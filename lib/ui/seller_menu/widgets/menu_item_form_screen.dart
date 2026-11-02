import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/ui/seller_menu/view_models/menu_item_form_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// K14 (add an item) and K15 (edit one): name, kind, price, preparation time and description. The errors
/// under the fields are K14-ERR.
class MenuItemFormScreen extends StatelessWidget {
  const MenuItemFormScreen({super.key});

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go(AppRoutes.sellerMenu);

  Future<void> _save(BuildContext context, MenuItemFormViewModel vm) async {
    final name = vm.name.trim();
    final result = await vm.save.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, vm.isNew ? 'Đã thêm "$name" vào thực đơn.' : 'Đã lưu thay đổi của "$name".');
        _back(context);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MenuItemFormViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: vm.isNew ? 'Thêm món mới' : 'Sửa món', onBack: () => _back(context), closes: vm.isNew),
      // In the bottom bar, not in the body: a message from the Scaffold then appears above the button
      // instead of covering it.
      bottomNavigationBar: vm.state is ViewData<MenuItem?>
          ? ListenableBuilder(
              listenable: vm.save,
              builder: (context, _) => BottomActionButton(
                label: vm.isNew ? 'Lưu món' : 'Lưu thay đổi',
                testId: '${vm.isNew ? 'k14' : 'k15'}.save',
                loading: vm.save.running,
                onPressed: vm.canSave && !vm.save.running ? () => _save(context, vm) : null,
              ),
            )
          : null,
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải món…'),
        ViewError(:final message) => TestId(
          'k15.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k14.empty',
          child: EmptyView(
            message: message ?? MenuItemFormViewModel.notFoundMessage,
            icon: Icons.restaurant_menu,
            actionLabel: 'Về quản lý món',
            onAction: () => context.go(AppRoutes.sellerMenu),
          ),
        ),
        ViewData() => _Form(vm: vm),
      },
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.vm});

  final MenuItemFormViewModel vm;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _name = TextEditingController(text: widget.vm.name);
  late final _price = TextEditingController(text: widget.vm.price);
  late final _description = TextEditingController(text: widget.vm.description);

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final p = vm.isNew ? 'k14' : 'k15';
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.md,
          ),
          children: [
            TestId(
              '$p.name',
              child: TextField(
                controller: _name,
                onChanged: vm.setName,
                maxLength: MenuItemFormViewModel.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Tên món', hintText: 'Nhập tên món', errorText: vm.nameError),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              header: true,
              child: Text('Danh mục', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final category in MenuItemFormViewModel.categories)
                  TestId(
                    '$p.category.${category.name}',
                    child: AppChip(
                      label: itemCategoryLabel(category),
                      selected: vm.category == category,
                      onSelected: (_) => vm.setCategory(category),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TestId(
              '$p.price',
              child: TextField(
                controller: _price,
                onChanged: vm.setPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                decoration: InputDecoration(labelText: 'Giá (đ)', hintText: 'Nhập giá', errorText: vm.priceError),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text('Thời gian chuẩn bị', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: AppSpacing.xs),
            ProfileSection(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('phút', style: text.bodyLarge?.copyWith(color: colors.muted)),
                    QuantityStepper(
                      name: 'thời gian chuẩn bị',
                      quantity: vm.prepMinutesValue,
                      testId: '$p.prep',
                      removesAtOne: false,
                      onDecrement: vm.prepMinutesValue > 0 ? () => vm.changePrepMinutes(-1) : null,
                      onIncrement: vm.prepMinutesValue < MenuItemFormViewModel.maxPrepMinutes
                          ? () => vm.changePrepMinutes(1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Còn hàng', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    TestId(
                      '$p.inStock',
                      child: Semantics(
                        label: 'Còn hàng',
                        toggled: vm.inStock,
                        child: Switch(value: vm.inStock, onChanged: vm.setInStock),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TestId(
              '$p.description',
              child: TextField(
                controller: _description,
                onChanged: vm.setDescription,
                minLines: 2,
                maxLines: 4,
                maxLength: MenuItemFormViewModel.maxDescriptionLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (không bắt buộc)',
                  hintText: 'Thành phần, độ cay, kích cỡ…',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
