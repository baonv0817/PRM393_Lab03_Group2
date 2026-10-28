/// Mô hình dữ liệu thuần (không phụ thuộc Flutter hay Firebase).
/// Ánh xạ với collection Firestore trong `docs/architecture.md` mục 6.
library;

enum UserRole { user, staff, admin }

class AppUser {
  const AppUser({required this.uid, required this.displayName, required this.role});

  final String uid;
  final String displayName;
  final UserRole role;

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
  });

  final String id;
  final String name;
  final int priceVnd;
  final String category;
  final int prepMinutes;
  final bool soldOut;
}

class Kiosk {
  const Kiosk({required this.id, required this.name, required this.open, required this.waitMinutes});

  final String id;
  final String name;
  final bool open;
  final int waitMinutes;
}

class Voucher {
  const Voucher({required this.code, required this.discountVnd, required this.expiresAt, required this.minOrderVnd});

  final String code;
  final int discountVnd;
  final DateTime expiresAt;
  final int minOrderVnd;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);
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

enum OrderStatus { pending, preparing, ready, delivered, cancelled }

enum PaymentMethod { momo, vnpay, card, cash }

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
  });

  final String id;
  final String uid;
  final List<CartItem> items;
  final int totalVnd;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final String kioskId;
  final DateTime createdAt;
}

class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body, required this.receivedAt, this.orderId});

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// Màn liên quan khi chạm vào thông báo (nếu có).
  final String? orderId;
}
