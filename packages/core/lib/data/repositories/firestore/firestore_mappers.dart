import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

typedef Json = Map<String, dynamic>;

String _string(Object? value, [String fallback = '']) => value is String ? value : fallback;

String? _stringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

int _int(Object? value, [int fallback = 0]) => value is num ? value.toInt() : fallback;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

bool _bool(Object? value, [bool fallback = false]) => value is bool ? value : fallback;

Json? _map(Object? value) => value is Map ? value.cast<String, dynamic>() : null;

AppUser appUserFromData(String uid, Json? data, {required String fallbackName, String? email, String? photoUrl}) =>
    AppUser(
      uid: uid,
      displayName: _stringOrNull(data?['displayName']) ?? fallbackName,
      role: readEnum(UserRole.values, data?['role'], UserRole.user),
      email: _stringOrNull(data?['email']) ?? email,
      photoUrl: _stringOrNull(data?['photoUrl']) ?? photoUrl,
      studentId: _stringOrNull(data?['studentId']),
      kioskId: _stringOrNull(data?['kioskId']),
      defaultKioskId: _stringOrNull(data?['defaultKioskId']),
    );

Kiosk kioskFromData(String id, Json data) => Kiosk(
  id: id,
  name: _string(data['name'], id),
  open: _bool(data['open']),
  waitMinutes: _int(data['waitMinutes']),
  location: _string(data['location']),
  openTime: _stringOrNull(data['openTime']),
  closeTime: _stringOrNull(data['closeTime']),
  notice: _stringOrNull(data['notice']),
  pausedUntil: readDate(data['pausedUntil']),
  maxOrdersPerSlot: _intOrNull(data['maxOrdersPerSlot']),
);

MenuItem menuItemFromData(String id, Json data) => MenuItem(
  id: id,
  name: _string(data['name']),
  priceVnd: _int(data['priceVnd']),
  category: readEnum(ItemCategory.values, data['category'], ItemCategory.other),
  prepMinutes: _int(data['prepMinutes']),
  dishId: _string(data['dishId']),
  soldOut: _bool(data['soldOut']),
  kioskId: _string(data['kioskId']),
  description: _string(data['description']),
  imageUrl: _stringOrNull(data['imageUrl']),
  availableAgainAt: readDate(data['availableAgainAt']),
  soldOutReason: switch (data['soldOutReason']) {
    final String name => SoldOutReason.values.asNameMap()[name],
    _ => null,
  },
);

Json menuItemToData(MenuItem item, {required String dishId}) => {
  'kioskId': item.kioskId,
  'dishId': dishId,
  'name': item.name.trim(),
  'searchName': searchKey(item.name),
  'description': item.description.trim(),
  'priceVnd': item.priceVnd,
  'category': item.category.name,
  'prepMinutes': item.prepMinutes,
  'soldOut': item.soldOut,
  'imageUrl': ?item.imageUrl,
};

VoucherDiscount? discountFromData(Object? value) {
  final map = _map(value);
  if (map == null) return null;
  final amount = _int(map['amountVnd']);
  final percent = _int(map['percent']);
  final maxVnd = _int(map['maxVnd']);
  return switch (map['type']) {
    'fixed' when amount > 0 => FixedDiscount(amount),
    'percent' when percent > 0 && percent <= 100 && maxVnd > 0 => PercentDiscount(percent: percent, maxVnd: maxVnd),
    _ => null,
  };
}

Voucher? voucherFromData(String code, Json data) {
  final discount = discountFromData(data['discount']);
  final expiresAt = readDate(data['expiresAt']);
  if (discount == null || expiresAt == null) return null;
  return Voucher(
    code: code,
    title: _string(data['title']),
    discount: discount,
    minOrderVnd: _int(data['minOrderVnd']),
    startsAt: readDate(data['startsAt']),
    expiresAt: expiresAt,
    activeFrom: _stringOrNull(data['activeFrom']),
    activeTo: _stringOrNull(data['activeTo']),
    active: _bool(data['active']),
  );
}

PickupSlot pickupSlotFromData(String id, Json data) {
  final startAt = readDateOr(data['startAt'], DateTime.fromMillisecondsSinceEpoch(0));
  return PickupSlot(
    id: id,
    startAt: startAt,
    endAt: readDateOr(data['endAt'], startAt),
    capacity: _int(data['capacity']),
    booked: _int(data['booked']),
  );
}

CartItem cartItemFromData(Object? value) {
  final map = _map(value) ?? const <String, dynamic>{};
  return CartItem(
    itemId: _string(map['itemId']),
    name: _string(map['name']),
    priceVnd: _int(map['priceVnd']),
    quantity: _int(map['quantity'], 1),
    note: _string(map['note']),
  );
}

Json cartItemToData(CartItem item) => {
  'itemId': item.itemId,
  'name': item.name,
  'priceVnd': item.priceVnd,
  'quantity': item.quantity,
  'note': item.note,
};

List<CartItem> _items(Object? value) => value is List ? value.map(cartItemFromData).toList() : const [];

Cart cartFromData(Json? data) {
  if (data == null) return Cart.empty;
  return Cart(
    kioskId: _stringOrNull(data['kioskId']),
    items: _items(data['items']),
    voucherCode: _stringOrNull(data['voucherCode']),
    pickupSlotId: _stringOrNull(data['pickupSlotId']),
    pickupAt: readDate(data['pickupAt']),
  );
}

Map<String, Object?> cartToData(Cart cart) => {
  'kioskId': cart.kioskId,
  'items': cart.items.map(cartItemToData).toList(),
  'voucherCode': cart.voucherCode,
  'pickupSlotId': cart.pickupSlotId,
  'pickupAt': switch (cart.pickupAt) {
    final DateTime at => Timestamp.fromDate(at),
    null => null,
  },
};

String orderCodeOf(String id) => (id.length > 6 ? id.substring(0, 6) : id).toUpperCase();

Order orderFromData(String id, Json data, {DateTime? now}) => Order(
  id: id,
  uid: _string(data['uid']),
  items: _items(data['items']),
  totalVnd: _int(data['totalVnd']),
  paymentMethod: readEnum(PaymentMethod.values, data['paymentMethod'], PaymentMethod.cash),
  status: readEnum(OrderStatus.values, data['status'], OrderStatus.pending),
  kioskId: _string(data['kioskId']),
  createdAt: readDateOr(data['createdAt'], now ?? DateTime.now()),
  orderCode: _stringOrNull(data['orderCode']) ?? orderCodeOf(id),
  customerName: _string(data['customerName']),
  kioskName: _string(data['kioskName']),
  subtotalVnd: _int(data['subtotalVnd'], _int(data['totalVnd'])),
  discountVnd: _int(data['discountVnd']),
  voucherCode: _stringOrNull(data['voucherCode']),
  paymentStatus: readEnum(PaymentStatus.values, data['paymentStatus'], PaymentStatus.unpaid),
  pickupSlotId: _stringOrNull(data['pickupSlotId']),
  pickupAt: readDate(data['pickupAt']),
  pickupCode: _string(data['pickupCode']),
  note: _string(data['note']),
  cancelReason: _stringOrNull(data['cancelReason']),
  cancelledBy: switch (data['cancelledBy']) {
    final String name => CancelledBy.values.asNameMap()[name],
    _ => null,
  },
  acceptedAt: readDate(data['acceptedAt']),
  readyBy: readDate(data['readyBy']),
  readyAt: readDate(data['readyAt']),
  prepSeconds: _intOrNull(data['prepSeconds']),
  deliveredAt: readDate(data['deliveredAt']),
  cancelledAt: readDate(data['cancelledAt']),
  updatedAt: readDate(data['updatedAt']),
);

Report reportFromData(String id, Json data, {required DateTime now}) => Report(
  id: id,
  uid: _string(data['uid']),
  fileName: _string(data['fileName']),
  url: _string(data['url']),
  publicId: _string(data['publicId']),
  sizeKb: _int(data['sizeKb']),
  createdAt: readDateOr(data['createdAt'], now),
  orderId: _stringOrNull(data['orderId']),
);

Review reviewFromData(String id, Json data, {required DateTime now}) => Review(
  orderId: _string(data['orderId']),
  itemId: _string(data['itemId']),
  dishId: _string(data['dishId']),
  kioskId: _string(data['kioskId']),
  uid: _string(data['uid']),
  authorName: _string(data['authorName']),
  rating: _int(data['rating']).clamp(0, 5),
  comment: _string(data['comment']),
  tags: switch (data['tags']) {
    final List<dynamic> list => [
      for (final tag in list)
        if (tag is String) tag,
    ],
    _ => const <String>[],
  },
  createdAt: readDateOr(data['createdAt'], now),
  updatedAt: readDate(data['updatedAt']),
);

Incident incidentFromData(String id, Json data, {required DateTime now}) => Incident(
  orderId: _string(data['orderId'], id),
  kioskId: _string(data['kioskId']),
  uid: _string(data['uid']),
  customerName: _string(data['customerName']),
  type: readEnum(IncidentType.values, data['type'], IncidentType.other),
  description: _string(data['description']),
  photoUrl: _stringOrNull(data['photoUrl']),
  status: readEnum(IncidentStatus.values, data['status'], IncidentStatus.open),
  resolution: switch (data['resolution']) {
    final String name => IncidentResolution.values.asNameMap()[name],
    _ => null,
  },
  resolutionNote: _stringOrNull(data['resolutionNote']),
  refundVnd: _intOrNull(data['refundVnd']),
  handledBy: _stringOrNull(data['handledBy']),
  createdAt: readDateOr(data['createdAt'], now),
  resolvedAt: readDate(data['resolvedAt']),
  updatedAt: readDate(data['updatedAt']),
);

UserProfile userProfileFromData(String uid, Json? data) => UserProfile(
  uid: uid,
  displayName: _string(data?['displayName']),
  email: _stringOrNull(data?['email']),
  studentId: _stringOrNull(data?['studentId']),
  phone: _stringOrNull(data?['phone']),
  defaultKioskId: _stringOrNull(data?['defaultKioskId']),
  defaultPaymentMethod: switch (data?['defaultPaymentMethod']) {
    final String name => PaymentMethod.values.asNameMap()[name],
    _ => null,
  },
);
