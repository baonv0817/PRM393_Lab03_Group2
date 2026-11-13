import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/domain/order_pricing.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S09: change a pending order before the kitchen takes it: quantities, notes and the voucher.
///
/// The changes live in a draft until [save]; the repository prices the order again on the server side.
class EditOrderViewModel extends ChangeNotifier with SafeChangeNotifier {
  EditOrderViewModel({
    required this.orders,
    required this.menu,
    required this.crash,
    required this.orderId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    save = Command0(_save);
    load();
  }

  static const maxNoteLength = 100;
  static const notFoundMessage = 'Không tìm thấy đơn này.';
  static const lockedMessage = 'Bếp đã nhận đơn nên không sửa được nữa.';
  static const lastLineMessage = 'Đơn cần ít nhất một món. Muốn bỏ hết món thì hãy huỷ đơn.';

  final OrderRepository orders;
  final MenuRepository menu;
  final CrashService crash;
  final String orderId;
  final DateTime Function() _clock;

  late final Command0<void> save;

  StreamSubscription<Order?>? _sub;
  ViewState<Order> _state = const ViewLoading();
  List<CartItem> _draft = const [];
  bool _started = false;
  bool _voucherDropped = false;
  Voucher? _voucher;
  String? _voucherMissing;
  String? _voucherLoadedFor;

  ViewState<Order> get state => _state;
  Order? get order => _state.dataOrNull;
  DateTime get now => _clock();

  /// The kitchen took the order (or it ended) while the screen was open: nothing can be changed any more.
  bool get locked => order != null && order!.status != OrderStatus.pending;

  List<CartItem> get items => _draft;

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    _started = false;
    notifyListeners();
    _sub = orders
        .watchOrder(orderId)
        .listen(
          (value) {
            _state = value == null ? const ViewEmpty(notFoundMessage) : ViewData(value);
            if (value != null && !_started && value.status == OrderStatus.pending) {
              _started = true;
              _draft = [...value.items];
              _voucherDropped = false;
              unawaited(_loadVoucher(value.voucherCode));
            }
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'editOrder.watchOrder');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn hàng.');
            notifyListeners();
          },
        );
  }

  Future<void> _loadVoucher(String? code) async {
    _voucherLoadedFor = code;
    _voucher = null;
    _voucherMissing = null;
    if (code == null) return;
    final result = await menu.getVoucher(code);
    if (code != _voucherLoadedFor) return;
    switch (result) {
      case Ok(:final value):
        _voucher = value;
      case Err(error: NotFoundException()):
        _voucherMissing = 'Mã $code không tồn tại hoặc đã bị gỡ.';
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'editOrder.voucher');
        _voucherMissing = error.message;
    }
    notifyListeners();
  }

  bool canIncrease(String lineKey) => _lineOf(lineKey).quantity < Cart.maxQuantity;

  /// The last line cannot be removed: an order without items is a cancellation.
  bool canDecrease(String lineKey) => _lineOf(lineKey).quantity > 1 || _draft.length > 1;

  /// [lineKey] is `CartItem.lineKey`: a dish can be two lines with different options.
  CartItem _lineOf(String lineKey) => _draft.firstWhere((i) => i.lineKey == lineKey);

  void changeQuantity(String lineKey, int delta) {
    final index = _draft.indexWhere((i) => i.lineKey == lineKey);
    if (index == -1 || locked) return;
    final line = _draft[index];
    final next = line.quantity + delta;
    if (next > Cart.maxQuantity) return;
    final updated = [..._draft];
    if (next < 1) {
      if (_draft.length == 1) return;
      updated.removeAt(index);
    } else {
      updated[index] = line.copyWith(quantity: next);
    }
    _draft = updated;
    notifyListeners();
  }

  void setNote(String lineKey, String note) {
    final index = _draft.indexWhere((i) => i.lineKey == lineKey);
    if (index == -1 || locked) return;
    final trimmed = note.trim();
    final updated = [..._draft];
    updated[index] = _draft[index].copyWith(
      note: trimmed.length > maxNoteLength ? trimmed.substring(0, maxNoteLength) : trimmed,
    );
    _draft = updated;
    notifyListeners();
  }

  /// The order had a voucher, and the draft still keeps it.
  String? get voucherCode => order?.voucherCode;

  bool get voucherDropped => _voucherDropped;

  Voucher? get _activeVoucher => _voucherDropped ? null : _voucher;

  void dropVoucher() {
    if (_voucherDropped) return;
    _voucherDropped = true;
    notifyListeners();
  }

  void keepVoucher() {
    if (!_voucherDropped) return;
    _voucherDropped = false;
    notifyListeners();
  }

  OrderPricing get pricing => priceOrder(_draft, voucher: _activeVoucher, now: now);

  /// Why the kept voucher cannot be used with the changed items; the order cannot be saved until it is dropped.
  String? get voucherProblem {
    if (_voucherDropped || voucherCode == null) return null;
    if (_voucherMissing case final message?) return message;
    final voucher = _voucher;
    if (voucher == null) return null;
    final problem = voucher.problemFor(pricing.subtotalVnd, now);
    return problem == null ? null : voucherProblemMessage(voucher, problem);
  }

  int get itemCount => _draft.fold(0, (sum, i) => sum + i.quantity);

  /// Something differs from the order as it was placed.
  bool get hasChanges {
    final o = order;
    if (o == null || !_started) return false;
    if (_voucherDropped) return true;
    if (_draft.length != o.items.length) return true;
    for (var i = 0; i < _draft.length; i++) {
      final before = o.items[i];
      final after = _draft[i];
      if (before.lineKey != after.lineKey || before.quantity != after.quantity || before.note != after.note) {
        return true;
      }
    }
    return false;
  }

  bool get canSave => _started && !locked && hasChanges && voucherProblem == null && _draft.isNotEmpty;

  Future<Result<void>> _save() async {
    final o = order;
    if (o == null) return const Result.error(NotFoundException(message: notFoundMessage));
    if (locked) return const Result.error(ValidationException(lockedMessage));
    final result = await orders.editPendingOrder(
      o,
      items: _draft,
      voucherCode: _voucherDropped ? null : o.voucherCode,
      pickupSlotId: o.pickupSlotId,
      note: o.note,
    );
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'editOrder.save');
    return result;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    save.dispose();
    super.dispose();
  }
}
