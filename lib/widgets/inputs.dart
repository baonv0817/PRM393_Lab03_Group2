import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// Chip lọc của Lab 2: mặc định, đang chọn.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surface,
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// TextField của Lab 2 với trạng thái lỗi và gợi ý.
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
