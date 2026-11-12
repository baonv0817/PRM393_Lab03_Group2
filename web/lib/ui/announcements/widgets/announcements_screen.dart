import 'package:breakbite_admin/ui/announcements/view_models/announcements_view_model.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/domain/models/announcement.dart';
import 'package:breakbite_core/domain/models/kiosk.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:breakbite_core/ui/core/widgets/status_badge.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// W05 Announcements: the list on the left, the form on the right (admins only).
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<AdminSession>();
    return ChangeNotifierProvider(
      create: (context) => AnnouncementsViewModel(
        announcements: context.read<AnnouncementRepository>(),
        uid: session.user!.uid,
        canWrite: session.isAdmin,
        analytics: context.read<AnalyticsService>(),
      ),
      child: const _AnnouncementsView(),
    );
  }
}

class _AnnouncementsView extends StatelessWidget {
  const _AnnouncementsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnnouncementsViewModel>();
    final kiosks = context.select<AdminSession, List<Kiosk>>((s) => s.kiosks);
    return AdminPage(
      title: 'Thông báo',
      subtitle: 'Thông báo đã đăng hiện ngay trong hộp thư của ứng dụng khách.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: ViewStateView<List<Announcement>>(
              state: vm.state,
              onRetry: vm.retry,
              builder: (context, items) => ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) => _AnnouncementTile(item: items[i], kiosks: kiosks),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: vm.canWrite
                  ? _AnnouncementForm(kiosks: kiosks)
                  : const AdminPanel(
                      child: Text('Chỉ quản trị viên được đăng thông báo. Nhân viên kiosk xem các thông báo đã đăng.'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item, required this.kiosks});

  final Announcement item;
  final List<Kiosk> kiosks;

  static const _status = {
    AnnouncementStatus.draft: 'Bản nháp',
    AnnouncementStatus.published: 'Đã đăng',
    AnnouncementStatus.archived: 'Đã lưu trữ',
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.read<AnnouncementsViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scope = item.kioskId == null
        ? 'Mọi kiosk'
        : kiosks.where((k) => k.id == item.kioskId).firstOrNull?.name ?? item.kioskId!;
    final when = item.publishedAt ?? item.createdAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.title, style: text.titleMedium)),
                StatusBadge(label: _status[item.status]!, warning: item.status != AnnouncementStatus.published),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(item.body, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$scope${when == null ? '' : ' · ${formatDateTime(when)}'}',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                ),
                if (vm.canWrite && item.status == AnnouncementStatus.draft)
                  TextButton(
                    onPressed: () => vm.setStatus.execute((item, AnnouncementStatus.published)),
                    child: const Text('Đăng'),
                  ),
                if (vm.canWrite && item.status == AnnouncementStatus.published)
                  TextButton(
                    onPressed: () => vm.setStatus.execute((item, AnnouncementStatus.archived)),
                    child: const Text('Lưu trữ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({required this.kiosks});

  final List<Kiosk> kiosks;

  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _kioskId;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send(AnnouncementsViewModel vm, {required bool publish}) async {
    final problem = vm.problemWith(_title.text, _body.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final result = await vm.submit.execute(
      AnnouncementInput(title: _title.text, body: _body.text, publish: publish, kioskId: _kioskId),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case Ok():
        _title.clear();
        _body.clear();
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? 'Đã đăng. Khách thấy ngay trong hộp thư.' : 'Đã lưu bản nháp.'),
            behavior: SnackBarBehavior.floating,
            width: 480,
          ),
        );
      case Err(:final error):
        setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnnouncementsViewModel>();
    final text = Theme.of(context).textTheme;
    final busy = vm.submit.running;
    return AdminPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thông báo mới', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Tiêu đề', controller: _title, helperText: 'Tối đa ${Announcement.maxTitleLength} ký tự'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            maxLength: Announcement.maxBodyLength,
            decoration: const InputDecoration(labelText: 'Nội dung', alignLabelWithHint: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: _kioskId,
            decoration: const InputDecoration(labelText: 'Gửi tới'),
            items: [
              const DropdownMenuItem(child: Text('Khách của mọi kiosk')),
              for (final k in widget.kiosks) DropdownMenuItem(value: k.id, child: Text('Khách chọn ${k.name}')),
            ],
            onChanged: (id) => setState(() => _kioskId = id),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Đăng ngay',
            icon: Icons.send,
            large: true,
            loading: busy,
            onPressed: busy ? null : () => _send(vm, publish: true),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Lưu bản nháp',
            variant: AppButtonVariant.secondary,
            onPressed: busy ? null : () => _send(vm, publish: false),
          ),
        ],
      ),
    );
  }
}
