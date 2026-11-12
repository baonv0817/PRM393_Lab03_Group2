import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/order_manage/view_models/review_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S23: rate the items of a delivered order with stars, quick tags and a comment.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  void _back(BuildContext context, ReviewViewModel vm) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.orderDetailOf(vm.orderId));

  Future<void> _submit(BuildContext context, ReviewViewModel vm) async {
    final result = await vm.submit.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        showAppMessage(context, 'Đã gửi $value đánh giá. Cảm ơn bạn!');
        _back(context, vm);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Đánh giá món', onBack: () => _back(context, vm)),
      // In the bottom bar, not in the body: a message from the Scaffold then appears above the button
      // instead of covering it.
      bottomNavigationBar: vm.state is ViewData<Order>
          ? ListenableBuilder(
              listenable: vm.submit,
              builder: (context, _) {
                final pending = vm.pendingCount;
                return BottomActionButton(
                  label: pending > 0 ? 'Gửi đánh giá ($pending món)' : 'Gửi đánh giá',
                  testId: 's23.submit',
                  loading: vm.submit.running,
                  onPressed: vm.canSubmit && !vm.submit.running ? () => _submit(context, vm) : null,
                );
              },
            )
          : null,
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's23.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's23.empty',
          child: EmptyView(
            message: message ?? ReviewViewModel.notFoundMessage,
            actionLabel: 'Xem đơn hàng',
            onAction: () => context.go(AppRoutes.orders),
          ),
        ),
        ViewData(:final data) => _Form(vm: vm, order: data),
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.vm, required this.order});

  final ReviewViewModel vm;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final hint = vm.missingHint;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      children: [
        Text(
          'Món ăn hôm nay thế nào?',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Đơn #${order.orderCode} · ${order.kioskName}',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: colors.muted),
        ),
        for (final item in vm.items) ...[const SizedBox(height: AppSpacing.sm), _ItemCard(vm: vm, item: item)],
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TestId(
              's23.hint',
              child: Text(hint, style: text.bodyMedium?.copyWith(color: colors.muted)),
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({required this.vm, required this.item});

  final ReviewViewModel vm;
  final CartItem item;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

/// One of the five numbered circles: the points on top, the word under it ("Tệ" … "Tuyệt").
class _Score extends StatelessWidget {
  const _Score({required this.points, required this.selected, required this.onTap});

  final int points;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$points điểm, ${ratingLabel(points)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: AppA11y.minTouchTarget + AppSpacing.xxs,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppA11y.minTouchTarget,
                height: AppA11y.minTouchTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : scheme.surface,
                  border: Border.all(color: selected ? scheme.primary : colors.borderInput, width: 1.5),
                ),
                child: Text(
                  '$points',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                ratingLabel(points),
                style: text.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                  color: selected ? scheme.onSurface : colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCardState extends State<_ItemCard> {
  late final _comment = TextEditingController(text: widget.vm.draftOf(widget.item.itemId).comment);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final item = widget.item;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final draft = vm.draftOf(item.itemId);
    final id = 's23.item.${item.itemId}';
    return TestId(
      id,
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (vm.isReviewed(item.itemId))
                    TestId(
                      '$id.reviewed',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: colors.success),
                          const SizedBox(width: AppSpacing.xxs),
                          Text('Đã đánh giá', style: text.bodyMedium?.copyWith(color: colors.success)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                container: true,
                label: 'Chấm ${item.name}: ${draft.rating} trên 5',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var points = 1; points <= 5; points++)
                      TestId(
                        '$id.star.$points',
                        child: _Score(
                          points: points,
                          selected: draft.rating == points,
                          onTap: () => vm.setRating(item.itemId, points),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text('Điều bạn thích', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in ReviewViewModel.tags)
                    TestId(
                      '$id.tag.$tag',
                      child: AppChip(
                        label: reviewTagLabel(tag),
                        selected: draft.tags.contains(tag),
                        onSelected: (_) => vm.toggleTag(item.itemId, tag),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TestId(
                '$id.comment',
                child: TextField(
                  controller: _comment,
                  onChanged: (value) => vm.setComment(item.itemId, value),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: ReviewViewModel.maxCommentLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tuỳ chọn)',
                    hintText: 'Nhập ghi chú',
                    alignLabelWithHint: true,
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
