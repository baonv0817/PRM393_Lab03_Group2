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

  /// What the customer just added and the cart has not shown yet, by line key. Adding goes through a Firestore
  /// transaction, which only completes after a round trip to the server, so without this the cart button and the
  /// counts would wait for the network. [target] is the quantity the line should have once the write shows up; a
  /// failed write drops it.
  final _adding = <String, ({String itemId, int target, bool confirmed})>{};

  Cart get value => _value;

  void start() {
    stop();
    _sub = cart.watchCart(uid).listen((current) {
      _value = current;
      _adding.removeWhere((key, add) => add.confirmed || _storedQuantity(key) >= add.target);
      _quantities.settle(_storedQuantity);
      _onChanged();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, '$_source.watchCart'));
  }

  void stop() => unawaited(_sub?.cancel());

  int get count {
    var total = 0;
    for (final line in _value.items) {
      total += quantityOfLine(line.lineKey);
    }
    // A line added a moment ago that is not in the snapshot yet counts for what it will be.
    for (final MapEntry(key: key, value: add) in _adding.entries) {
      if (_value.items.every((line) => line.lineKey != key)) total += add.target;
    }
    return total;
  }

  /// How many portions of the dish are in the cart, whatever options they were picked with.
  int quantityOf(String itemId) {
    final keys = {
      itemId,
      for (final line in _value.items)
        if (line.itemId == itemId) line.lineKey,
      for (final MapEntry(:key, :value) in _adding.entries)
        if (value.itemId == itemId) key,
    };
    return keys.fold(0, (sum, key) => sum + quantityOfLine(key));
  }

  /// How many portions of one line (a dish with one set of choices) are in the cart.
  int quantityOfLine(String lineKey) => _quantities.pendingOf(lineKey) ?? _shownQuantity(lineKey);

  int _shownQuantity(String lineKey) {
    final stored = _storedQuantity(lineKey);
    final adding = _adding[lineKey]?.target ?? 0;
    return adding > stored ? adding : stored;
  }

  int _storedQuantity(String lineKey) =>
      _value.items.where((line) => line.lineKey == lineKey).firstOrNull?.quantity ?? 0;

  bool canIncrease(String itemId) => quantityOf(itemId) < Cart.maxQuantity;

  /// How many more portions of one line fit in the cart.
  int roomForLine(String lineKey) => Cart.maxQuantity - quantityOfLine(lineKey);

  bool blocksAdd(MenuItem item) => !_value.isEmpty && _value.kioskId != item.kioskId;

  int roomFor(String itemId) => Cart.maxQuantity - quantityOf(itemId);

  /// Adds [quantity] portions of [item] with the picked [options] (empty for a dish without options). The line costs
  /// the dish plus the extras of the options.
  Future<Result<void>> add(
    MenuItem item, {
    int quantity = 1,
    String note = '',
    List<SelectedChoice> options = const [],
  }) async {
    final line = CartItem(
      itemId: item.id,
      name: item.name,
      priceVnd: item.priceVnd + options.fold(0, (sum, o) => sum + o.extraVnd),
      quantity: quantity,
      note: note,
      options: options,
    );
    final key = line.lineKey;
    final alreadyInCart = _storedQuantity(key) > 0;
    final target = (_shownQuantity(key) + quantity).clamp(0, Cart.maxQuantity);
    if (!blocksAdd(item)) {
      _adding[key] = (itemId: item.id, target: target, confirmed: false);
      _onChanged();
    }
    final result = await cart.addItem(uid, kioskId: item.kioskId, item: line);
    if (result case Ok() when alreadyInCart && note.isNotEmpty) {
      final noted = await cart.setNote(uid, key, note);
      if (noted case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, '$_source.addNote');
    }
    switch (result) {
      case Ok():
        // The snapshot with the new line may already be here: then there is nothing left to show early.
        if (_adding[key] case final add? when _storedQuantity(key) >= add.target) {
          _adding.remove(key);
        } else if (_adding.containsKey(key)) {
          _adding[key] = (itemId: item.id, target: target, confirmed: true);
        }
        _onChanged();
        await _logAdd(item, quantity);
      case Err(:final error):
        _adding.remove(key);
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
