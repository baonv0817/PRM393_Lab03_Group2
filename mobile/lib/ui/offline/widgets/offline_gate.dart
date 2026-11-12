import 'package:breakbite/ui/offline/view_models/connectivity_view_model.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// S30: puts "Mất kết nối mạng" over the whole app while the phone is offline. [child] stays mounted below it,
/// so nothing the customer was doing is lost; [onViewCart] is how "Xem giỏ hàng" gets to the cart.
class OfflineGate extends StatelessWidget {
  const OfflineGate({super.key, required this.child, required this.onViewCart, this.canViewCart = true});

  final Widget child;
  final VoidCallback onViewCart;

  /// A signed-in customer has a cart to look at; staff and signed-out users do not.
  final bool canViewCart;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConnectivityViewModel>();
    return Stack(
      children: [
        child,
        if (vm.showOffline)
          Positioned.fill(
            child: OfflineScreen(
              checking: vm.checking,
              onRetry: vm.retry,
              onViewCart: canViewCart
                  ? () {
                      vm.dismiss();
                      onViewCart();
                    }
                  : null,
            ),
          ),
      ],
    );
  }
}

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.checking, required this.onRetry, required this.onViewCart});

  final bool checking;
  final VoidCallback onRetry;
  final VoidCallback? onViewCart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Semantics(
                liveRegion: true,
                child: TestId(
                  's30.offline',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.sheet),
                        ),
                        child: Icon(Icons.priority_high, size: 48, color: scheme.error, semanticLabel: 'Lỗi'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Mất kết nối mạng', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Giỏ hàng vẫn được giữ trên máy. Hãy thử lại khi có mạng.',
                        style: text.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: TestId(
                          's30.retry',
                          child: AppButton(label: 'Thử lại', loading: checking, onPressed: onRetry),
                        ),
                      ),
                      if (onViewCart != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TestId(
                          's30.cart',
                          child: AppButton(
                            label: 'Xem giỏ hàng',
                            variant: AppButtonVariant.text,
                            onPressed: onViewCart,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
