import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/selectable_card.dart';
import 'package:breakbite/utils/format.dart';
import 'package:flutter/material.dart';

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
    required this.testId,
  });

  static IconData iconOf(PaymentMethod method) => switch (method) {
    PaymentMethod.momo => Icons.account_balance_wallet,
    PaymentMethod.vnpay => Icons.qr_code_2,
    PaymentMethod.card => Icons.credit_card,
    PaymentMethod.cash => Icons.payments_outlined,
  };

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  final String testId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final label = paymentMethodLabel(method);
    final hint = paymentMethodHint(method);
    return SelectableCard(
      testId: testId,
      selected: selected,
      onTap: onTap,
      semanticLabel: '$label. $hint',
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(iconOf(method), color: colors.primaryText),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(hint, style: text.bodyMedium?.copyWith(color: colors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
