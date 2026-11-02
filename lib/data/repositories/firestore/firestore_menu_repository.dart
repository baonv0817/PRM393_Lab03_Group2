import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/menu_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreMenuRepository implements MenuRepository {
  FirestoreMenuRepository(this._db);

  static const _inQueryLimit = 30;
  static final _voucherCode = RegExp(r'^[A-Z0-9]{3,20}$');

  final FirebaseFirestore _db;

  CollectionReference<Json> get _items => _db.collection('menu_items');

  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => guardStream(
    _items
        .where('kioskId', isEqualTo: kioskId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) menuItemFromData(doc.id, doc.data())]),
  );

  @override
  Future<Result<MenuItem>> getItem(String id) => guard(() async {
    final snapshot = await _items.doc(id).get();
    final data = snapshot.data();
    if (data == null) throw const NotFoundException(message: 'Không tìm thấy món.');
    return menuItemFromData(snapshot.id, data);
  });

  @override
  Future<Result<Map<String, MenuItem>>> getItems(Iterable<String> ids) => guard(() async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    final found = <String, MenuItem>{};
    for (var start = 0; start < unique.length; start += _inQueryLimit) {
      final chunk = unique.sublist(start, (start + _inQueryLimit).clamp(0, unique.length));
      final snapshot = await _items.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snapshot.docs) {
        found[doc.id] = menuItemFromData(doc.id, doc.data());
      }
    }
    return found;
  });

  @override
  Stream<List<Kiosk>> watchKiosks() => guardStream(
    _db
        .collection('kiosks')
        .snapshots()
        .map(
          (snapshot) =>
              [for (final doc in snapshot.docs) kioskFromData(doc.id, doc.data())]
                ..sort((a, b) => a.name.compareTo(b.name)),
        ),
  );

  @override
  Future<Result<Voucher>> getVoucher(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!_voucherCode.hasMatch(normalized)) {
      return const Result.error(NotFoundException(message: 'Mã giảm giá không tồn tại.'));
    }
    return guard(() async {
      final snapshot = await _db.collection('vouchers').doc(normalized).get();
      final data = snapshot.data();
      if (data == null) throw const NotFoundException(message: 'Mã giảm giá không tồn tại.');
      final voucher = voucherFromData(normalized, data);
      if (voucher == null) throw const ServiceException(message: 'Mã giảm giá đang bị lỗi cấu hình.');
      return voucher;
    });
  }

  @override
  Future<Result<String>> upsertItem(MenuItem item) async {
    final dishId = item.dishId.isNotEmpty ? item.dishId : slugify(item.name);
    final problem = _validate(item, dishId);
    if (problem != null) return Result.error(ValidationException(problem));
    final id = '${item.kioskId}-$dishId';
    if (item.id.isNotEmpty && item.id != id) {
      return const Result.error(ValidationException('Không thể đổi kiosk hoặc mã món của một món đã có.'));
    }
    final ref = _items.doc(id);
    final data = menuItemToData(item, dishId: dishId);
    return runGuardedTransaction(_db, (tx) async {
      final current = await tx.get(ref);
      if (current.exists) {
        tx.update(ref, {...data, ...Stamp.updated()});
      } else {
        tx.set(ref, {...data, ...Stamp.created()});
      }
      return id;
    });
  }

  @override
  Future<Result<void>> updateKiosk(String id, KioskSettings settings) async {
    final problem = settings.problem;
    if (problem != null) return Result.error(ValidationException(problem));
    final notice = settings.notice?.trim() ?? '';
    return guard(
      () => _db.collection('kiosks').doc(id).update({
        'open': settings.open,
        'waitMinutes': settings.waitMinutes,
        'pausedUntil': settings.pausedUntil == null ? FieldValue.delete() : Timestamp.fromDate(settings.pausedUntil!),
        'maxOrdersPerSlot': settings.maxOrdersPerSlot ?? FieldValue.delete(),
        'notice': notice.isEmpty ? FieldValue.delete() : notice,
        'openTime': settings.openTime ?? FieldValue.delete(),
        'closeTime': settings.closeTime ?? FieldValue.delete(),
        ...Stamp.updated(),
      }),
    );
  }

  @override
  Future<Result<void>> setSoldOut(String id, bool soldOut, {SoldOutReason? reason, DateTime? availableAgainAt}) =>
      guard(
        () => _items.doc(id).update({
          'soldOut': soldOut,
          'soldOutReason': soldOut && reason != null ? reason.name : FieldValue.delete(),
          'availableAgainAt': soldOut && availableAgainAt != null
              ? Timestamp.fromDate(availableAgainAt)
              : FieldValue.delete(),
          ...Stamp.updated(),
        }),
      );

  String? _validate(MenuItem item, String dishId) {
    if (item.kioskId.isEmpty) return 'Món phải thuộc một kiosk.';
    if (item.name.trim().isEmpty) return 'Nhập tên món.';
    if (dishId.isEmpty) return 'Tên món phải có chữ hoặc số.';
    if (item.priceVnd <= 0) return 'Giá món phải lớn hơn 0.';
    if (item.prepMinutes < 0) return 'Thời gian chuẩn bị không hợp lệ.';
    return null;
  }
}
