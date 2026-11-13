import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/ui/seller_menu/view_models/menu_item_form_view_model.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// K14 (add an item) and K15 (edit one): photo, name, kind, price, preparation time and description. The errors
/// under the fields are K14-ERR.
///
/// K14 also has "Điền bằng AI" (docs/ai-feature.md): every field the AI filled is labelled [aiLabel] until staff
/// change it, and a notice asks them to check the suggestion before saving.
class MenuItemFormScreen extends StatelessWidget {
  const MenuItemFormScreen({super.key});

  /// The label of a field that still holds the AI's suggestion.
  static const aiLabel = 'Gợi ý từ AI';

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

  /// Asks the AI, then shows what it filled in the text fields (the view model already holds the values). A failure
  /// is not a passing message: it stays under the button (`vm.aiError`) until another photo is chosen.
  Future<void> _suggest() async {
    final vm = widget.vm;
    final result = await vm.suggest.execute();
    if (!mounted || result is! Ok<MenuItemSuggestion>) return;
    _name.text = vm.name;
    _price.text = vm.price;
    _description.text = vm.description;
    showAppMessage(context, 'AI đã điền gợi ý. Kiểm tra và sửa trước khi lưu.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final p = vm.isNew ? 'k14' : 'k15';
    String? aiHelper(AiField field) => vm.isAiSuggested(field) ? MenuItemFormScreen.aiLabel : null;
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
            _PhotoBox(vm: vm, prefix: p, onSuggest: _suggest),
            const SizedBox(height: AppSpacing.md),
            if (vm.hasAiSuggestion) ...[
              TestId('$p.ai.notice', child: const _AiNotice()),
              const SizedBox(height: AppSpacing.md),
            ],
            TestId(
              '$p.name',
              child: TextField(
                controller: _name,
                onChanged: vm.setName,
                maxLength: MenuItemFormViewModel.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Tên món',
                  hintText: 'Nhập tên món',
                  errorText: vm.nameError,
                  helperText: aiHelper(AiField.name),
                ),
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
            if (vm.isAiSuggested(AiField.category)) const _AiHint(),
            const SizedBox(height: AppSpacing.md),
            TestId(
              '$p.price',
              child: TextField(
                controller: _price,
                onChanged: vm.setPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                decoration: InputDecoration(
                  labelText: 'Giá (đ)',
                  hintText: 'Nhập giá',
                  errorText: vm.priceError,
                  helperText: aiHelper(AiField.price),
                ),
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
            if (vm.isAiSuggested(AiField.prep)) const _AiHint(),
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
                decoration: InputDecoration(
                  labelText: 'Mô tả (không bắt buộc)',
                  hintText: 'Thành phần, độ cay, kích cỡ…',
                  alignLabelWithHint: true,
                  helperText: aiHelper(AiField.description),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OptionGroupsEditor(groups: vm.optionGroups, onChanged: vm.setOptionGroups, problem: vm.optionsProblem),
          ],
        ),
      ),
    );
  }
}

/// The photo of the item: a picture (or a place for one), "Thư viện" and "Chụp ảnh" to choose it, and "Xoá ảnh"
/// to take it off. It is sent to Cloudinary when the item is saved; customers then see it on the menu.
class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.vm, required this.prefix, required this.onSuggest});

  final MenuItemFormViewModel vm;
  final String prefix;
  final VoidCallback onSuggest;

  Future<void> _pick(BuildContext context, PhotoSource source) async {
    final result = await vm.pickPhoto(source);
    if (!context.mounted) return;
    if (result case Err(:final error)) showAppMessage(context, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final busy = vm.photoBusy;
    final progress = vm.uploadProgress;
    final picked = vm.pickedPhoto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Ảnh món', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: AppSpacing.xs),
        TestId(
          '$prefix.photo',
          child: Semantics(
            label: vm.hasPhoto ? 'Ảnh món đã chọn' : 'Chưa có ảnh món',
            image: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: colors.surfaceVariant,
                  child: picked != null
                      ? Image.memory(picked, fit: BoxFit.cover)
                      : vm.photoUrl != null && vm.photoUrl!.isNotEmpty
                      ? LayoutBuilder(
                          builder: (context, box) =>
                              MenuItemImage(imageUrl: vm.photoUrl, size: box.maxWidth, height: box.maxHeight),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: colors.muted),
                              const SizedBox(height: AppSpacing.xs),
                              Text('Thêm ảnh món (tuỳ chọn)', style: text.bodyMedium?.copyWith(color: colors.muted)),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TestId(
            '$prefix.photo.progress',
            child: Semantics(
              label: 'Đang tải ảnh lên',
              value: '${(progress * 100).round()}%',
              child: LinearProgressIndicator(value: progress),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TestId(
                '$prefix.photo.gallery',
                child: AppButton(
                  label: 'Thư viện',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => _pick(context, PhotoSource.gallery),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TestId(
                '$prefix.photo.camera',
                child: AppButton(
                  label: 'Chụp ảnh',
                  icon: Icons.photo_camera_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => _pick(context, PhotoSource.camera),
                ),
              ),
            ),
          ],
        ),
        if (vm.aiAvailable) ...[
          const SizedBox(height: AppSpacing.xs),
          TestId(
            '$prefix.ai.suggest',
            child: AppButton(
              label: vm.suggest.running ? 'AI đang đọc ảnh…' : 'Điền bằng AI',
              icon: Icons.auto_awesome,
              loading: vm.suggest.running,
              semanticLabel: 'Điền bằng AI từ ảnh món',
              onPressed: vm.canSuggest ? onSuggest : null,
            ),
          ),
          if (vm.aiError case final message?) ...[
            const SizedBox(height: AppSpacing.xxs),
            TestId(
              '$prefix.ai.error',
              child: Semantics(
                liveRegion: true,
                child: Text(message, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          ],
          if (vm.pickedPhoto == null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Chọn hoặc chụp ảnh món để AI gợi ý tên, giá và mô tả. Chỉ chụp món, không chụp người.',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
          ],
        ],
        if (vm.hasPhoto)
          Align(
            alignment: Alignment.centerLeft,
            child: TestId(
              '$prefix.photo.remove',
              child: TextButton.icon(
                onPressed: busy ? null : vm.removePhoto,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xoá ảnh'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}

/// Says that some fields hold what the AI proposed and must be checked; it goes away once staff changed them all.
class _AiNotice extends StatelessWidget {
  const _AiNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${MenuItemFormScreen.aiLabel}. Kiểm tra và sửa các ô trước khi lưu.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.selected,
          border: Border.all(color: colors.selectedBorder),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${MenuItemFormScreen.aiLabel}. ',
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: 'AI có thể sai: kiểm tra và sửa các ô có nhãn này trước khi lưu.'),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Gợi ý từ AI" under a choice that is not a text field (the kind and the preparation time).
class _AiHint extends StatelessWidget {
  const _AiHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Text(
        MenuItemFormScreen.aiLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted),
      ),
    );
  }
}
