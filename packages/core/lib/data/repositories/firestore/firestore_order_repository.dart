import 'dart:math';

import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/domain/order_pricing.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(this._db, {Random? random, DateTime Function()? clock})
    : _random = random ?? Random.secure(),
      _now = clock ?? DateTime.now;

  static const activeStatuses = [OrderStatus.pending, OrderStatus.preparing, OrderStatus.ready];

  /// K11 draws its chart from this many of the newest orders; the figures above it are counted on the server.
  static const statsChartLimit = 500;
  static const paidOrClosedMessage = 'Đơn này đã được thanh toán hoặc đã huỷ.';
  static const handledMessage = 'Đơn này vừa được xử lý ở nơi khác. Danh sách đã cập nhật lại.';

  final FirebaseFirestore _db;
  final Random _random;
  final DateTime Function() _now;

  CollectionReference<Json> get _orders => _db.collection('orders');

  DocumentReference<Json> _kiosk(String kioskId) => _db.collection('kiosks').doc(kioskId);

  DocumentReference<Json> _slot(String kioskId, String slotId) => _kiosk(kioskId).collection('slots').doc(slotId);

  List<String> get _activeNames => [for (final s in activeStatuses) s.name];

  Order _fromDoc(DocumentSnapshot<Json> doc) => orderFromData(doc.id, doc.data() ?? const {}, now: _now());

  @override
  Future<Result<String>> placeOrder(OrderDraft draft) async {
    final problem = _checkItems(draft.items);
    if (problem != null) return Result.error(problem);
    final ref = _orders.doc();
    final pickupCode = List.generate(6, (_) => _random.nextInt(10)).join();
    return runGuardedTransaction(_db, (tx) async {
      final kiosk = await tx.get(_kiosk(draft.kioskId));
      _ensureAcceptsOrders(kiosk);
      final voucher = await _readVoucher(tx, draft.voucherCode);
      final slotRef = draft.pickupSlotId == null ? null : _slot(draft.kioskId, draft.pickupSlotId!);
      final slot = slotRef == null ? null : await _readOpenSlot(tx, slotRef);
      final pricing = _price(draft.items, voucher);
      tx.set(ref, {
        'orderCode': orderCodeOf(ref.id),
        'uid': draft.uid,
        'customerName': draft.customerName,
        'kioskId': draft.kioskId,
        'kioskName': draft.kioskName,
        'items': draft.items.map(cartItemToData).toList(),
        'subtotalVnd': pricing.subtotalVnd,
        'discountVnd': pricing.discountVnd,
        'totalVnd': pricing.totalVnd,
        if (voucher != null) 'voucherCode': voucher.code,
        'paymentMethod': draft.paymentMethod.name,
        'paymentStatus': PaymentStatus.unpaid.name,
        'status': OrderStatus.pending.name,
        if (slot != null) 'pickupSlotId': slot.id,
        if (slot != null) 'pickupAt': Timestamp.fromDate(slot.startAt),
        'pickupCode': pickupCode,
        if (draft.note.trim().isNotEmpty) 'note': draft.note.trim(),
        ...Stamp.created(),
      });
      if (draft.paymentMethod == PaymentMethod.cash) tx.delete(_db.collection('carts').doc(draft.uid));
      if (slotRef != null) tx.update(slotRef, _bookedBy(1));
      return ref.id;
    });
  }

  @override
  Future<Result<void>> payOrder(String orderId) {
    final ref = _orders.doc(orderId);
    return runGuardedTransaction<void>(_db, (tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw const NotFoundException(message: 'Không tìm thấy đơn hàng.');
      final current = _fromDoc(snapshot);
      if (!current.awaitingPayment) throw const ValidationException(paidOrClosedMessage);
      tx.update(ref, {'paymentStatus': PaymentStatus.paid.name, ...Stamp.updated()});
      tx.delete(_db.collection('carts').doc(current.uid));
    });
  }

  @override
  Stream<Order?> watchOrder(String id) =>
      guardStream(_orders.doc(id).snapshots().map((snapshot) => snapshot.exists ? _fromDoc(snapshot) : null));

  @override
  Stream<List<Order>> watchMyOrders(String uid, {int limit = Paged.defaultLimit}) {
    if (Paged.checkLimit(limit) case final error?) return Stream.error(error);
    return _watch(_orders.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true).limit(limit));
  }

  @override
  Stream<List<Order>> watchMyActiveOrders(String uid) => _watch(
    _orders.where('uid', isEqualTo: uid).where('status', whereIn: _activeNames).orderBy('createdAt', descending: true),
  );

  @override
  Future<Result<Paged<Order>>> fetchMyOrders(String uid, {int limit = Paged.defaultLimit, PageCursor? after}) =>
      fetchPage(
        _orders.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true),
        fromDoc: _fromDoc,
        limit: limit,
        after: after,
      );

  @override
  Future<Result<int>> countMyOrders(String uid) => guard(() async {
    final snapshot = await _orders.where('uid', isEqualTo: uid).count().get();
    return snapshot.count ?? 0;
  });

  @override
  Future<Result<void>> editPendingOrder(
    Order order, {
    required List<CartItem> items,
    String? voucherCode,
    String? pickupSlotId,
    String note = '',
  }) async {
    final problem = _checkItems(items);
    if (problem != null) return Result.error(problem);
    final ref = _orders.doc(order.id);
    return runGuardedTransaction<void>(_db, (tx) async {
      final current = _fromDoc(await tx.get(ref));
      if (current.status != OrderStatus.pending) {
        throw const ValidationException('Kiosk đã nhận đơn nên không sửa được nữa.');
      }
      final voucher = await _readVoucher(tx, voucherCode);
      final oldSlot = current.pickupSlotId;
      final slotChanged = pickupSlotId != oldSlot;
      final newSlotRef = pickupSlotId == null || !slotChanged ? null : _slot(current.kioskId, pickupSlotId);
      final newSlot = newSlotRef == null ? null : await _readOpenSlot(tx, newSlotRef);
      final pricing = _price(items, voucher);
      tx.update(ref, {
        'items': items.map(cartItemToData).toList(),
        'subtotalVnd': pricing.subtotalVnd,
        'discountVnd': pricing.discountVnd,
        'totalVnd': pricing.totalVnd,
        'voucherCode': voucher?.code ?? FieldValue.delete(),
        if (slotChanged) 'pickupSlotId': pickupSlotId ?? FieldValue.delete(),
        if (slotChanged) 'pickupAt': newSlot == null ? FieldValue.delete() : Timestamp.fromDate(newSlot.startAt),
        'note': note.trim().isEmpty ? FieldValue.delete() : note.trim(),
        ...Stamp.updated(),
      });
      if (slotChanged && oldSlot != null) tx.update(_slot(current.kioskId, oldSlot), _bookedBy(-1));
      if (newSlotRef != null) tx.update(newSlotRef, _bookedBy(1));
    });
  }

  @override
  Future<Result<void>> cancelMyOrder(Order order, {String? reason}) => _step(order, (current) {
    if (current.status != OrderStatus.pending) {
      throw const ValidationException('Kiosk đã nhận đơn nên không huỷ được nữa. Liên hệ quầy để được hỗ trợ.');
    }
    return {
      'status': OrderStatus.cancelled.name,
      'cancelledBy': CancelledBy.customer.name,
      'cancelledAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.trim().isNotEmpty) 'cancelReason': reason.trim(),
    };
  }, releaseSlot: true);

  @override
  Stream<List<Order>> watchKioskQueue(String kioskId) =>
      _watch(
        _orders
            .where('kioskId', isEqualTo: kioskId)
            .where('status', whereIn: _activeNames)
            .orderBy('createdAt', descending: true),
      ).map(
        (orders) => [
          for (final o in orders)
            if (!o.awaitingPayment) o,
        ],
      );

  @override
  Future<Result<List<Order>>> findReadyByPickupCode(String kioskId, String pickupCode) => guard(() async {
    final snapshot = await _orders
        .where('kioskId', isEqualTo: kioskId)
        .where('pickupCode', isEqualTo: pickupCode.trim())
        .where('status', isEqualTo: OrderStatus.ready.name)
        .get();
    return [for (final doc in snapshot.docs) _fromDoc(doc)];
  });

  @override
  Future<Result<void>> accept(Order order, {required Duration readyIn}) {
    if (readyIn < OrderRepository.minReadyIn) {
      return Future.value(const Result.error(ValidationException('Thời gian chuẩn bị tối thiểu 1 phút.')));
    }
    return _step(order, (current) {
      _expect(current, OrderStatus.pending);
      if (current.awaitingPayment) throw const ValidationException('Khách chưa thanh toán đơn này.');
      return {
        'status': OrderStatus.preparing.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'readyBy': Timestamp.fromDate(_now().add(readyIn)),
      };
    });
  }

  @override
  Future<Result<void>> markReady(Order order) => _step(order, (current) {
    _expect(current, OrderStatus.preparing);
    final acceptedAt = current.acceptedAt;
    final seconds = acceptedAt == null ? 0 : _now().difference(acceptedAt).inSeconds;
    return {
      'status': OrderStatus.ready.name,
      'readyAt': FieldValue.serverTimestamp(),
      'prepSeconds': seconds < 0 ? 0 : seconds,
    };
  });

  @override
  Future<Result<void>> deliver(Order order) => _step(order, (current) {
    _expect(current, OrderStatus.ready);
    return {
      'status': OrderStatus.delivered.name,
      'deliveredAt': FieldValue.serverTimestamp(),
      'paymentStatus': PaymentStatus.paid.name,
    };
  });

  @override
  Future<Result<void>> reject(Order order, {required String reason}) {
    if (reason.trim().isEmpty) {
      return Future.value(const Result.error(ValidationException('Chọn hoặc nhập lý do từ chối đơn.')));
    }
    return _step(order, (current) {
      if (!activeStatuses.contains(current.status)) throw const ValidationException(handledMessage);
      return {
        'status': OrderStatus.cancelled.name,
        'cancelledBy': CancelledBy.staff.name,
        'cancelReason': reason.trim(),
        'cancelledAt': FieldValue.serverTimestamp(),
      };
    }, releaseSlot: true);
  }

  @override
  Future<Result<KioskStats>> kioskStats(String kioskId, {required DateTime since}) => guard(() async {
    final shift = _orders
        .where('kioskId', isEqualTo: kioskId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    final results = await Future.wait([
      shift
          .where('status', isEqualTo: OrderStatus.delivered.name)
          .aggregate(count(), sum('totalVnd'), average('prepSeconds'))
          .get(),
      shift.where('status', isEqualTo: OrderStatus.cancelled.name).count().get(),
      shift.where('status', whereIn: _activeNames).count().get(),
      shift.orderBy('createdAt', descending: true).limit(statsChartLimit).get(),
    ]);
    final delivered = results[0] as AggregateQuerySnapshot;
    final recent = (results[3] as QuerySnapshot<Json>).docs;
    return KioskStats(
      deliveredCount: delivered.count ?? 0,
      revenueVnd: delivered.getSum('totalVnd')?.round() ?? 0,
      averagePrepSeconds: delivered.getAverage('prepSeconds'),
      cancelledCount: (results[1] as AggregateQuerySnapshot).count ?? 0,
      activeCount: (results[2] as AggregateQuerySnapshot).count ?? 0,
      ordersByHour: KioskStats.hourlyCounts([for (final doc in recent) _fromDoc(doc)]),
      chartTruncated: recent.length >= statsChartLimit,
    );
  });

  Stream<List<Order>> _watch(Query<Json> query) =>
      guardStream(query.snapshots().map((snapshot) => [for (final doc in snapshot.docs) _fromDoc(doc)]));

  Future<Result<void>> _step(
    Order order,
    Map<String, Object> Function(Order current) changes, {
    bool releaseSlot = false,
  }) {
    final ref = _orders.doc(order.id);
    return runGuardedTransaction<void>(_db, (tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) throw const NotFoundException(message: 'Không tìm thấy đơn hàng.');
      final current = _fromDoc(snapshot);
      tx.update(ref, {...changes(current), ...Stamp.updated()});
      final slotId = current.pickupSlotId;
      if (releaseSlot && slotId != null) tx.update(_slot(current.kioskId, slotId), _bookedBy(-1));
    });
  }

  void _expect(Order current, OrderStatus status) {
    if (current.status != status) throw const ValidationException(handledMessage);
  }

  Map<String, Object> _bookedBy(int delta) => {'booked': FieldValue.increment(delta), ...Stamp.updated()};

  AppException? _checkItems(List<CartItem> items) {
    if (items.isEmpty) return const ValidationException('Giỏ hàng đang trống.');
    if (items.length > Cart.maxLines) {
      return const ValidationException('Mỗi đơn tối đa ${Cart.maxLines} món khác nhau.');
    }
    if (items.any((e) => e.quantity < 1 || e.quantity > Cart.maxQuantity || e.priceVnd <= 0)) {
      return const ValidationException('Có món trong đơn không hợp lệ.');
    }
    return null;
  }

  void _ensureAcceptsOrders(DocumentSnapshot<Json> snapshot) {
    final data = snapshot.data();
    if (data == null) throw const NotFoundException(message: 'Không tìm thấy kiosk.');
    final kiosk = kioskFromData(snapshot.id, data);
    if (!kiosk.open) throw ValidationException('${kiosk.name} đang đóng cửa. Chọn kiosk khác để đặt món.');
    final now = _now();
    if (!kiosk.isWithinHours(now)) {
      throw ValidationException(
        '${kiosk.name} đang ngoài giờ mở cửa (${kiosk.openTime}–${kiosk.closeTime}). Chọn kiosk khác hoặc quay lại sau.',
      );
    }
    if (kiosk.isPaused(now)) {
      throw ValidationException('${kiosk.name} tạm ngưng nhận đơn đến ${formatTime(kiosk.pausedUntil!)}.');
    }
  }

  Future<Voucher?> _readVoucher(Transaction tx, String? code) async {
    if (code == null || code.isEmpty) return null;
    final snapshot = await tx.get(_db.collection('vouchers').doc(code));
    final data = snapshot.data();
    if (data == null) throw const NotFoundException(message: 'Mã giảm giá không tồn tại.');
    final voucher = voucherFromData(snapshot.id, data);
    if (voucher == null) throw const ServiceException(message: 'Mã giảm giá đang bị lỗi cấu hình.');
    return voucher;
  }

  Future<PickupSlot> _readOpenSlot(Transaction tx, DocumentReference<Json> ref) async {
    final snapshot = await tx.get(ref);
    final data = snapshot.data();
    if (data == null) throw const NotFoundException(message: 'Khung giờ nhận món không còn.');
    final slot = pickupSlotFromData(snapshot.id, data);
    if (slot.isFull) throw ValidationException('Khung ${formatTime(slot.startAt)} đã đủ đơn. Chọn giờ khác.');
    if (slot.endAt.isBefore(_now())) {
      throw ValidationException('Khung ${formatTime(slot.startAt)} đã qua. Chọn giờ khác.');
    }
    return slot;
  }

  OrderPricing _price(List<CartItem> items, Voucher? voucher) {
    final now = _now();
    final pricing = priceOrder(items, voucher: voucher, now: now);
    if (voucher != null) {
      final problem = voucher.problemFor(pricing.subtotalVnd, now);
      if (problem != null) throw ValidationException(voucherProblemMessage(voucher, problem));
    }
    return pricing;
  }
}
