/// The three groups of Figma K14, S13 and S28. Stored as the enum name.
enum ItemCategory { food, drink, other }

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.category,
    required this.prepMinutes,
    this.dishId = '',
    this.soldOut = false,
    this.kioskId = '',
    this.description = '',
    this.imageUrl,
  });

  /// `{kioskId}-{dishId}`.
  final String id;
  final String name;
  final int priceVnd;
  final ItemCategory category;
  final int prepMinutes;

  /// The same dish sold at several kiosks shares this id; favorites and reviews are kept per dish.
  final String dishId;
  final bool soldOut;

  /// Kiosk that sells this item; each item belongs to exactly one kiosk.
  final String kioskId;
  final String description;

  /// Item image: path to an image bundled in the app (`assets/images/menu/…`) or an `https://` link
  /// to an image on Cloudinary `breakbite/menu/{kioskId}/…`.
  final String? imageUrl;

  MenuItem copyWith({bool? soldOut, int? priceVnd}) => MenuItem(
    id: id,
    name: name,
    priceVnd: priceVnd ?? this.priceVnd,
    category: category,
    prepMinutes: prepMinutes,
    dishId: dishId,
    soldOut: soldOut ?? this.soldOut,
    kioskId: kioskId,
    description: description,
    imageUrl: imageUrl,
  );
}
