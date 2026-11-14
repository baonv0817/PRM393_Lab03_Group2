import 'package:breakbite_admin/ui/review_queue/view_models/review_queue_view_model.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/theme/order_stage.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:breakbite_core/ui/core/widgets/status_badge.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// W03 Review queue (list on the left, the selected order on the right).
/// Modernized with Novel Studio design language: segmented tabs with count pills,
/// studio-styled order cards with active border indicators, collapsible sections,
/// and refined fulfillment controls.
class ReviewQueueScreen extends StatelessWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The admin's kiosk picker changes the kiosk while this screen stays open: a new kiosk gets a new view model
    // (the key), so the screen never keeps listening to the previous kiosk.
    final kioskId = context.select<AdminSession, String?>((s) => s.kioskId)!;
    return ChangeNotifierProvider(
      key: ValueKey(kioskId),
      create: (context) => ReviewQueueViewModel(
        orders: context.read<OrderRepository>(),
        kioskId: kioskId,
        analytics: context.read<AnalyticsService>(),
        remoteConfig: context.read<RemoteConfigService>(),
      ),
      child: const _ReviewQueueView(),
    );
  }
}

class _ReviewQueueView extends StatefulWidget {
  const _ReviewQueueView();

  @override
  State<_ReviewQueueView> createState() => _ReviewQueueViewState();
}

class _ReviewQueueViewState extends State<_ReviewQueueView> {
  late final ReviewQueueViewModel _vm = context.read<ReviewQueueViewModel>();

  /// Currently active queue tab ('pending' = Chờ duyệt, 'in_progress' = Đang làm).
  String _activeTab = 'pending';

  /// Text filter for order code, customer name or dish name.
  String _searchQuery = '';

  /// Sort strategy: 'fifo' (oldest first), 'newest' (newest first), 'total' (highest value).
  String _sortBy = 'fifo';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.approve.addListener(_onApproved);
    _vm.reject.addListener(_onRejected);
  }

  @override
  void dispose() {
    _vm.approve.removeListener(_onApproved);
    _vm.reject.removeListener(_onRejected);
    _searchController.dispose();
    super.dispose();
  }

  void _onApproved() =>
      showCommandResult(context, _vm.approve, success: 'Đã duyệt đơn. Khách thấy ngay trên ứng dụng.');
  void _onRejected() => showCommandResult(context, _vm.reject, success: 'Đã từ chối đơn và gửi lý do cho khách.');

  List<Order> _filterAndSort(List<Order> source) {
    var items = source;
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((o) {
        final matchesCode = o.orderCode.toLowerCase().contains(query);
        final matchesCustomer = o.customerName.toLowerCase().contains(query);
        final matchesItems = o.items.any((item) => item.name.toLowerCase().contains(query));
        return matchesCode || matchesCustomer || matchesItems;
      }).toList();
    }
    switch (_sortBy) {
      case 'newest':
        return [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'total':
        return [...items]..sort((a, b) => b.totalVnd.compareTo(a.totalVnd));
      case 'fifo':
      default:
        return [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewQueueViewModel>();
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final waiting = vm.state.dataOrNull?.length ?? 0;
    final inProgress = vm.inProgressCount;

    return AdminPage(
      title: 'Duyệt đơn',
      subtitle: 'Đơn khách vừa đặt trên ứng dụng · $waiting chờ duyệt · $inProgress đang làm',
      child: ViewStateView<List<Order>>(
        state: vm.state,
        onRetry: vm.retry,
        builder: (context, pendingOrders) {
          final activeOrders = _activeTab == 'pending' ? pendingOrders : vm.inProgressOrders;
          final displayedOrders = _filterAndSort(activeOrders);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Studio Queue List
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      // Studio Tab Bar (Novel Studio context-tabs style)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: colors.border)),
                        ),
                        child: Row(
                          children: [
                            _StudioTabButton(
                              label: 'Chờ duyệt',
                              icon: Icons.hourglass_top_rounded,
                              count: waiting,
                              selected: _activeTab == 'pending',
                              onTap: () => setState(() => _activeTab = 'pending'),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _StudioTabButton(
                              label: 'Đang làm',
                              icon: Icons.soup_kitchen_outlined,
                              count: inProgress,
                              selected: _activeTab == 'in_progress',
                              onTap: () => setState(() => _activeTab = 'in_progress'),
                            ),
                          ],
                        ),
                      ),

                      // Studio Filter & Search Toolbar
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) => setState(() => _searchQuery = value),
                                style: text.bodyMedium,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Tìm mã đơn, tên khách, món...',
                                  hintStyle: text.bodyMedium?.copyWith(color: colors.muted),
                                  prefixIcon: Icon(Icons.search, size: 18, color: colors.muted),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.close, size: 16, color: colors.muted),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                  filled: true,
                                  fillColor: colors.surfaceVariant,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.chip),
                                    borderSide: BorderSide(color: colors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.chip),
                                    borderSide: BorderSide(color: colors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.chip),
                                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            PopupMenuButton<String>(
                              initialValue: _sortBy,
                              tooltip: 'Sắp xếp danh sách',
                              onSelected: (value) => setState(() => _sortBy = value),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'fifo', child: Text('Cũ nhất trước (FIFO)')),
                                const PopupMenuItem(value: 'newest', child: Text('Mới nhất trước')),
                                const PopupMenuItem(value: 'total', child: Text('Giá trị đơn cao nhất')),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colors.border),
                                  borderRadius: BorderRadius.circular(AppRadius.chip),
                                  color: colors.surfaceVariant,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sort_rounded, size: 18, color: colors.muted),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Icon(Icons.arrow_drop_down, size: 16, color: colors.muted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Order Items List
                      Expanded(
                        child: displayedOrders.isEmpty
                            ? _StudioEmptyQueue(
                                tab: _activeTab,
                                hasFilter: _searchQuery.isNotEmpty,
                                onClearFilter: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                                itemCount: displayedOrders.length,
                                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                                itemBuilder: (context, i) {
                                  final order = displayedOrders[i];
                                  final isSelected = order.id == vm.selected?.id;
                                  return _StudioOrderTile(
                                    order: order,
                                    selected: isSelected,
                                    onTap: () => vm.select(order),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Right Column: Studio Detail Panel
              Expanded(
                flex: 6,
                child: vm.selected == null
                    ? Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: colors.border),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_outlined, size: 48, color: colors.muted),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Chọn một đơn hàng bên trái để xem chi tiết và duyệt',
                                style: text.bodyLarge?.copyWith(color: colors.muted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _StudioOrderDetail(order: vm.selected!),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A tab button with icon and count pill inspired by Novel Studio's context-tabs.
class _StudioTabButton extends StatelessWidget {
  const _StudioTabButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? colors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: selected ? colors.selectedBorder : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? colors.primaryText : colors.muted),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: text.labelLarge?.copyWith(
                color: selected ? colors.primaryText : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? scheme.primary : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: text.labelSmall?.copyWith(
                  color: selected ? scheme.onPrimary : colors.muted,
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

/// Studio-styled order card with active border indicator and in-card collapsible preview.
class _StudioOrderTile extends StatefulWidget {
  const _StudioOrderTile({required this.order, required this.selected, required this.onTap});

  final Order order;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StudioOrderTile> createState() => _StudioOrderTileState();
}

class _StudioOrderTileState extends State<_StudioOrderTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final order = widget.order;
    final count = order.items.fold<int>(0, (sum, line) => sum + line.quantity);
    final isPending = order.status == OrderStatus.pending;

    // Check if order waited more than 10 minutes
    final waitMinutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isUrgent = isPending && waitMinutes >= 10;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: 'Đơn ${order.orderCode} của ${order.customerName}',
      child: Container(
        decoration: BoxDecoration(
          color: widget.selected ? colors.selected : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border(
            left: BorderSide(
              color: widget.selected ? scheme.primary : colors.border,
              width: widget.selected ? 4 : 1,
            ),
            top: BorderSide(color: widget.selected ? colors.selectedBorder : colors.border),
            right: BorderSide(color: widget.selected ? colors.selectedBorder : colors.border),
            bottom: BorderSide(color: widget.selected ? colors.selectedBorder : colors.border),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Code pill, Urgent tag, Total price
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        '#${order.orderCode}',
                        style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(
                          'Gấp · ${waitMinutes}p',
                          style: text.labelSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatVnd(order.totalVnd),
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: colors.primaryText),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Middle Row: Customer name and payment method
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 15, color: colors.muted),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        order.customerName.isEmpty ? 'Khách hàng' : order.customerName,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        paymentMethodLabel(order.paymentMethod),
                        style: text.labelSmall?.copyWith(color: colors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Bottom Row: Time placed, Item count, and Expand/Collapse toggle
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: colors.muted),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      formatTime(order.createdAt),
                      style: text.bodySmall?.copyWith(color: colors.muted),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('·', style: text.bodySmall?.copyWith(color: colors.muted)),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$count món',
                      style: text.bodySmall?.copyWith(color: colors.muted, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // Collapse / Expand toggle button for dishes preview
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded ? 'Thu gọn' : 'Xem món',
                              style: text.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Collapsible preview of items inside tile
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: AppSpacing.md),
                            for (final line in order.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${line.quantity}×',
                                        style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        line.displayName,
                                        style: text.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      formatVnd(line.lineTotalVnd),
                                      style: text.bodySmall?.copyWith(color: colors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            if (order.note.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Ghi chú: ${order.note}',
                                style: text.bodySmall?.copyWith(color: colors.primaryText, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Studio-styled right detail panel with collapsible dish groups, financial breakdown,
/// and interactive fulfillment decision zone.
class _StudioOrderDetail extends StatefulWidget {
  const _StudioOrderDetail({required this.order});

  final Order order;

  @override
  State<_StudioOrderDetail> createState() => _StudioOrderDetailState();
}

class _StudioOrderDetailState extends State<_StudioOrderDetail> {
  bool _itemsCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewQueueViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final order = widget.order;
    final busy = vm.approve.running || vm.reject.running;
    final totalCount = order.items.fold<int>(0, (sum, line) => sum + line.quantity);
    final isPending = order.status == OrderStatus.pending;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Eyebrow and Status Badge
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 16, color: colors.muted),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'CHI TIẾT ĐƠN HÀNG KIOSK',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: colors.muted,
                  ),
                ),
                const Spacer(),
                StatusBadge(
                  label: isPending ? 'Chờ duyệt' : 'Đang làm',
                  stage: OrderStage.of(order.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Order Code and Customer
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đơn #${order.orderCode}',
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            Text(
              '${order.customerName.isEmpty ? "Khách hàng" : order.customerName} · ${paymentMethodLabel(order.paymentMethod)}',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
            const SizedBox(height: AppSpacing.md),

            // Meta Info Grid
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thời gian đặt', style: text.labelSmall?.copyWith(color: colors.muted)),
                        const SizedBox(height: 2),
                        Text(formatTime(order.createdAt), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: colors.border),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thanh toán', style: text.labelSmall?.copyWith(color: colors.muted)),
                        const SizedBox(height: 2),
                        Text(orderPaymentLabel(order), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (order.pickupAt != null) ...[
                    Container(width: 1, height: 32, color: colors.border),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Giờ nhận hẹn', style: text.labelSmall?.copyWith(color: colors.muted)),
                          const SizedBox(height: 2),
                          Text(formatTime(order.pickupAt!), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: AppSpacing.xl),

            // Collapsible Dishes Section (Novel Studio Accordion)
            InkWell(
              onTap: () => setState(() => _itemsCollapsed = !_itemsCollapsed),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu_outlined, size: 20, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Danh sách món (${order.items.length} món · $totalCount phần)',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      _itemsCollapsed ? 'Mở rộng' : 'Thu gọn',
                      style: text.labelSmall?.copyWith(color: colors.muted),
                    ),
                    Icon(
                      _itemsCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _itemsCollapsed
                  ? Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Text(
                        order.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                        style: text.bodyMedium?.copyWith(color: colors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Column(
                      children: [
                        for (final line in order.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(AppRadius.input),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.selected,
                                      borderRadius: BorderRadius.circular(AppRadius.chip),
                                      border: Border.all(color: colors.selectedBorder),
                                    ),
                                    child: Text(
                                      '${line.quantity}×',
                                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: colors.primaryText),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(line.name, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                        if (line.optionsSummary.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            line.optionsSummary,
                                            style: text.bodySmall?.copyWith(color: colors.muted),
                                          ),
                                        ],
                                        if (line.note.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colors.selected,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Ghi chú: ${line.note}',
                                              style: text.bodySmall?.copyWith(color: colors.primaryText),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    formatVnd(line.lineTotalVnd),
                                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // Customer Order Note
            if (order.note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.selected,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: colors.selectedBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.speaker_notes_outlined, size: 18, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ghi chú đơn hàng:', style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: colors.primaryText)),
                          Text(order.note, style: text.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: AppSpacing.xl),

            // Billing Breakdown
            if (order.subtotalVnd > 0 && order.discountVnd > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tạm tính', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  Text(formatVnd(order.subtotalVnd), style: text.bodyMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Giảm giá (${order.voucherCode ?? "Voucher"})', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  Text('- ${formatVnd(order.discountVnd)}', style: text.bodyMedium?.copyWith(color: scheme.error)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Row(
              children: [
                Expanded(child: Text('Tổng thanh toán', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Text(
                  formatVnd(order.totalVnd),
                  style: text.headlineSmall?.copyWith(color: colors.primaryText, fontWeight: FontWeight.w800),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Fulfillment Decision Zone
            if (isPending) ...[
              Text('Thời gian làm xong dự kiến', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              _StudioReadyInPicker(key: ValueKey(order.id), busy: busy),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Từ chối đơn',
                icon: Icons.close_rounded,
                variant: AppButtonVariant.destructive,
                onPressed: busy ? null : () => _askReason(context, vm),
                loading: vm.reject.running,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: colors.success, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đang thực hiện chế biến món', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (order.pickupCode.isNotEmpty)
                            Text('Mã nhận của khách: #${order.pickupCode}', style: text.bodySmall?.copyWith(color: colors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _askReason(BuildContext context, ReviewQueueViewModel vm) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _StudioRejectDialog(order: widget.order, reasons: vm.rejectReasons),
    );
    if (reason != null) await vm.reject.execute(reason);
  }
}

/// Ready-in time picker with smooth pill choices and prominent primary approval action.
class _StudioReadyInPicker extends StatefulWidget {
  const _StudioReadyInPicker({super.key, required this.busy});

  final bool busy;

  @override
  State<_StudioReadyInPicker> createState() => _StudioReadyInPickerState();
}

class _StudioReadyInPickerState extends State<_StudioReadyInPicker> {
  int _minutes = ReviewQueueViewModel.readyInChoices.first;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReviewQueueViewModel>();
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final choices = [...ReviewQueueViewModel.readyInChoices]..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final m in choices)
              InkWell(
                onTap: widget.busy ? null : () => setState(() => _minutes = m),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: m == _minutes ? colors.selected : scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: m == _minutes ? scheme.primary : colors.border,
                      width: m == _minutes ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m == _minutes) ...[
                        Icon(Icons.check_rounded, size: 14, color: colors.primaryText),
                        const SizedBox(width: AppSpacing.xxs),
                      ],
                      Text(
                        '$m phút',
                        style: text.labelLarge?.copyWith(
                          color: m == _minutes ? colors.primaryText : scheme.onSurface,
                          fontWeight: m == _minutes ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Duyệt đơn · xong sau $_minutes phút',
          icon: Icons.check_circle_outline,
          large: true,
          loading: vm.approve.running,
          onPressed: widget.busy ? null : () => vm.approve.execute(Duration(minutes: _minutes)),
        ),
      ],
    );
  }
}

/// Studio-styled reject dialog with reasons selection chips and other-reason input.
class _StudioRejectDialog extends StatefulWidget {
  const _StudioRejectDialog({required this.order, required this.reasons});

  final Order order;
  final List<String> reasons;

  @override
  State<_StudioRejectDialog> createState() => _StudioRejectDialogState();
}

class _StudioRejectDialogState extends State<_StudioRejectDialog> {
  final _other = TextEditingController();
  late String? _picked = widget.reasons.first;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String get _reason => (_picked ?? _other.text).trim();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Row(
        children: [
          Icon(Icons.report_problem_outlined, color: scheme.error, size: 24),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text('Từ chối đơn #${widget.order.orderCode}?', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khách sẽ thấy lý do này trên ứng dụng điện thoại.', style: text.bodyMedium?.copyWith(color: colors.muted)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final r in widget.reasons)
                  AppChip(label: r, selected: r == _picked, onSelected: (_) => setState(() => _picked = r)),
                AppChip(
                  label: 'Lý do khác',
                  selected: _picked == null,
                  onSelected: (_) => setState(() => _picked = null),
                ),
              ],
            ),
            if (_picked == null) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Nhập lý do cụ thể', controller: _other, onChanged: (_) => setState(() {})),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Huỷ', style: text.labelLarge?.copyWith(color: colors.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _reason.isEmpty ? null : () => Navigator.pop(context, _reason),
          child: const Text('Từ chối đơn'),
        ),
      ],
    );
  }
}

/// Empty queue placeholder when no orders match the active tab or search filter.
class _StudioEmptyQueue extends StatelessWidget {
  const _StudioEmptyQueue({
    required this.tab,
    required this.hasFilter,
    required this.onClearFilter,
  });

  final String tab;
  final bool hasFilter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 40,
              color: colors.muted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasFilter
                  ? 'Không tìm thấy đơn phù hợp với từ khóa'
                  : tab == 'pending'
                      ? 'Không có đơn nào chờ duyệt'
                      : 'Không có đơn nào đang thực hiện',
              style: text.bodyMedium?.copyWith(color: colors.muted),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: onClearFilter,
                child: const Text('Xóa bộ lọc'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
