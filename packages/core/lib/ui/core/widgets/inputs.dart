import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: ChoiceChip(
        label: Text(label),
        labelStyle: text.labelLarge?.copyWith(color: selected ? colors.primaryText : scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surface,
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.5 : 1),
        shape: const StadiumBorder(),
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, required this.hint, this.onTap, this.controller, this.onChanged, this.focusNode})
    : assert(onTap != null || controller != null);

  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Lets the screen put the cursor in the field itself (S28 opens with the keyboard up).
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      borderSide: BorderSide(color: colors.border),
    );
    if (controller case final controller?) {
      return Semantics(
        textField: true,
        label: 'Tìm kiếm. $hint',
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: text.bodyMedium?.copyWith(color: colors.muted),
            filled: true,
            fillColor: colors.surfaceVariant,
            prefixIcon: Icon(Icons.search, size: 20, color: colors.muted),
            suffixIcon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : AppIconButton(
                      icon: Icons.close,
                      semanticLabel: 'Xoá từ khoá',
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                    ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: scheme.primary, width: 1.5)),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Tìm kiếm. $hint',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: colors.muted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  hint,
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.onChanged,
    this.obscureText = false,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppA11y.minTouchTarget),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          ),
        ),
      ),
    );
  }
}
