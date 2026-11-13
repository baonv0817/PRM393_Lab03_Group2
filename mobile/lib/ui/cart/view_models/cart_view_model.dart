import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_quote.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/domain/order_pricing.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/queued_quantities.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class CartViewModel extends ChangeNotifier with SafeChangeNotifier {
  CartViewModel({
    required this.cart,
    required this.menu,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) {
    quote = CartQuote(
      cart: cart,
      menu: menu,
      crash: crash,
      uid: uid,
      onChanged: _changed,
      clock: clock ?? DateTime.now,
      reason: 'cart',
    );
    clearCart = Command0(() => cart.clear(uid));
    removeVoucher = Command0(() => cart.setVoucher(uid, null));
    quote.start();
  }

  static const maxNoteLength = 100;

  final CartRepository cart;
  final MenuRepository menu;
  final CrashService crash;
  final String uid;

  /// The photo of each dish in the cart. A cart line keeps only the name and price, so the photos are read from the
  /// menu once per dish; until a photo arrives (or if the dish no longer exists) the row shows the logo.
  final _imageUrls = <String, String?>{};
  final _imagesRequested = <String>{};

  String? imageUrlOf(String itemId) => _imageUrls[itemId];

  late final CartQuote quote;
  late final Command0<void> clearCart;
  late final Command0<void> removeVoucher;
  late final _quantities = QueuedQuantities(
    write: (id, quantity) => cart.setQuantity(uid, id, quantity),
    onChanged: _changed,
  );

  void _changed() {
    _quantities.settle(_storedQuantity);
    notifyListeners();
    _loadImages();
  }

  void _loadImages() {
    final missing = [
      for (final line in quote.value.items)
        if (_imagesRequested.add(line.itemId)) line.itemId,
    ];
    if (missing.isEmpty) return;
    unawaited(() async {
      final result = await menu.getItems(missing);
      switch (result) {
        case Ok(:final value):
          for (final id in missing) {
            _imageUrls[id] = value[id]?.imageUrl;
          }
          notifyListeners();
        case Err():
          // A missing photo is not worth an error: let the next change of the cart try again.
          _imagesRequested.removeAll(missing);
      }
    }());
  }

  int _storedQuantity(String itemId) =>
      quote.value.items.where((line) => line.itemId == itemId).firstOrNull?.quantity ?? 0;

  List<CartItem> get items => [
    for (final line in quote.value.items)
      if ((_quantities.pendingOf(line.itemId) ?? line.quantity) case final quantity when quantity > 0)
        line.copyWith(quantity: quantity),
  ];

  ViewState<List<CartItem>> get state {
    if (quote.loadError case final message?) return ViewError(message);
    if (!quote.loaded) return const ViewLoading();
    return ViewStateX.fromList(items, emptyMessage: 'Giỏ hàng đang trống. Chọn vài món ngon nhé!');
  }

  int get itemCount => items.fold(0, (sum, line) => sum + line.quantity);
  Kiosk? get kiosk => quote.kiosk;
  Voucher? get voucher => quote.voucher;
  OrderPricing get pricing => quote.price(items);
  String? get voucherProblem => quote.voucherProblem(pricing.subtotalVnd);
  DateTime get readyAt => quote.readyAt;
  bool get pickupChosen => quote.value.pickupSlotId != null;

  String? get blocker => quote.kioskProblem ?? (voucherProblem == null ? null : 'Bỏ mã giảm giá để tiếp tục.');

  bool get canCheckout => items.isNotEmpty && blocker == null;

  int quantityOf(String itemId) => _quantities.pendingOf(itemId) ?? _storedQuantity(itemId);

  Future<Result<void>> changeQuantity(String itemId, int delta) async {
    final current = quantityOf(itemId);
    final next = (current + delta).clamp(0, Cart.maxQuantity);
    if (next == current) return const Result.ok(null);
    final result = await _quantities.set(itemId, next);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'cart.changeQuantity');
    return result;
  }

  Future<Result<void>> setNote(String itemId, String note) async {
    final trimmed = note.trim();
    final result = await cart.setNote(
      uid,
      itemId,
      trimmed.length > maxNoteLength ? trimmed.substring(0, maxNoteLength) : trimmed,
    );
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'cart.setNote');
    return result;
  }

  void retry() => quote.start();

  @override
  void dispose() {
    quote.stop();
    clearCart.dispose();
    removeVoucher.dispose();
    super.dispose();
  }
}
