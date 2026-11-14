import 'package:breakbite_admin/ui/menu_management/view_models/menu_management_view_model.dart';
import 'package:breakbite_core/domain/models/menu_item.dart';
import 'package:breakbite_core/domain/models/option_group.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/option_groups_editor.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Create a menu item ([item] is `null`) or edit one. Closes with `true` once Firestore accepted the write.
class MenuItemDialog extends StatefulWidget {
  const MenuItemDialog({super.key, required this.item});

  final MenuItem? item;

  @override
  State<MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<MenuItemDialog> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _price = TextEditingController(text: widget.item?.priceVnd.toString());
  late final _prep = TextEditingController(text: (widget.item?.prepMinutes ?? 5).toString());
  late final _description = TextEditingController(text: widget.item?.description);
  late final _image = TextEditingController(text: widget.item?.imageUrl);
  late ItemCategory _category = widget.item?.category ?? ItemCategory.food;
  late bool _soldOut = widget.item?.soldOut ?? false;
  late List<OptionGroup> _options = widget.item?.optionGroups ?? const [];
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _price, _prep, _description, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(MenuManagementViewModel vm) async {
    final price = int.tryParse(_price.text.replaceAll(RegExp('[^0-9]'), ''));
    final prep = int.tryParse(_prep.text.trim());
    if (price == null || prep == null) {
      setState(() => _error = 'Giá và thời gian chuẩn bị phải là số.');
      return;
    }
    if (optionGroupsProblem(_options) case final problem?) {
      setState(() => _error = problem);
      return;
    }
    final input = MenuItemInput(
      name: _name.text,
      priceVnd: price,
      category: _category,
      prepMinutes: prep,
      description: _description.text,
      imageUrl: _image.text,
      soldOut: _soldOut,
      optionGroups: _options,
    );
    final result = await vm.save.execute((widget.item, input));
    if (!mounted || result == null) return;
    switch (result) {
      case Ok():
        Navigator.pop(context, true);
      case Err(:final error):
        setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MenuManagementViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: colors.primaryText, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Text(widget.item == null ? 'Thêm món mới' : 'Sửa ${widget.item!.name}'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(label: 'Tên món', controller: _name),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Giá (đồng)',
                      controller: _price,
                      keyboardType: TextInputType.number,
                      helperText: 'Ví dụ 39000',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: 'Chuẩn bị (phút)',
                      controller: _prep,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ItemCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Loại món',
                  prefixIcon: Icon(Icons.category_outlined, size: 18),
                ),
                items: [
                  for (final c in ItemCategory.values) DropdownMenuItem(value: c, child: Text(itemCategoryLabel(c))),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Mô tả ngắn', controller: _description),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Ảnh (đường dẫn https hoặc assets/images/menu/…)',
                controller: _image,
                helperText: 'Để trống thì app hiện logo BreakBite',
              ),
              const SizedBox(height: AppSpacing.md),
              OptionGroupsEditor(groups: _options, onChanged: (g) => setState(() => _options = g)),
              const SizedBox(height: AppSpacing.xs),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                title: const Text('Tạm hết món'),
                value: _soldOut,
                onChanged: (v) => setState(() => _soldOut = v),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: vm.save.running ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton.icon(
          onPressed: vm.save.running ? null : () => _save(vm),
          icon: const Icon(Icons.save_outlined, size: 16),
          label: Text(vm.save.running ? 'Đang lưu…' : 'Lưu món'),
        ),
      ],
    );
  }
}
