/// Mô hình dữ liệu thuần (không phụ thuộc Flutter hay Firebase).
/// Ánh xạ với collection Firestore trong `docs/data-model.md`: tên trường giữ nguyên ở đó;
/// việc đổi `Timestamp` sang `DateTime` làm ở `lib/firebase/`.
library;

enum UserRole { user, staff, admin }

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    this.email,
    this.photoUrl,
    this.studentId,
    this.kioskId,
  });

  final String uid;
  final String displayName;
  final UserRole role;
  final String? email;
  final String? photoUrl;

  /// Mã số sinh viên (S16).
  final String? studentId;

  /// Kiosk nhân viên phụ trách; chỉ có với staff.
  final String? kioskId;

  bool get isStaff => role == UserRole.staff || role == UserRole.admin;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.category,
    required this.prepMinutes,
    this.soldOut = false,
    this.kioskId = '',
    this.description = '',
    this.imageUrl,
  });

  final String id;
  final String name;
  final int priceVnd;
  final String category;
  final int prepMinutes;
  final bool soldOut;

  /// Kiosk bán món này; mỗi món thuộc đúng một kiosk.
  final String kioskId;
  final String description;

  /// Ảnh trong Cloud Storage `menu/{kioskId}/…` hoặc ảnh đóng gói sẵn.
  final String? imageUrl;
}

class Kiosk {
  const Kiosk({
    required this.id,
    required this.name,
    required this.open,
    required this.waitMinutes,
    this.location = '',
    this.openTime,
    this.closeTime,
    this.notice,
  });

  final String id;
  final String name;
  final bool open;
  final int waitMinutes;

  /// Địa điểm đầy đủ, ví dụ "Campus Q9, tầng 2".
  final String location;

  /// Giờ mở và đóng cửa dạng "HH:mm".
  final String? openTime;
  final String? closeTime;

  /// Thông báo hiện ở Trang chủ khi quán đóng hoặc có thay đổi (S21).
  final String? notice;
}

/// Một khung giờ nhận món của kiosk, ứng với giờ ra chơi giữa hai slot (S25).
class PickupSlot {
  const PickupSlot({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.booked,
  });

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final int booked;

  int get remaining => capacity - booked;
  bool get isFull => booked >= capacity;
}

class Voucher {
  const Voucher({
    required this.code,
    required this.discountVnd,
    required this.expiresAt,
    required this.minOrderVnd,
    this.title = '',
    this.percent,
    this.maxDiscountVnd,
    this.active = true,
  });

  final String code;

  /// Giảm cố định (VND). Khi `percent` có giá trị thì dùng giảm theo phần trăm.
  final int discountVnd;
  final DateTime expiresAt;
  final int minOrderVnd;
  final String title;

  /// Giảm theo phần trăm (1–100), kèm trần `maxDiscountVnd`.
  final int? percent;
  final int? maxDiscountVnd;
  final bool active;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  /// Số tiền giảm cho một đơn có tạm tính `subtotalVnd`; 0 nếu chưa đủ điều kiện.
  int discountFor(int subtotalVnd, DateTime now) {
    if (!active || isExpired(now) || subtotalVnd < minOrderVnd) return 0;
    final raw = percent == null ? discountVnd : subtotalVnd * percent! ~/ 100;
    final capped = maxDiscountVnd == null || raw < maxDiscountVnd! ? raw : maxDiscountVnd!;
    return capped > subtotalVnd ? subtotalVnd : capped;
  }
}

class CartItem {
  const CartItem({required this.itemId, required this.name, required this.priceVnd, this.quantity = 1, this.note = ''});

  final String itemId;
  final String name;
  final int priceVnd;
  final int quantity;
  final String note;

  int get lineTotalVnd => priceVnd * quantity;

  CartItem copyWith({int? quantity, String? note}) => CartItem(
        itemId: itemId,
        name: name,
        priceVnd: priceVnd,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
      );
}

/// Vòng đời đơn: pending → preparing → ready → delivered; huỷ được khi chưa giao.
enum OrderStatus { pending, preparing, ready, delivered, cancelled }

enum PaymentMethod { momo, vnpay, card, cash }

/// Cổng mô phỏng ghi nhận `paid` ngay; tiền mặt là `unpaid` đến khi nhân viên thu tiền.
enum PaymentStatus { unpaid, paid }

enum CancelledBy { customer, staff }

class Order {
  const Order({
    required this.id,
    required this.uid,
    required this.items,
    required this.totalVnd,
    required this.paymentMethod,
    required this.status,
    required this.kioskId,
    required this.createdAt,
    this.orderCode = '',
    this.customerName = '',
    this.kioskName = '',
    this.subtotalVnd = 0,
    this.discountVnd = 0,
    this.voucherCode,
    this.paymentStatus = PaymentStatus.paid,
    this.pickupSlotId,
    this.pickupAt,
    this.pickupCode = '',
    this.note = '',
    this.cancelReason,
    this.cancelledBy,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final List<CartItem> items;
  final int totalVnd;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final String kioskId;
  final DateTime createdAt;

  /// Mã ngắn hiện cho khách và nhân viên (6 ký tự đầu của id, viết hoa).
  final String orderCode;
  final String customerName;
  final String kioskName;
  final int subtotalVnd;
  final int discountVnd;
  final String? voucherCode;
  final PaymentStatus paymentStatus;
  final String? pickupSlotId;
  final DateTime? pickupAt;

  /// 6 chữ số ngẫu nhiên, nằm trong mã QR nhận món (S20, K05).
  final String pickupCode;
  final String note;
  final String? cancelReason;
  final CancelledBy? cancelledBy;
  final DateTime? updatedAt;

  /// Khách chỉ sửa hoặc huỷ được khi đơn còn pending.
  bool get customerCanEdit => status == OrderStatus.pending;

  /// Nội dung mã QR: nhân viên quét rồi đối chiếu `pickupCode`.
  String get qrPayload => 'bb:$id:$pickupCode';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.orderId,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// Màn liên quan khi chạm vào thông báo (nếu có).
  final String? orderId;
  final bool read;
}

class Review {
  const Review({
    required this.orderId,
    required this.itemId,
    required this.kioskId,
    required this.uid,
    required this.rating,
    required this.createdAt,
    this.authorName = '',
    this.comment = '',
  });

  final String orderId;
  final String itemId;
  final String kioskId;
  final String uid;
  final String authorName;

  /// Số sao 1–5.
  final int rating;
  final String comment;
  final DateTime createdAt;

  /// Id tài liệu: mỗi món trong một đơn chỉ đánh giá một lần.
  String get id => '${orderId}_$itemId';
}

enum IncidentType { wrongItem, missingItem, quality, late, other }

enum IncidentStatus { open, inProgress, resolved }

class Incident {
  const Incident({
    required this.id,
    required this.orderId,
    required this.kioskId,
    required this.uid,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
    this.customerName = '',
    this.photoUrl,
    this.resolution,
    this.handledBy,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String kioskId;
  final String uid;
  final String customerName;
  final IncidentType type;
  final String description;
  final String? photoUrl;
  final IncidentStatus status;
  final String? resolution;
  final String? handledBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}
