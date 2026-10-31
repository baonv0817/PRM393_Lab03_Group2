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

  /// Kiosk that sells this item; each item belongs to exactly one kiosk.
  final String kioskId;
  final String description;

  /// Item image: path to an image bundled in the app (`assets/images/menu/…`) or an `https://` link
  /// to an image in Cloud Storage `menu/{kioskId}/…`.
  final String? imageUrl;

  MenuItem copyWith({bool? soldOut}) => MenuItem(
    id: id,
    name: name,
    priceVnd: priceVnd,
    category: category,
    prepMinutes: prepMinutes,
    soldOut: soldOut ?? this.soldOut,
    kioskId: kioskId,
    description: description,
    imageUrl: imageUrl,
  );
}
