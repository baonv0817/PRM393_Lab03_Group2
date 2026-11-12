import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/orders/view_models/admin_orders_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String orderStatusText(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'Chờ kiosk nhận',
  OrderStatus.preparing => 'Đang làm',
  OrderStatus.ready => 'Sẵn sàng',
  OrderStatus.delivered => 'Đã giao',
  OrderStatus.cancelled => 'Đã huỷ',
};

/// A06: every order of every kiosk, filters on top, "Tải thêm" at the bottom, a detail of one order on tap.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminOrdersViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return AdminPage(
      title: 'Đơn hàng',
      subtitle: 'Xem đơn của mọi kiosk. Chỉ xem: nhân viên của kiosk mới xử lý đơn (K02).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 260,
                child: TestId(
                  'a06.kiosk',
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: vm.kioskId,
                    decoration: const InputDecoration(labelText: 'Kiosk'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Mọi kiosk')),
                      for (final k in vm.kiosks) DropdownMenuItem<String?>(value: k.id, child: Text(k.name)),
                    ],
                    onChanged: vm.setKiosk,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TestId(
                  'a06.search',
                  child: AppSearchField(
                    hint: 'Tìm theo mã đơn, tên khách hoặc mã nhận món',
                    controller: _search,
                    onChanged: vm.setSearch,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (range, label) in [
                (OrderRange.today, 'Hôm nay'),
                (OrderRange.week, '7 ngày'),
                (OrderRange.month, '30 ngày'),
                (OrderRange.all, 'Tất cả'),
              ])
                TestId(
                  'a06.range.${range.name}',
                  child: AppChip(label: label, selected: vm.range == range, onSelected: (_) => vm.setRange(range)),
                ),
              const SizedBox(width: AppSpacing.md),
              TestId(
                'a06.status.all',
                child: AppChip(
                  label: 'Mọi trạng thái',
                  selected: vm.status == null && !vm.stuckOnly,
                  onSelected: (_) => vm.setStatus(null),
                ),
              ),
              for (final status in OrderStatus.values)
                TestId(
                  'a06.status.${status.name}',
                  child: AppChip(
                    label: orderStatusText(status),
                    selected: vm.status == status && !vm.stuckOnly,
                    onSelected: (_) => vm.setStatus(status),
                  ),
                ),
              TestId(
                'a06.stuck',
                child: AppChip(
                  label: vm.stuckOnly || vm.stuckCount == 0 ? 'Đơn kẹt' : 'Đơn kẹt (${vm.stuckCount})',
                  selected: vm.stuckOnly,
                  onSelected: vm.setStuckOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: switch (vm.state) {
              ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
              ViewError(:final message) => TestId(
                'a06.retry',
                child: ErrorView(message: message, onRetry: vm.load),
              ),
              ViewEmpty(:final message) => TestId(
                'a06.empty',
                child: EmptyView(
                  message: message ?? AdminOrdersViewModel.emptyMessage,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              ViewData() =>
                vm.visible.isEmpty
                    ? const EmptyView(
                        message: 'Không có đơn nào khớp ô tìm kiếm trong các đơn đã tải.',
                        icon: Icons.search_off,
                      )
                    : Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: colors.border),
                        ),
                        child: ListView(
                          children: [
                            for (final order in vm.visible) ...[
                              _OrderRow(vm: vm, order: order),
                              const Divider(height: 1),
                            ],
                            if (vm.moreError != null)
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Text(
                                  vm.moreError!,
                                  style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                                ),
                              ),
                            if (vm.hasMore)
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Center(
                                  child: TestId(
                                    'a06.more',
                                    child: OutlinedButton(
                                      onPressed: vm.loadingMore ? null : vm.loadMore,
                                      child: Text(vm.loadingMore ? 'Đang tải…' : 'Tải thêm'),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Center(
                                  child: Text('Đã hiện hết đơn.', style: text.bodySmall?.copyWith(color: colors.muted)),
                                ),
                              ),
                          ],
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.vm, required this.order});

  final AdminOrdersViewModel vm;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final stuck = vm.isStuck(order);
    return TestId(
      'a06.row.${order.id}',
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _OrderDetail(vm: vm, order: order),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  '#${order.orderCode.isEmpty ? order.id : order.orderCode}',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.customerName.isEmpty ? 'Khách' : order.customerName} · ${vm.kioskName(order.kioskId)}',
                      style: text.bodyMedium,
                    ),
                    Text(
                      '${order.items.map((e) => '${e.name} ×${e.quantity}').join(', ')} · ${formatDateTime(order.createdAt)}',
                      style: text.bodySmall?.copyWith(color: colors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(formatVnd(order.totalVnd), textAlign: TextAlign.end, style: text.titleSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 168,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusBadge(
                    label: stuck ? 'Kẹt · ${orderStatusText(order.status)}' : orderStatusText(order.status),
                    warning: stuck || order.status == OrderStatus.cancelled,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.vm, required this.order});

  final AdminOrdersViewModel vm;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: text.bodySmall?.copyWith(color: context.appColors.muted)),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
    return AlertDialog(
      title: Text('Đơn #${order.orderCode.isEmpty ? order.id : order.orderCode}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: TestId(
            'a06.detail',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line('Trạng thái', orderStatusText(order.status)),
                line('Khách', order.customerName.isEmpty ? order.uid : order.customerName),
                line('Kiosk', vm.kioskName(order.kioskId)),
                line('Đặt lúc', formatDateTime(order.createdAt)),
                if (order.pickupAt != null) line('Giờ nhận', formatDateTime(order.pickupAt!)),
                const Divider(),
                for (final item in order.items)
                  line(
                    '${item.name} ×${item.quantity}',
                    '${formatVnd(item.priceVnd * item.quantity)}${item.note.isEmpty ? '' : ' · ${item.note}'}',
                  ),
                const Divider(),
                line('Tạm tính', formatVnd(order.subtotalVnd)),
                if (order.discountVnd > 0)
                  line(
                    'Giảm giá',
                    '-${formatVnd(order.discountVnd)}${order.voucherCode == null ? '' : ' (${order.voucherCode})'}',
                  ),
                line('Tổng', formatVnd(order.totalVnd)),
                line('Thanh toán', '${paymentMethodLabel(order.paymentMethod)} · ${orderPaymentLabel(order)}'),
                if (order.note.isNotEmpty) line('Ghi chú', order.note),
                if (order.prepSeconds != null) line('Thời gian làm', '${(order.prepSeconds! / 60).round()} phút'),
                if (order.status == OrderStatus.cancelled)
                  line(
                    'Huỷ bởi',
                    '${order.cancelledBy == CancelledBy.staff ? 'kiosk' : 'khách'}${order.cancelReason == null ? '' : ': ${order.cancelReason}'}',
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng'))],
    );
  }
}
