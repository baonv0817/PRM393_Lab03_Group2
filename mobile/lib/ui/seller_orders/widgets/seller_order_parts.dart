import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';

/// The white rounded box the seller screens put each block in.
class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.child, this.color, this.borderColor, this.borderWidth = 1});

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: borderColor ?? context.appColors.border, width: borderWidth),
    ),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child),
  );
}

/// The lines of an order with the customer's note under each, and the order's own note in a warm box.
/// [checks] (K04) puts a check box in front of each line.
class OrderLinesCard extends StatelessWidget {
  const OrderLinesCard({super.key, required this.order, this.checked, this.onToggle, this.idPrefix = 'k03'});

  final Order order;
  final bool Function(int index)? checked;
  final ValueChanged<int>? onToggle;
  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return SellerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < order.items.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            _Line(
              item: order.items[i],
              checked: checked?.call(i),
              onToggle: onToggle == null ? null : () => onToggle!(i),
              testId: '$idPrefix.line.$i',
              text: text,
              muted: colors.muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.item,
    required this.checked,
    required this.onToggle,
    required this.testId,
    required this.text,
    required this.muted,
  });

  final CartItem item;
  final bool? checked;
  final VoidCallback? onToggle;
  final String testId;
  final TextTheme text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (checked != null) ...[
          ExcludeSemantics(
            child: Checkbox(value: checked, onChanged: (_) => onToggle?.call()),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.name} ×${item.quantity}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (item.options.isNotEmpty)
                TestId('$testId.options', child: Text(item.optionsSummary, style: text.bodyLarge)),
              if (item.note.isNotEmpty) Text(item.note, style: text.bodyMedium?.copyWith(color: muted)),
            ],
          ),
        ),
      ],
    );
    if (onToggle == null) return TestId(testId, child: body);
    return TestId(
      testId,
      child: Semantics(
        checked: checked,
        label: '${item.displayName} ×${item.quantity}',
        child: InkWell(
          onTap: onToggle,
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: body),
        ),
      ),
    );
  }
}

/// "Ghi chú: không hành tây" in a warm box, or nothing when the customer wrote none.
class OrderNoteCard extends StatelessWidget {
  const OrderNoteCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (order.note.trim().isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TestId(
        'k03.note',
        child: SellerCard(
          color: colors.selected,
          borderColor: colors.selectedBorder,
          child: SizedBox(
            width: double.infinity,
            child: Text('Ghi chú: ${order.note.trim()}', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ),
    );
  }
}

/// How the order is paid. Cash gets a warm box with the amount, so it is not forgotten at the handover.
class OrderPaymentCard extends StatelessWidget {
  const OrderPaymentCard({super.key, required this.order, this.idPrefix = 'k03'});

  final Order order;
  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final unpaid = order.paymentStatus == PaymentStatus.unpaid;
    return TestId(
      '$idPrefix.payment',
      child: SellerCard(
        child: Row(
          children: [
            Icon(unpaid ? Icons.payments_outlined : Icons.check, color: unpaid ? colors.primaryText : colors.success),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                unpaid
                    ? 'Trả tại quầy ${formatVnd(order.totalVnd)}'
                    : 'Đã thanh toán ${paymentMethodLabel(order.paymentMethod)} · ${formatVnd(order.totalVnd)}',
                style: text.bodyLarge?.copyWith(
                  color: unpaid ? colors.primaryText : colors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The text of a finished, cancelled or missing order on the seller's screens.
String sellerOrderStatusLabel(Order order) => switch (order.status) {
  OrderStatus.pending => 'Mới',
  OrderStatus.preparing => 'Đang làm',
  OrderStatus.ready => 'Sẵn sàng',
  OrderStatus.delivered => 'Đã giao',
  OrderStatus.cancelled => 'Đã huỷ',
};
