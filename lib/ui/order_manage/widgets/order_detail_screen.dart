import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/order_manage/view_models/order_detail_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S12: one order in full, with a PDF receipt that is generated, uploaded and listed, and a reorder.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  Future<void> _reorder(BuildContext context, OrderDetailViewModel vm) async {
    final router = GoRouter.of(context);
    final result = await vm.reorder.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        showAddedSnackbar(
          context,
          message: 'Đã thêm $value món vào giỏ',
          onViewCart: () => router.push(AppRoutes.cart),
        );
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> _export(BuildContext context, OrderDetailViewModel vm) async {
    final result = await vm.exportReceipt.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã tải biên nhận lên.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  static Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) showAppMessage(context, 'Đã chép đường dẫn tệp.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderDetailViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Chi tiết đơn',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.orders),
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's12.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's12.empty',
          child: EmptyView(
            message: message ?? OrderDetailViewModel.notFoundMessage,
            actionLabel: 'Xem đơn hàng',
            onAction: () => context.go(AppRoutes.orders),
          ),
        ),
        ViewData(:final data) => _Body(
          vm: vm,
          order: data,
          onReorder: () => _reorder(context, vm),
          onExport: () => _export(context, vm),
          onCopy: (url) => _copy(context, url),
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.vm,
    required this.order,
    required this.onReorder,
    required this.onExport,
    required this.onCopy,
  });

  final OrderDetailViewModel vm;
  final Order order;
  final VoidCallback onReorder;
  final VoidCallback onExport;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final note = vm.noteLine;
    final earlier = vm.earlierReceipts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        TestId(
          's12.header',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đơn tại ${order.kioskName}', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.orderCode}',
                          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TestId(
                        's12.status',
                        child: StatusBadge(label: vm.statusLabel, warning: vm.isCancelled),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const _SectionTitle('Diễn biến'),
        TestId(
          's12.timeline',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(children: [for (final row in vm.timeline) _Line(row: row)]),
            ),
          ),
        ),
        const _SectionTitle('Món đã đặt'),
        TestId(
          's12.items',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in vm.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${line.name} ${line.quantity}', style: text.bodyLarge),
                                if (line.note case final lineNote?)
                                  Text('Ghi chú: $lineNote', style: text.bodyMedium?.copyWith(color: colors.muted)),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(line.price, style: text.bodyLarge),
                        ],
                      ),
                    ),
                  Divider(height: AppSpacing.md, color: colors.border),
                  for (final row in vm.amounts) TestId('s12.amount.${row.id}', child: _Line(row: row)),
                ],
              ),
            ),
          ),
        ),
        const _SectionTitle('Thanh toán và nhận món'),
        TestId(
          's12.info',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconLine(icon: Icons.payments_outlined, text: vm.paymentLine),
                  const SizedBox(height: AppSpacing.xs),
                  _IconLine(icon: Icons.schedule, text: vm.pickupLine),
                  if (note != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _IconLine(icon: Icons.sticky_note_2_outlined, text: note),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (vm.isActive)
          TestId(
            's12.track',
            child: AppButton(
              label: 'Theo dõi đơn',
              icon: Icons.local_shipping_outlined,
              large: true,
              onPressed: () => context.push(AppRoutes.orderOf(order.id)),
            ),
          )
        else
          ListenableBuilder(
            listenable: vm.reorder,
            builder: (context, _) => TestId(
              's12.reorder',
              child: AppButton(
                label: 'Đặt lại món này',
                icon: Icons.replay,
                large: true,
                loading: vm.reorder.running,
                onPressed: vm.reorder.running ? null : onReorder,
              ),
            ),
          ),
        if (vm.canReview) ...[
          const SizedBox(height: AppSpacing.sm),
          TestId(
            's12.review',
            child: AppButton(
              label: 'Đánh giá món',
              icon: Icons.star_outline,
              variant: AppButtonVariant.secondary,
              large: true,
              onPressed: () => context.push(AppRoutes.orderReviewOf(order.id)),
            ),
          ),
        ],
        if (vm.canReportIncident) ...[
          const SizedBox(height: AppSpacing.sm),
          TestId(
            's12.incident',
            child: AppButton(
              label: 'Báo sự cố với đơn này',
              icon: Icons.report_problem_outlined,
              variant: AppButtonVariant.secondary,
              large: true,
              onPressed: () => context.push(AppRoutes.orderIncidentOf(order.id)),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ListenableBuilder(
          listenable: vm.exportReceipt,
          builder: (context, _) => TestId(
            's12.export',
            child: AppButton(
              label: 'Xuất biên nhận PDF',
              icon: Icons.picture_as_pdf_outlined,
              variant: AppButtonVariant.secondary,
              large: true,
              loading: vm.exportReceipt.running,
              onPressed: vm.exportReceipt.running ? null : onExport,
            ),
          ),
        ),
        if (vm.stage != ReceiptStage.idle) _ExportProgress(vm: vm),
        if (vm.lastReceipt case final report?) _UploadedCard(report: report, onCopy: () => onCopy(report.url)),
        if (earlier.isNotEmpty) ...[
          const _SectionTitle('Biên nhận đã xuất'),
          TestId(
            's12.receipts',
            child: ProfileSection(
              child: Column(
                children: [
                  for (final report in earlier)
                    TestId(
                      's12.receipt.${report.id}',
                      child: ListTile(
                        minTileHeight: AppA11y.minTouchTarget + AppSpacing.xs,
                        title: Text(report.fileName, style: text.bodyLarge),
                        subtitle: Text(
                          '${formatDateTime(report.createdAt)} · ${report.sizeKb} KB',
                          style: text.bodyMedium?.copyWith(color: colors.muted),
                        ),
                        trailing: AppIconButton(
                          icon: Icons.copy,
                          semanticLabel: 'Chép đường dẫn tệp ${report.fileName}',
                          onPressed: () => onCopy(report.url),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.row});

  final DetailRow row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final labelStyle = row.strong
        ? text.bodyLarge?.copyWith(fontWeight: FontWeight.w800)
        : text.bodyMedium?.copyWith(color: colors.muted);
    final valueStyle = row.strong ? text.bodyLarge?.copyWith(fontWeight: FontWeight.w800) : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(row.label, style: labelStyle)),
          const SizedBox(width: AppSpacing.sm),
          Text(row.value, style: valueStyle),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.appColors.primaryText),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

class _ExportProgress extends StatelessWidget {
  const _ExportProgress({required this.vm});

  final OrderDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final percent = (vm.uploadProgress * 100).round();
    final label = switch (vm.stage) {
      ReceiptStage.generating => 'Đang tạo PDF…',
      ReceiptStage.uploading => 'Đang tải lên $percent%',
      ReceiptStage.saving => 'Đang lưu thông tin tệp…',
      ReceiptStage.idle => '',
    };
    return TestId(
      's12.export.progress',
      child: Semantics(
        liveRegion: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.xxs),
              LinearProgressIndicator(
                value: vm.stage == ReceiptStage.uploading ? vm.uploadProgress : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadedCard extends StatelessWidget {
  const _UploadedCard({required this.report, required this.onCopy});

  final Report report;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TestId(
        's12.export.card',
        child: ProfileSection(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: colors.success),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text('Đã tải lên · ${report.sizeKb} KB', style: text.titleMedium)),
                    TestId(
                      's12.export.copy',
                      child: AppIconButton(icon: Icons.copy, semanticLabel: 'Chép đường dẫn tệp', onPressed: onCopy),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(report.fileName, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                TestId(
                  's12.export.url',
                  child: SelectableText(report.url, style: text.bodyMedium?.copyWith(color: colors.primaryText)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
