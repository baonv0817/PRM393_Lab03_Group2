import 'package:breakbite/domain/models/cart_item.dart';

/// Order lifecycle: pending → preparing → ready → delivered; can be cancelled before delivery.
enum OrderStatus { pending, preparing, ready, delivered, cancelled }

enum PaymentMethod { momo, vnpay, card, cash }

/// The simulated gateway records `paid` immediately; cash stays `unpaid` until staff collect the money.
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

  /// Short code shown to customers and staff (first 6 characters of the id, uppercased).
  final String orderCode;
  final String customerName;
  final String kioskName;
  final int subtotalVnd;
  final int discountVnd;
  final String? voucherCode;
  final PaymentStatus paymentStatus;
  final String? pickupSlotId;
  final DateTime? pickupAt;

  /// 6 random digits, embedded in the pickup QR code (S20, K05).
  final String pickupCode;
  final String note;
  final String? cancelReason;
  final CancelledBy? cancelledBy;
  final DateTime? updatedAt;

  /// Customers can only edit or cancel while the order is still pending.
  bool get customerCanEdit => status == OrderStatus.pending;

  /// QR code payload: staff scan it and check it against `pickupCode`.
  String get qrPayload => 'bb:$id:$pickupCode';
}
