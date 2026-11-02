import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/order_manage/view_models/review_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
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
        ViewData(:final data) => _Form(vm: vm, order: data, onSubmit: () => _submit(context, vm)),
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.vm, required this.order, required this.onSubmit});

  final ReviewViewModel vm;
  final Order order;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final hint = vm.missingHint;
    final pending = vm.pendingCount;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.md,
            ),
            children: [
              Text(
                'Đơn #${order.orderCode} · ${order.kioskName}',
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
          ),
        ),
        ListenableBuilder(
          listenable: vm.submit,
          builder: (context, _) => BottomActionButton(
            label: pending > 0 ? 'Gửi đánh giá ($pending món)' : 'Gửi đánh giá',
            testId: 's23.submit',
            loading: vm.submit.running,
            onPressed: vm.canSubmit && !vm.submit.running ? onSubmit : null,
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
    final scheme = Theme.of(context).colorScheme;
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
                label: 'Chấm ${item.name}: ${draft.rating} trên 5 sao',
                child: Row(
                  children: [
                    for (var stars = 1; stars <= 5; stars++)
                      TestId(
                        '$id.star.$stars',
                        child: IconButton(
                          tooltip: '$stars sao',
                          constraints: const BoxConstraints.tightFor(
                            width: AppA11y.minTouchTarget,
                            height: AppA11y.minTouchTarget,
                          ),
                          onPressed: () => vm.setRating(item.itemId, stars),
                          icon: Icon(
                            draft.rating >= stars ? Icons.star : Icons.star_border,
                            size: 32,
                            color: draft.rating >= stars ? scheme.primary : colors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TestId(
                '$id.rating',
                child: Text(ratingLabel(draft.rating), style: text.bodyMedium?.copyWith(color: colors.muted)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
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
                    labelText: 'Nhận xét (không bắt buộc)',
                    hintText: 'Món này thế nào?',
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
