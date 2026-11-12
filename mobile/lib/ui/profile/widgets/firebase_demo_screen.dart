import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/profile/view_models/firebase_demo_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
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

class FirebaseDemoScreen extends StatelessWidget {
  const FirebaseDemoScreen({super.key});

  static const configLabels = {
    RemoteKeys.quickItemsLimit: 'Số món nhanh trên Trang chủ',
    RemoteKeys.promoBannerEnabled: 'Banner Combo Giờ Vàng',
    RemoteKeys.pickupSlotEnabled: 'Hẹn giờ nhận món',
    RemoteKeys.aiEnabled: 'AI điền món từ ảnh (K14)',
    RemoteKeys.aiModel: 'Model Gemini',
    RemoteKeys.aiPrompt: 'Hướng dẫn cho AI',
  };

  static Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) showAppMessage(context, 'Đã chép đường dẫn tệp.');
  }

  Future<void> _recordTestError(BuildContext context, FirebaseDemoViewModel demo) async {
    final result = await demo.recordTestError.execute();
    if (result is Ok<void> && context.mounted) {
      showAppMessage(context, 'Đã ghi một lỗi thử. Crashlytics hiện lỗi này sau vài phút.');
    }
  }

  Future<void> _confirmCrash(BuildContext context, FirebaseDemoViewModel demo) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Làm sập app thử?',
      message: 'App sẽ đóng ngay. Mở lại app để Crashlytics gửi báo cáo lên console.',
      confirmLabel: 'Làm sập',
      destructive: true,
    );
    if (confirmed == true) demo.crashForTest();
  }

  Future<void> _export(BuildContext context, FirebaseDemoViewModel demo) async {
    final result = await demo.exportAndUpload.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã tải tệp lên.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = context.watch<FirebaseDemoViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;

    Widget header(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: text.bodyMedium?.copyWith(color: colors.muted)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppTopBar(title: 'Khu demo Firebase', onBack: () => context.pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.xl),
        children: [
          header('Thông báo', 'Tin nhắn FCM nhận được ở cả 3 trạng thái của app đều nằm ở đây.'),
          ProfileSection(
            child: TestId(
              'demo.notifications',
              child: ListTile(
                minTileHeight: AppA11y.minTouchTarget + AppSpacing.xs,
                leading: Icon(Icons.notifications_none, color: colors.primaryText),
                title: Text('Trung tâm thông báo', style: text.bodyLarge),
                trailing: Icon(Icons.chevron_right, color: colors.muted),
                onTap: () => context.push(AppRoutes.notifications),
              ),
            ),
          ),
          header('Remote Config', 'Đổi giá trị trên console rồi publish, màn này và Trang chủ đổi theo ngay.'),
          ProfileSection(child: _ConfigList(demo: demo)),
          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: demo.refreshConfig,
            builder: (context, _) => TestId(
              'demo.config.refresh',
              child: AppButton(
                label: 'Lấy giá trị mới',
                icon: Icons.sync,
                variant: AppButtonVariant.secondary,
                loading: demo.refreshConfig.running,
                onPressed: demo.refreshConfig.execute,
              ),
            ),
          ),
          header('Crashlytics', 'Ghi một lỗi không làm sập app, hoặc làm sập app để thử báo cáo crash.'),
          ListenableBuilder(
            listenable: demo.recordTestError,
            builder: (context, _) => TestId(
              'demo.crash.error',
              child: AppButton(
                label: 'Ghi lỗi thử',
                icon: Icons.bug_report_outlined,
                variant: AppButtonVariant.secondary,
                loading: demo.recordTestError.running,
                onPressed: () => _recordTestError(context, demo),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TestId(
            'demo.crash.crash',
            child: AppButton(
              label: 'Làm sập app thử',
              icon: Icons.warning_amber,
              variant: AppButtonVariant.text,
              onPressed: () => _confirmCrash(context, demo),
            ),
          ),
          header(
            'Xuất và tải tệp',
            'Tạo PDF tóm tắt đơn hàng của bạn rồi tải lên. Chỉ bạn thấy danh sách tệp của mình.',
          ),
          ListenableBuilder(
            listenable: demo.exportAndUpload,
            builder: (context, _) => TestId(
              'demo.export',
              child: AppButton(
                label: 'Xuất và tải lên',
                icon: Icons.upload_file,
                loading: demo.exportAndUpload.running,
                onPressed: () => _export(context, demo),
              ),
            ),
          ),
          if (demo.stage != ExportStage.idle) _ExportProgress(demo: demo),
          if (demo.lastReport case final report?)
            _UploadedFileCard(report: report, onCopy: () => _copy(context, report.url)),
          header('Tệp của tôi', 'Lấy từ Firestore, chỉ chủ tệp đọc được.'),
          _MyReports(demo: demo, onCopy: (url) => _copy(context, url)),
        ],
      ),
    );
  }
}

class _ConfigList extends StatelessWidget {
  const _ConfigList({required this.demo});

  final FirebaseDemoViewModel demo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final fetchedAt = demo.configFetchedAt;
    return Column(
      children: [
        for (final (index, entry) in demo.config.indexed) ...[
          if (index > 0) Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: colors.border),
          TestId(
            'demo.config.${entry.key.replaceAll('_', '-')}',
            child: Semantics(
              container: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(FirebaseDemoScreen.configLabels[entry.key] ?? entry.key, style: text.bodyLarge),
                          Text(
                            '${entry.key} · ${entry.source == RemoteValueSource.console ? 'từ console' : 'mặc định trong app'}',
                            style: text.bodyMedium?.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // A text value (the model, the prompt) can be long: it keeps to the space left and ends with "…".
                    Flexible(
                      child: Text(
                        switch (entry.value) {
                          true => 'Bật',
                          false => 'Tắt',
                          final other => '$other',
                        },
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        Divider(height: 1, color: colors.border),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              fetchedAt == null
                  ? 'Chưa lấy được giá trị từ console.'
                  : 'Lần lấy gần nhất: ${formatDateTime(fetchedAt)}',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportProgress extends StatelessWidget {
  const _ExportProgress({required this.demo});

  final FirebaseDemoViewModel demo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final percent = (demo.uploadProgress * 100).round();
    final label = switch (demo.stage) {
      ExportStage.generating => 'Đang tạo PDF…',
      ExportStage.uploading => 'Đang tải lên $percent%',
      ExportStage.saving => 'Đang lưu thông tin tệp…',
      ExportStage.idle => '',
    };
    return TestId(
      'demo.export.progress',
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
                value: demo.stage == ExportStage.uploading ? demo.uploadProgress : null,
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

class _UploadedFileCard extends StatelessWidget {
  const _UploadedFileCard({required this.report, required this.onCopy});

  final Report report;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
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
                    'demo.export.copy',
                    child: AppIconButton(icon: Icons.copy, semanticLabel: 'Chép đường dẫn tệp', onPressed: onCopy),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(report.fileName, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              TestId(
                'demo.export.url',
                child: SelectableText(report.url, style: text.bodyMedium?.copyWith(color: colors.primaryText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyReports extends StatelessWidget {
  const _MyReports({required this.demo, required this.onCopy});

  final FirebaseDemoViewModel demo;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return switch (demo.myReports) {
      ViewLoading() => const LoadingView(message: 'Đang tải danh sách tệp…'),
      ViewEmpty(:final message) => EmptyView(message: message ?? 'Chưa có tệp nào.'),
      ViewError(:final message) => TestId(
        'demo.reports.retry',
        child: ErrorView(message: message, onRetry: demo.watchReports),
      ),
      ViewData(:final data) => ProfileSection(
        child: Column(
          children: [
            for (final (index, report) in data.indexed) ...[
              if (index > 0) Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: colors.border),
              TestId(
                'demo.reports.$index',
                child: ListTile(
                  minTileHeight: AppA11y.minTouchTarget + AppSpacing.xs,
                  leading: Icon(Icons.picture_as_pdf_outlined, color: colors.primaryText),
                  title: Text(report.fileName, style: text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${report.sizeKb} KB · ${formatDateTime(report.createdAt)}',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                  trailing: AppIconButton(
                    icon: Icons.copy,
                    semanticLabel: 'Chép đường dẫn ${report.fileName}',
                    onPressed: () => onCopy(report.url),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    };
  }
}
