import 'package:breakbite/ui/seller_orders/view_models/seller_order_actions.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// K12: why an order is turned down. Returns the text to save, or `null` when staff keep the order.
/// The customer is refunded automatically (D04), so the dialog says so; a reason is required.
Future<String?> showRejectOrderDialog(BuildContext context, {required String orderCode}) => showDialog<String>(
  context: context,
  builder: (_) => _RejectDialog(orderCode: orderCode),
);

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.orderCode});

  final String orderCode;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  var _reason = RejectReason.soldOut;
  final _typed = TextEditingController();
  var _tried = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _send() {
    if (rejectReasonProblem(_reason, _typed.text) != null) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop(rejectReasonText(_reason, _typed.text));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final problem = _tried ? rejectReasonProblem(_reason, _typed.text) : null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      title: Text('Từ chối đơn #${widget.orderCode}?'),
      content: SingleChildScrollView(
        child: RadioGroup<RejectReason>(
          groupValue: _reason,
          onChanged: (value) => setState(() => _reason = value ?? _reason),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final reason in RejectReason.values)
                TestId(
                  'k12.reason.${reason.name}',
                  child: RadioListTile<RejectReason>(
                    contentPadding: EdgeInsets.zero,
                    value: reason,
                    title: Text(reason.label),
                  ),
                ),
              if (_reason == RejectReason.other || _typed.text.isNotEmpty)
                TestId(
                  'k12.text',
                  child: AppTextField(
                    label: _reason == RejectReason.other ? 'Lý do' : 'Ghi chú thêm (tuỳ chọn)',
                    controller: _typed,
                    errorText: problem,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text('Khách được hoàn tiền tự động.', style: text.bodyMedium?.copyWith(color: context.appColors.muted)),
            ],
          ),
        ),
      ),
      actions: [
        TestId(
          'k12.keep',
          child: AppButton(
            label: 'Giữ đơn',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        TestId(
          'k12.reject',
          child: FilledButton(
            onPressed: _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size(AppA11y.minTouchTarget, AppA11y.minTouchTarget),
              shape: const StadiumBorder(),
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: const Text('Từ chối'),
          ),
        ),
      ],
    );
  }
}
