class Review {
  const Review({
    required this.orderId,
    required this.itemId,
    required this.kioskId,
    required this.uid,
    required this.rating,
    required this.createdAt,
    this.dishId = '',
    this.authorName = '',
    this.comment = '',
    this.tags = const [],
    this.updatedAt,
  });

  final String orderId;
  final String itemId;

  /// Reviews of the same dish are gathered across kiosks.
  final String dishId;
  final String kioskId;
  final String uid;

  /// Public name, already shortened with [publicAuthorName]; every signed-in user can read reviews.
  final String authorName;

  /// Star rating 1–5.
  final int rating;
  final String comment;

  /// Chips of S23: `tasty`, `fast`, `hot`, `wellPacked`.
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Document id: each item in an order can be reviewed only once.
  String get id => '${orderId}_$itemId';

  /// Name shown on a public review: the given name and the initial of the family name, so the full
  /// name never leaves the profile. Vietnamese names put the family name first:
  /// "Nguyễn Minh Quân" becomes "Quân N.".
  static String publicAuthorName(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Khách';
    if (parts.length == 1) return parts.single;
    return '${parts.last} ${String.fromCharCode(parts.first.runes.first).toUpperCase()}.';
  }
}
