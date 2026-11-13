import 'package:breakbite_core/domain/models/option_group.dart';

/// One line of a cart or an order. [priceVnd] is the price of one portion **with** the extras of [options], so every
/// total (cart, order, rules, statistics) is still `priceVnd * quantity` and does not know about options.
class CartItem {
  const CartItem({
    required this.itemId,
    required this.name,
    required this.priceVnd,
    this.quantity = 1,
    this.note = '',
    this.options = const [],
  });

  final String itemId;
  final String name;
  final int priceVnd;
  final int quantity;
  final String note;

  /// What the customer picked (size, toppings); empty for a dish without options.
  final List<SelectedChoice> options;

  int get lineTotalVnd => priceVnd * quantity;

  /// Tells lines apart: the same dish with other choices is another line, the same choices merge into one. Equal to
  /// [itemId] for a dish without options, so a line of such a dish keeps the key it always had.
  String get lineKey {
    if (options.isEmpty) return itemId;
    final ids = [for (final o in options) '${o.groupId}:${o.choiceId}']..sort();
    return '$itemId|${ids.join(',')}';
  }

  /// [lineKey] with only letters, digits and dashes, for the id a widget test or ARTEMIS finds the line by.
  String get lineSlug => lineKey.replaceAll(RegExp('[^A-Za-z0-9-]'), '-');

  /// "Size L · Thêm trứng"; empty when there are no options.
  String get optionsSummary => options.map((o) => o.name).join(' · ');

  /// The name with the choices after it, for a place that has one line: "Trà sữa (Size L · Trân châu)".
  String get displayName => options.isEmpty ? name : '$name ($optionsSummary)';

  /// What the portion costs on top of the dish's own price.
  int get extrasVnd => options.fold(0, (sum, o) => sum + o.extraVnd);

  CartItem copyWith({int? quantity, String? note, int? priceVnd}) => CartItem(
    itemId: itemId,
    name: name,
    priceVnd: priceVnd ?? this.priceVnd,
    quantity: quantity ?? this.quantity,
    note: note ?? this.note,
    options: options,
  );
}
