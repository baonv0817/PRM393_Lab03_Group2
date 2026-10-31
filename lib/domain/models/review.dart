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

  /// Star rating 1–5.
  final int rating;
  final String comment;
  final DateTime createdAt;

  /// Document id: each item in an order can be reviewed only once.
  String get id => '${orderId}_$itemId';
}
