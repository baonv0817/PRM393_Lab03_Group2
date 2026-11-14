import 'package:breakbite_admin/ui/menu_management/view_models/menu_management_view_model.dart';
import 'package:breakbite_admin/ui/menu_management/widgets/menu_item_dialog.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/domain/models/menu_item.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/menu_image.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:breakbite_core/ui/core/widgets/status_badge.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// W02 Management of menu items.
class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The admin's kiosk picker changes the kiosk while this screen stays open: a new kiosk gets a new view model
    // (the key), so the screen never keeps listening to the previous kiosk.
    final kioskId = context.select<AdminSession, String?>((s) => s.kioskId)!;
    return ChangeNotifierProvider(
      key: ValueKey(kioskId),
      create: (context) => MenuManagementViewModel(
        menu: context.read<MenuRepository>(),
        kioskId: kioskId,
        analytics: context.read<AnalyticsService>(),
      ),
      child: const _MenuManagementView(),
    );
  }
}

class _MenuManagementView extends StatefulWidget {
  const _MenuManagementView();

  @override
  State<_MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<_MenuManagementView> {
  late final MenuManagementViewModel _vm = context.read<MenuManagementViewModel>();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.toggleArchived.addListener(_onArchived);
  }

  @override
  void dispose() {
    _vm.toggleArchived.removeListener(_onArchived);
    _search.dispose();
    super.dispose();
  }

  void _onArchived() => showCommandResult(context, _vm.toggleArchived, success: 'Đã cập nhật món.');

  static const _labels = {
    MenuFilter.onSale: 'Đang bán',
    MenuFilter.soldOut: 'Tạm hết',
    MenuFilter.archived: 'Đã lưu trữ',
    MenuFilter.all: 'Tất cả',
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MenuManagementViewModel>();
    final counts = vm.counts;
    return AdminPage(
      title: 'Thực đơn',
      subtitle: 'Món khách thấy trên ứng dụng. Lưu trữ để ẩn món mà vẫn giữ lịch sử đơn và đánh giá.',
      actions: [AppButton(label: 'Thêm món', icon: Icons.add, onPressed: () => _edit(context, null))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 360,
                child: AppSearchField(hint: 'Tìm theo tên món', controller: _search, onChanged: vm.setQuery),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final f in MenuFilter.values)
                      AppChip(
                        label: '${_labels[f]} (${counts[f]})',
                        selected: vm.filter == f,
                        onSelected: (_) => vm.setFilter(f),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ViewStateView<List<MenuItem>>(
              state: vm.state,
              onRetry: vm.retry,
              builder: (context, items) => ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) => _ItemRow(item: items[i], onEdit: () => _edit(context, items[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, MenuItem? item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: _vm,
        child: MenuItemDialog(item: item),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item == null ? 'Đã thêm món. Khách thấy ngay trên ứng dụng.' : 'Đã lưu món.'),
          behavior: SnackBarBehavior.floating,
          width: 480,
        ),
      );
    }
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onEdit});

  final MenuItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MenuManagementViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final status = item.archived ? 'Đã lưu trữ' : (item.soldOut ? 'Tạm hết' : 'Đang bán');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Opacity(
              opacity: item.archived ? 0.4 : 1,
              child: MenuItemImage(imageUrl: item.imageUrl, size: 56),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${itemCategoryLabel(item.category)} · ${item.prepMinutes} phút · mã ${item.dishId}',
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(formatVnd(item.priceVnd), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 120,
            child: StatusBadge(label: status, warning: item.soldOut || item.archived),
          ),
          IconButton(
            tooltip: 'Sửa ${item.name}',
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded, size: 20, color: colors.primaryText),
          ),
          IconButton(
            tooltip: item.archived ? 'Khôi phục ${item.name}' : 'Lưu trữ ${item.name}',
            onPressed: vm.toggleArchived.running ? null : () => vm.toggleArchived.execute(item),
            icon: Icon(
              item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
              size: 20,
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
