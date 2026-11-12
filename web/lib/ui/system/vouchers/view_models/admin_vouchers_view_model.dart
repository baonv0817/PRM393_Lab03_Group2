import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

enum DiscountKind { fixed, percent }

/// Where a voucher stands at a given moment.
enum VoucherStatus { live, scheduled, expired, off }

/// What an admin typed for a voucher (A04). The two dates are days on the Vietnam calendar, as `DateTime.utc`
/// with no time: a voucher starts at 00:00 of its first day and ends at 23:59 of its last, Vietnam time.
class VoucherForm {
  const VoucherForm({
    this.code = '',
    this.title = '',
    this.kind = DiscountKind.fixed,
    this.amount = '',
    this.percent = '',
    this.maxVnd = '',
    this.minOrder = '0',
    this.startsOn,
    this.expiresOn,
    this.activeFrom = '',
    this.activeTo = '',
    this.active = true,
  });

  factory VoucherForm.of(Voucher voucher) {
    DateTime? day(DateTime? instant) {
      if (instant == null) return null;
      final vietnam = instant.toUtc().add(SlotPlan.vietnamOffset);
      return DateTime.utc(vietnam.year, vietnam.month, vietnam.day);
    }

    final discount = voucher.discount;
    return VoucherForm(
      code: voucher.code,
      title: voucher.title,
      kind: discount is PercentDiscount ? DiscountKind.percent : DiscountKind.fixed,
      amount: discount is FixedDiscount ? '${discount.amountVnd}' : '',
      percent: discount is PercentDiscount ? '${discount.percent}' : '',
      maxVnd: discount is PercentDiscount ? '${discount.maxVnd}' : '',
      minOrder: '${voucher.minOrderVnd}',
      startsOn: day(voucher.startsAt),
      expiresOn: day(voucher.expiresAt),
      activeFrom: voucher.activeFrom ?? '',
      activeTo: voucher.activeTo ?? '',
      active: voucher.active,
    );
  }

  final String code;
  final String title;
  final DiscountKind kind;
  final String amount;
  final String percent;
  final String maxVnd;
  final String minOrder;
  final DateTime? startsOn;
  final DateTime? expiresOn;
  final String activeFrom;
  final String activeTo;
  final bool active;

  VoucherForm copyWith({
    String? code,
    String? title,
    DiscountKind? kind,
    String? amount,
    String? percent,
    String? maxVnd,
    String? minOrder,
    Object? startsOn = _keep,
    Object? expiresOn = _keep,
    String? activeFrom,
    String? activeTo,
    bool? active,
  }) => VoucherForm(
    code: code ?? this.code,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    percent: percent ?? this.percent,
    maxVnd: maxVnd ?? this.maxVnd,
    minOrder: minOrder ?? this.minOrder,
    startsOn: identical(startsOn, _keep) ? this.startsOn : startsOn as DateTime?,
    expiresOn: identical(expiresOn, _keep) ? this.expiresOn : expiresOn as DateTime?,
    activeFrom: activeFrom ?? this.activeFrom,
    activeTo: activeTo ?? this.activeTo,
    active: active ?? this.active,
  );

  static const _keep = Object();

  /// The voucher these fields describe, or `null` while a number is not a number or there is no last day.
  Voucher? toVoucher() {
    final last = expiresOn;
    final min = int.tryParse(minOrder.trim().isEmpty ? '0' : minOrder.trim());
    if (last == null || min == null) return null;
    final VoucherDiscount discount;
    if (kind == DiscountKind.fixed) {
      final value = int.tryParse(amount.trim());
      if (value == null) return null;
      discount = FixedDiscount(value);
    } else {
      final p = int.tryParse(percent.trim());
      final m = int.tryParse(maxVnd.trim());
      if (p == null || m == null) return null;
      discount = PercentDiscount(percent: p, maxVnd: m);
    }
    final first = startsOn;
    return Voucher(
      code: code.trim().toUpperCase(),
      title: title.trim(),
      discount: discount,
      minOrderVnd: min,
      startsAt: first == null
          ? null
          : DateTime.utc(first.year, first.month, first.day).subtract(SlotPlan.vietnamOffset),
      expiresAt: DateTime.utc(last.year, last.month, last.day, 23, 59, 59).subtract(SlotPlan.vietnamOffset),
      activeFrom: activeFrom.trim().isEmpty ? null : activeFrom.trim(),
      activeTo: activeTo.trim().isEmpty ? null : activeTo.trim(),
      active: active,
    );
  }
}

enum VoucherFilter { all, live, off, expired }

/// A04: the discount codes. An admin makes one (a fixed amount or a percentage with a cap, a minimum order, a first
/// and a last day, hours of the day), edits it, and switches it on or off. Customers get the live ones in S29.
class AdminVouchersViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminVouchersViewModel({required this.vouchers, DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    save = Command1(_save);
    toggle = Command1(_toggle);
    load();
  }

  static const emptyMessage = 'Chưa có mã giảm giá nào. Thêm mã đầu tiên.';

  final AdminVoucherRepository vouchers;
  final DateTime Function() _clock;

  late final Command1<void, ({VoucherForm form, bool isNew})> save;
  late final Command1<void, ({String code, bool active})> toggle;
  StreamSubscription<List<Voucher>>? _sub;
  ViewState<List<Voucher>> _state = const ViewLoading();
  VoucherFilter _filter = VoucherFilter.all;

  DateTime get now => _clock();
  ViewState<List<Voucher>> get state => _state;
  VoucherFilter get filter => _filter;

  VoucherStatus statusOf(Voucher v) {
    if (!v.active) return VoucherStatus.off;
    if (v.isExpired(now)) return VoucherStatus.expired;
    if (v.startsAt != null && now.isBefore(v.startsAt!)) return VoucherStatus.scheduled;
    return VoucherStatus.live;
  }

  List<Voucher> get visible {
    final all = _state.dataOrNull ?? const <Voucher>[];
    return [
      for (final v in all)
        if (switch (_filter) {
          VoucherFilter.all => true,
          VoucherFilter.live => statusOf(v) == VoucherStatus.live || statusOf(v) == VoucherStatus.scheduled,
          VoucherFilter.off => statusOf(v) == VoucherStatus.off,
          VoucherFilter.expired => statusOf(v) == VoucherStatus.expired,
        })
          v,
    ];
  }

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = vouchers.watchAll().listen(
      (list) {
        _state = list.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(list);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách mã giảm giá.');
        notifyListeners();
      },
    );
  }

  void setFilter(VoucherFilter value) {
    _filter = value;
    notifyListeners();
  }

  /// Why [form] cannot be saved, or `null`.
  String? problemOf(VoucherForm form, {required bool isNew}) {
    final voucher = form.toVoucher();
    if (voucher == null) {
      return form.expiresOn == null ? 'Chọn ngày hết hạn.' : 'Các ô số tiền, phần trăm và đơn tối thiểu phải là số.';
    }
    return VoucherRules.problemOf(voucher, isNew: isNew);
  }

  Future<Result<void>> _save(({VoucherForm form, bool isNew}) change) async {
    final problem = problemOf(change.form, isNew: change.isNew);
    if (problem != null) return Result.error(ValidationException(problem));
    return vouchers.save(change.form.toVoucher()!, isNew: change.isNew);
  }

  Future<Result<void>> _toggle(({String code, bool active}) change) => vouchers.setActive(change.code, change.active);

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    save.dispose();
    toggle.dispose();
    super.dispose();
  }
}
