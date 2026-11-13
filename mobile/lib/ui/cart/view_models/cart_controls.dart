import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/queued_quantities.dart';
import 'package:breakbite_core/utils/result.dart';

class CartControls {
  CartControls({
    required this.cart,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this._source,
    required this._onChanged,
  });

  final CartRepository cart;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String _source;
  final void Function() _onChanged;

  StreamSubscription<Cart>? _sub;
  Cart _value = Cart.empty;
  late final _quantities = QueuedQuantities(
    write: (id, quantity) => cart.setQuantity(uid, id, quantity),
    onChanged: _onChanged,
  );

  /// What the customer just added and the cart has not shown yet. Adding goes through a Firestore transaction, which
  /// only completes after a round trip to the server, so without this the cart button and the counts would wait for
  /// the network. [target] is the quantity the dish should have once the write shows up; a failed write drops it.
  final _adding = <String, ({int target, bool confirmed})>{};

  Cart get value => _value;

  void start() {
    stop();
    _sub = cart.watchCart(uid).listen((current) {
      _value = current;
      _adding.removeWhere((id, add) => add.confirmed || _storedQuantity(id) >= add.target);
      _quantities.settle(_storedQuantity);
      _onChanged();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, '$_source.watchCart'));
  }

  void stop() => unawaited(_sub?.cancel());

  int get count {
    var total = 0;
    for (final line in _value.items) {
      total += _quantities.pendingOf(line.itemId) ?? _shownQuantity(line.itemId);
    }
    // A dish added a moment ago that is not in the snapshot yet counts for what it will be.
    for (final MapEntry(key: id, value: add) in _adding.entries) {
      if (_value.items.every((line) => line.itemId != id)) total += add.target;
    }
    return total;
  }

  int quantityOf(String itemId) => _quantities.pendingOf(itemId) ?? _shownQuantity(itemId);

  int _shownQuantity(String itemId) {
    final stored = _storedQuantity(itemId);
    final adding = _adding[itemId]?.target ?? 0;
    return adding > stored ? adding : stored;
  }

  int _storedQuantity(String itemId) => _value.items.where((line) => line.itemId == itemId).firstOrNull?.quantity ?? 0;

  bool canIncrease(String itemId) => quantityOf(itemId) < Cart.maxQuantity;

  bool blocksAdd(MenuItem item) => !_value.isEmpty && _value.kioskId != item.kioskId;

  int roomFor(String itemId) => Cart.maxQuantity - quantityOf(itemId);

  Future<Result<void>> add(MenuItem item, {int quantity = 1, String note = ''}) async {
    final alreadyInCart = _storedQuantity(item.id) > 0;
    final target = (_shownQuantity(item.id) + quantity).clamp(0, Cart.maxQuantity);
    if (!blocksAdd(item)) {
      _adding[item.id] = (target: target, confirmed: false);
      _onChanged();
    }
    final result = await cart.addItem(
      uid,
      kioskId: item.kioskId,
      item: CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd, quantity: quantity, note: note),
    );
    if (result case Ok() when alreadyInCart && note.isNotEmpty) {
      final noted = await cart.setNote(uid, item.id, note);
      if (noted case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, '$_source.addNote');
    }
    switch (result) {
      case Ok():
        // The snapshot with the new line may already be here: then there is nothing left to show early.
        if (_adding[item.id] case final add? when _storedQuantity(item.id) >= add.target) {
          _adding.remove(item.id);
        } else if (_adding.containsKey(item.id)) {
          _adding[item.id] = (target: target, confirmed: true);
        }
        _onChanged();
        await _logAdd(item, quantity);
      case Err(:final error):
        _adding.remove(item.id);
        _onChanged();
        crash.recordNonFatal(error, error.stackTrace, '$_source.addToCart');
    }
    return result;
  }

  Future<Result<void>> change(MenuItem item, int delta) async {
    final current = quantityOf(item.id);
    final next = (current + delta).clamp(0, Cart.maxQuantity);
    if (next == current) return const Result.ok(null);
    if (delta > 0) unawaited(_logAdd(item, next - current));
    final result = await _quantities.set(item.id, next);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, '$_source.changeQuantity');
    return result;
  }

  Future<Result<int>> reorder(Order order) async {
    for (final item in order.items) {
      final result = await cart.addItem(uid, kioskId: order.kioskId, item: item);
      if (result case Err(:final error)) {
        crash.recordNonFatal(error, error.stackTrace, '$_source.reorder');
        return Result.error(error);
      }
    }
    await analytics.logEvent(AnalyticsEvents.reorder, {'order_id': order.id, 'item_count': order.items.length});
    return Result.ok(order.items.length);
  }

  Future<void> _logAdd(MenuItem item, int quantity) =>
      analytics.logEvent(AnalyticsEvents.addToCart, {'item_id': item.id, 'quantity': quantity, 'source': _source});
}
