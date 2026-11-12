class CartItem {
  const CartItem({required this.itemId, required this.name, required this.priceVnd, this.quantity = 1, this.note = ''});

  final String itemId;
  final String name;
  final int priceVnd;
  final int quantity;
  final String note;

  int get lineTotalVnd => priceVnd * quantity;

  CartItem copyWith({int? quantity, String? note}) => CartItem(
    itemId: itemId,
    name: name,
    priceVnd: priceVnd,
    quantity: quantity ?? this.quantity,
    note: note ?? this.note,
  );
}
