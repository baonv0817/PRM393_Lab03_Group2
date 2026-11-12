import 'package:breakbite_core/domain/models/menu_item.dart';

/// A dish the customer marked with a heart (S04, S13). Kept per **dish**, not per menu item, so the favorite
/// follows the customer to another kiosk; the price and whether it is on sale come from the menu of the
/// kiosk they have selected.
class Favorite {
  const Favorite({
    required this.dishId,
    required this.name,
    required this.priceVnd,
    this.category,
    this.imageUrl,
    this.createdAt,
  });

  /// The favorite of [item]. A menu item id is `<kioskId>-<dishId>`; an item without a `dishId` uses its id.
  factory Favorite.of(MenuItem item) => Favorite(
    dishId: dishIdOf(item),
    name: item.name,
    priceVnd: item.priceVnd,
    category: item.category,
    imageUrl: item.imageUrl,
  );

  /// The id shared by every kiosk that sells the same dish.
  static String dishIdOf(MenuItem item) {
    if (item.dishId.isNotEmpty) return item.dishId;
    final prefix = '${item.kioskId}-';
    return item.kioskId.isNotEmpty && item.id.startsWith(prefix) ? item.id.substring(prefix.length) : item.id;
  }

  final String dishId;
  final String name;
  final int priceVnd;
  final ItemCategory? category;
  final String? imageUrl;
  final DateTime? createdAt;

  /// Whether [item] is this dish.
  bool matches(MenuItem item) => dishIdOf(item) == dishId;
}
