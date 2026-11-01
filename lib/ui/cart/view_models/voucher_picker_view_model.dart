import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class VoucherOption {
  const VoucherOption(this.voucher, this.problem);

  final Voucher voucher;
  final VoucherProblem? problem;

  bool get usable => problem == null;
}

class VoucherPickerViewModel extends ChangeNotifier with SafeChangeNotifier {
  VoucherPickerViewModel({
    required this.vouchers,
    required this.menu,
    required this.cart,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    confirm = Command0(_confirm);
    applyCode = Command1(_applyCode);
    load();
  }

  static const emptyMessage = 'Chưa có mã giảm giá nào đang áp dụng';

  final VoucherRepository vouchers;
  final MenuRepository menu;
  final CartRepository cart;
  final CrashService crash;
  final String uid;
  final DateTime Function() _clock;

  late final Command0<void> confirm;
  late final Command1<void, String> applyCode;

  StreamSubscription<List<Voucher>>? _voucherSub;
  StreamSubscription<Cart>? _cartSub;
  List<Voucher>? _vouchers;
  Cart? _cart;
  String? _loadError;
  String? _selected;
  bool _selectionTouched = false;
  String? _codeError;

  DateTime get now => _clock();
  int get subtotalVnd => _cart?.subtotalVnd ?? 0;
  String? get selected => _selected;
  String? get appliedCode => _cart?.voucherCode;
  String? get codeError => _codeError;

  ViewState<List<VoucherOption>> get state {
    if (_loadError case final message?) return ViewError(message);
    final list = _vouchers;
    if (list == null || _cart == null) return const ViewLoading();
    final options = [for (final v in list) VoucherOption(v, v.problemFor(subtotalVnd, now))]
      ..sort((a, b) {
        final byRank = _rank(a).compareTo(_rank(b));
        return byRank != 0 ? byRank : a.voucher.code.compareTo(b.voucher.code);
      });
    return ViewStateX.fromList(options, emptyMessage: emptyMessage);
  }

  static int _rank(VoucherOption option) => switch (option.problem) {
    null => 0,
    VoucherProblem.belowMinimum || VoucherProblem.outsideActiveHours || VoucherProblem.notStarted => 1,
    VoucherProblem.expired || VoucherProblem.inactive => 2,
  };

  String conditionOf(VoucherOption option) {
    final v = option.voucher;
    return switch (option.problem) {
      VoucherProblem.expired => 'Đã hết hạn',
      VoucherProblem.inactive => 'Đã ngừng áp dụng',
      VoucherProblem.notStarted => 'Áp dụng từ ${formatDayMonth(v.startsAt!)}',
      VoucherProblem.outsideActiveHours => 'Chỉ áp dụng ${v.activeFrom}–${v.activeTo}',
      VoucherProblem.belowMinimum => 'Mua thêm ${formatVnd(v.minOrderVnd - subtotalVnd)} để dùng mã',
      null when v.activeFrom != null => 'Dùng được tới ${v.activeTo} hôm nay',
      null when v.expiresAt.difference(now).inDays > 365 => 'Dùng được ngay',
      null => 'Hết hạn ${formatDayMonth(v.expiresAt)}',
    };
  }

  String get confirmLabel => _selected == null && appliedCode != null ? 'Không dùng mã' : 'Dùng mã đã chọn';

  bool get canConfirm => !confirm.running && (_selected != null || appliedCode != null);

  void load() {
    unawaited(_voucherSub?.cancel());
    unawaited(_cartSub?.cancel());
    _loadError = null;
    _vouchers = null;
    notifyListeners();
    _voucherSub = vouchers.watchActiveVouchers().listen((list) {
      _vouchers = list;
      notifyListeners();
    }, onError: _onError);
    _cartSub = cart.watchCart(uid).listen((value) {
      _cart = value;
      if (!_selectionTouched) _selected = value.voucherCode;
      notifyListeners();
    }, onError: _onError);
  }

  void _onError(Object error, StackTrace stack) {
    crash.recordNonFatal(error, stack, 'vouchers.load');
    _loadError = error is AppException ? error.message : 'Không tải được mã giảm giá.';
    notifyListeners();
  }

  void select(VoucherOption option) {
    if (!option.usable) return;
    _selectionTouched = true;
    _selected = _selected == option.voucher.code ? null : option.voucher.code;
    notifyListeners();
  }

  void clearCodeError() {
    if (_codeError == null) return;
    _codeError = null;
    notifyListeners();
  }

  Future<Result<void>> _confirm() async {
    final result = await cart.setVoucher(uid, _selected);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'vouchers.confirm');
    return result;
  }

  Future<Result<void>> _applyCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return _rejectCode('Nhập mã giảm giá trước khi áp dụng.');
    final found = await menu.getVoucher(trimmed);
    switch (found) {
      case Err(error: NotFoundException(:final message)):
        return _rejectCode(message);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'vouchers.applyCode');
        return _rejectCode(error.message);
      case Ok(:final value):
        final problem = value.problemFor(subtotalVnd, now);
        if (problem != null) return _rejectCode(voucherProblemMessage(value, problem));
        _codeError = null;
        _selectionTouched = true;
        _selected = value.code;
        notifyListeners();
        return _confirm();
    }
  }

  Result<void> _rejectCode(String message) {
    _codeError = message;
    notifyListeners();
    return Result.error(ValidationException(message));
  }

  @override
  void dispose() {
    unawaited(_voucherSub?.cancel());
    unawaited(_cartSub?.cancel());
    confirm.dispose();
    applyCode.dispose();
    super.dispose();
  }
}
