import 'package:breakbite_core/domain/models/cart_item.dart';
import 'package:breakbite_core/domain/models/menu_item.dart';

/// What happened to one cart line since it was added.
sealed class CartLineChange {
  const CartLineChange(this.line);

  final CartItem line;
}

final class PriceChanged extends CartLineChange {
  const PriceChanged(super.line, {required this.newPriceVnd});

  final int newPriceVnd;
}

final class NowSoldOut extends CartLineChange {
  const NowSoldOut(super.line);
}

/// The kiosk no longer sells this item.
final class NoLongerSold extends CartLineChange {
  const NoLongerSold(super.line);
}

class RepricedCart {
  const RepricedCart(this.lines, this.changes);

  /// Lines that can still be ordered, at today's price.
  final List<CartItem> lines;
  final List<CartLineChange> changes;

  bool get hasChanges => changes.isNotEmpty;

  int get subtotalVnd => lines.fold(0, (sum, line) => sum + line.lineTotalVnd);
}

/// Checks a cart against the current menu right before placing the order (S06). Prices in a cart
/// are a snapshot from when the item was added and the rules cannot check each line, so the app
/// must not place an order at an old price: when [RepricedCart.hasChanges], show the changes, save
/// the new lines to the cart and let the customer confirm again.
RepricedCart repriceCart(List<CartItem> lines, Map<String, MenuItem> currentById) {
  final kept = <CartItem>[];
  final changes = <CartLineChange>[];
  for (final line in lines) {
    final current = currentById[line.itemId];
    if (current == null) {
      changes.add(NoLongerSold(line));
    } else if (current.soldOut) {
      changes.add(NowSoldOut(line));
    } else if (current.priceVnd != line.priceVnd) {
      changes.add(PriceChanged(line, newPriceVnd: current.priceVnd));
      kept.add(
        CartItem(
          itemId: line.itemId,
          name: line.name,
          priceVnd: current.priceVnd,
          quantity: line.quantity,
          note: line.note,
        ),
      );
    } else {
      kept.add(line);
    }
  }
  return RepricedCart(kept, changes);
}
