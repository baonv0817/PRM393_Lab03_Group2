import 'dart:async';

import 'package:breakbite_core/domain/models/menu_item.dart';
import 'package:breakbite_core/ui/core/widgets/cards_and_bars.dart';
import 'package:breakbite_core/ui/core/widgets/fly_to_cart.dart';
import 'package:breakbite_core/ui/core/widgets/menu_image.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

const cartFabClearance = 96.0;

class CartFlight {
  final cartKey = GlobalKey();
  final _imageKeys = <String, GlobalKey>{};

  GlobalKey imageKeyOf(String itemId) => _imageKeys.putIfAbsent(itemId, GlobalKey.new);

  Future<void> add(
    BuildContext context, {
    required MenuItem item,
    required bool blocked,
    required Future<Result<void>?> Function() write,
  }) async {
    if (!blocked) {
      unawaited(
        flyToCart(
          context: context,
          from: imageKeyOf(item.id),
          to: cartKey,
          child: MenuItemImage(imageUrl: item.imageUrl),
        ),
      );
    }
    final result = await write();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        unawaited(
          SemanticsService.sendAnnouncement(View.of(context), 'Đã thêm ${item.name} vào giỏ', TextDirection.ltr),
        );
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> change(BuildContext context, Future<Result<void>> Function() write) async {
    final result = await write();
    if (context.mounted) showResultError(context, result);
  }
}

class CartFab extends StatelessWidget {
  const CartFab({super.key, required this.flight, required this.count, required this.onPressed, required this.testId});

  static const size = 56.0;

  final CartFlight flight;
  final int count;
  final VoidCallback onPressed;
  final String testId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return KeyedSubtree(
      key: flight.cartKey,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: count == 0
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : BumpOnIncrease(
                  key: const ValueKey('cart'),
                  value: count,
                  child: TestId(
                    testId,
                    child: FloatingActionButton(
                      heroTag: null,
                      onPressed: onPressed,
                      tooltip: 'Giỏ hàng, $count món',
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: const CircleBorder(),
                      child: Badge(
                        backgroundColor: scheme.onPrimary,
                        textColor: scheme.surface,
                        textStyle: text.labelLarge?.copyWith(fontSize: 12),
                        label: Text('$count'),
                        child: const Icon(Icons.shopping_cart),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
