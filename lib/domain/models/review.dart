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
