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
    this.availableAgainAt,
  });

  final String id;
  final String name;
  final int priceVnd;
  final ItemCategory category;
  final int prepMinutes;
  final String dishId;
  final bool soldOut;
  final String kioskId;
  final String description;
  final String? imageUrl;
  final DateTime? availableAgainAt;

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
    availableAgainAt: (soldOut ?? this.soldOut) ? availableAgainAt : null,
  );
}
