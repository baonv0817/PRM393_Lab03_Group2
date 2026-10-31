import 'cart_item.dart';

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
