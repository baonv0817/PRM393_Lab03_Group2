import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

enum ReceiptStage { idle, generating, uploading, saving }

/// A label and a value shown on one row (a step of the order, a line of the bill).
class DetailRow {
  const DetailRow(this.label, this.value, {this.id, this.strong = false});

  final String label;
  final String value;

  /// Stable key of a bill line (`subtotal`, `discount`, `total`), used for test ids.
  final String? id;
  final bool strong;
}

class OrderLineView {
  const OrderLineView({required this.name, required this.quantity, required this.price, this.note});

  final String name;
  final String quantity;
  final String price;
  final String? note;
}

/// S12: everything about one order, a PDF receipt of it (generated, uploaded, listed) and a reorder.
class OrderDetailViewModel extends ChangeNotifier with SafeChangeNotifier {
  OrderDetailViewModel({
    required this.orders,
    required this.cart,
    required this.session,
    required this.storage,
    required this.reportFiles,
    required this.reports,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this.customerName,
    required this.orderId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    reorder = Command0(_reorder);
    exportReceipt = Command0(_exportReceipt);
    load();
  }

  static const notFoundMessage = 'Không tìm thấy đơn này.';
  static const noReceiptMessage = 'Đơn đã huỷ và chưa thanh toán nên không có biên nhận.';

  final OrderRepository orders;
  final CartRepository cart;
  final SessionRepository session;
  final StorageService storage;
  final ReportFileService reportFiles;
  final ReportRepository reports;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String customerName;
  final String orderId;
  final DateTime Function() _clock;

  late final Command0<int> reorder;
  late final Command0<Report> exportReceipt;

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'order_detail',
    onChanged: notifyListeners,
  );
  StreamSubscription<Order?>? _orderSub;
  StreamSubscription<List<Report>>? _reportsSub;
  ViewState<Order> _state = const ViewLoading();
  List<Report> _receipts = const [];
  ReceiptStage _stage = ReceiptStage.idle;
  double _uploadProgress = 0;
  Report? _lastReceipt;

  ViewState<Order> get state => _state;
  Order? get order => _state.dataOrNull;

  /// Receipts already exported for this order, newest first.
  List<Report> get receipts => _receipts;
  ReceiptStage get stage => _stage;
  double get uploadProgress => _uploadProgress;
  Report? get lastReceipt => _lastReceipt;

  /// The "Biên nhận đã xuất" list: the receipts exported before, without the one just uploaded.
  List<Report> get earlierReceipts => [
    for (final r in _receipts)
      if (r.id != _lastReceipt?.id) r,
  ];

  void load() {
    unawaited(_orderSub?.cancel());
    unawaited(_reportsSub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _orderSub = orders
        .watchOrder(orderId)
        .listen(
          (value) {
            _state = value == null ? const ViewEmpty(notFoundMessage) : ViewData(value);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'orderDetail.watchOrder');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn hàng.');
            notifyListeners();
          },
        );
    _reportsSub = reports.watchMine(uid).listen((items) {
      _receipts = items.where((r) => r.orderId == orderId).toList();
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => crash.recordNonFatal(error, stack, 'orderDetail.watchReceipts'));
  }

  bool get isCancelled => order?.status == OrderStatus.cancelled;

  bool get isActive {
    final status = order?.status;
    return status != null && status != OrderStatus.delivered && status != OrderStatus.cancelled;
  }

  /// A problem can be reported once the food was received (S24).
  bool get canReportIncident => order?.status == OrderStatus.delivered;

  /// A receipt proves a payment: an order cancelled before anything was paid has none (found by the ARTEMIS Pro
  /// session, docs/test-plan.md section 4.1). A paid order that was cancelled keeps it, marked "Được hoàn tiền".
  bool get canExportReceipt {
    final o = order;
    return o != null && !(o.status == OrderStatus.cancelled && o.paymentStatus == PaymentStatus.unpaid);
  }

  /// The items can be rated once the food was received (S23).
  bool get canReview => order?.status == OrderStatus.delivered;

  String get statusLabel => order == null ? '' : orderStatusLabel(order!.status);

  /// The steps the order went through, only those that have happened.
  List<DetailRow> get timeline {
    final o = order;
    if (o == null) return const [];
    return [
      DetailRow('Đặt đơn', formatDateTime(o.createdAt)),
      if (o.acceptedAt case final at?) DetailRow('Kiosk nhận đơn', formatDateTime(at)),
      if (o.readyAt case final at?) DetailRow('Món sẵn sàng', formatDateTime(at)),
      if (o.deliveredAt case final at?) DetailRow('Nhận món', formatDateTime(at)),
      if (o.cancelledAt case final at?) DetailRow('Huỷ đơn', formatDateTime(at)),
    ];
  }

  List<OrderLineView> get lines => [
    for (final item in order?.items ?? const <CartItem>[])
      OrderLineView(
        name: item.displayName,
        quantity: '×${item.quantity}',
        price: formatVnd(item.lineTotalVnd),
        note: item.note.trim().isEmpty ? null : item.note.trim(),
      ),
  ];

  /// The bill: items, the voucher if one was used, and the total.
  List<DetailRow> get amounts {
    final o = order;
    if (o == null) return const [];
    return [
      DetailRow('Tạm tính', formatVnd(orderItemsTotalVnd(o)), id: 'subtotal'),
      if (o.discountVnd > 0)
        DetailRow(
          'Giảm giá${o.voucherCode == null ? '' : ' (${o.voucherCode})'}',
          '−${formatVnd(o.discountVnd)}',
          id: 'discount',
        ),
      DetailRow('Tổng cộng', formatVnd(o.totalVnd), id: 'total', strong: true),
    ];
  }

  String get paymentLine {
    final o = order;
    return o == null ? '' : '${paymentMethodLabel(o.paymentMethod)} · ${orderPaymentLabel(o)}';
  }

  String get pickupLine {
    final pickupAt = order?.pickupAt;
    return pickupAt == null ? 'Nhận ngay khi sẵn sàng' : 'Hẹn nhận lúc ${formatDateTime(pickupAt)}';
  }

  String? get noteLine {
    final note = order?.note.trim() ?? '';
    return note.isEmpty ? null : 'Ghi chú cho bếp: $note';
  }

  Future<Result<int>> _reorder() async {
    final o = order;
    if (o == null) return const Result.error(NotFoundException(message: notFoundMessage));
    final result = await _cart.reorder(o);
    if (result is Ok<int>) await session.selectKiosk(o.kioskId);
    return result;
  }

  Future<Result<Report>> _exportReceipt() async {
    final result = await _export();
    _stage = ReceiptStage.idle;
    switch (result) {
      case Ok(:final value):
        _lastReceipt = value;
        unawaited(
          analytics.logEvent(AnalyticsEvents.exportReport, {'file_size_kb': value.sizeKb, 'source': 'order_detail'}),
        );
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'orderDetail.export');
    }
    notifyListeners();
    return result;
  }

  Future<Result<Report>> _export() async {
    final o = order;
    if (o == null) return const Result.error(NotFoundException(message: notFoundMessage));
    if (uid.isEmpty) return const Result.error(PermissionDeniedException(message: 'Đăng nhập để xuất biên nhận.'));
    if (!canExportReceipt) return const Result.error(ValidationException(noReceiptMessage));
    _stage = ReceiptStage.generating;
    _uploadProgress = 0;
    notifyListeners();

    final GeneratedFile file;
    switch (await reportFiles.orderReceipt(customerName: customerName, order: o, now: _clock())) {
      case Ok(:final value):
        file = value;
      case Err(:final error):
        return Result.error(error);
    }

    _stage = ReceiptStage.uploading;
    notifyListeners();
    final UploadedFile uploaded;
    switch (await storage.upload(
      folder: UploadFolder.reports,
      ownerId: uid,
      fileName: file.fileName,
      bytes: file.bytes,
      onProgress: (progress) {
        _uploadProgress = progress.clamp(0, 1);
        notifyListeners();
      },
    )) {
      case Ok(:final value):
        uploaded = value;
      case Err(:final error):
        return Result.error(error);
    }

    _stage = ReceiptStage.saving;
    notifyListeners();
    return reports.save(uid: uid, fileName: file.fileName, file: uploaded, orderId: o.id);
  }

  @override
  void dispose() {
    unawaited(_orderSub?.cancel());
    unawaited(_reportsSub?.cancel());
    reorder.dispose();
    exportReceipt.dispose();
    super.dispose();
  }
}
