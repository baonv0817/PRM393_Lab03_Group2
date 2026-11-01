import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigEntry {
  const RemoteConfigEntry({required this.key, required this.value, required this.source});

  final String key;
  final Object value;
  final RemoteValueSource source;
}

enum ExportStage { idle, generating, uploading, saving }

class FirebaseDemoViewModel extends ChangeNotifier with SafeChangeNotifier {
  FirebaseDemoViewModel({
    required this.remoteConfig,
    required this.crash,
    required this.analytics,
    required this.storage,
    required this.reportFiles,
    required this.reports,
    required this.orders,
    required this.uid,
    required this.customerName,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    refreshConfig = Command0(_refreshConfig);
    recordTestError = Command0(_recordTestError);
    exportAndUpload = Command0(_exportAndUpload);
    _readConfig();
    _configUpdates = remoteConfig.watchUpdates().listen((_) => _readConfig());
    watchReports();
  }

  final RemoteConfigService remoteConfig;
  final CrashService crash;
  final AnalyticsService analytics;
  final StorageService storage;
  final ReportFileService reportFiles;
  final ReportRepository reports;
  final OrderRepository orders;
  final String uid;
  final String customerName;
  final DateTime Function() _clock;

  late final Command0<void> refreshConfig;
  late final Command0<void> recordTestError;
  late final Command0<Report> exportAndUpload;

  StreamSubscription<Set<String>>? _configUpdates;
  StreamSubscription<List<Report>>? _reportsSub;

  List<RemoteConfigEntry> _config = const [];
  DateTime? _configFetchedAt;
  ViewState<List<Report>> _reports = const ViewLoading();
  ExportStage _stage = ExportStage.idle;
  double _uploadProgress = 0;
  Report? _lastReport;

  List<RemoteConfigEntry> get config => _config;
  DateTime? get configFetchedAt => _configFetchedAt;
  ViewState<List<Report>> get myReports => _reports;
  ExportStage get stage => _stage;
  double get uploadProgress => _uploadProgress;
  Report? get lastReport => _lastReport;

  void _readConfig() {
    _config = [
      for (final MapEntry(:key, :value) in RemoteKeys.defaults.entries)
        RemoteConfigEntry(
          key: key,
          value: value is bool ? remoteConfig.getBool(key) : remoteConfig.getInt(key),
          source: remoteConfig.sourceOf(key),
        ),
    ];
    _configFetchedAt = remoteConfig.lastFetchedAt;
    notifyListeners();
  }

  Future<Result<void>> _refreshConfig() async {
    await remoteConfig.fetchAndActivate();
    _readConfig();
    return const Result.ok(null);
  }

  Future<Result<void>> _recordTestError() async {
    await crash.recordError(
      StateError('Firebase demo: handled test error at ${_clock().toIso8601String()}'),
      StackTrace.current,
      reason: 'firebase_demo.test_error',
    );
    return const Result.ok(null);
  }

  void crashForTest() => crash.forceTestCrash();

  void watchReports() {
    unawaited(_reportsSub?.cancel());
    _reports = const ViewLoading();
    notifyListeners();
    _reportsSub = reports
        .watchMine(uid)
        .listen(
          (items) {
            _reports = ViewStateX.fromList(
              items,
              emptyMessage: 'Chưa có tệp nào. Bấm "Xuất và tải lên" để tạo tệp đầu tiên.',
            );
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            _log(error, stack, 'firebase_demo.watchReports');
            _reports = ViewError(error is AppException ? error.message : 'Không tải được danh sách tệp.');
            notifyListeners();
          },
        );
  }

  Future<Result<Report>> _exportAndUpload() async {
    final result = await _export();
    _stage = ExportStage.idle;
    switch (result) {
      case Ok(:final value):
        _lastReport = value;
        unawaited(
          analytics.logEvent(AnalyticsEvents.exportReport, {'file_size_kb': value.sizeKb, 'source': 'firebase_demo'}),
        );
      case Err(:final error):
        _log(error, error.stackTrace ?? StackTrace.current, 'firebase_demo.export');
    }
    notifyListeners();
    return result;
  }

  Future<Result<Report>> _export() async {
    if (uid.isEmpty) return const Result.error(PermissionDeniedException(message: 'Đăng nhập để xuất tệp.'));
    _stage = ExportStage.generating;
    _uploadProgress = 0;
    notifyListeners();

    final List<Order> myOrders;
    switch (await orders.fetchMyOrders(uid)) {
      case Ok(:final value):
        myOrders = value.items;
      case Err(:final error):
        return Result.error(error);
    }

    final GeneratedFile file;
    switch (await reportFiles.ordersSummary(customerName: customerName, orders: myOrders, now: _clock())) {
      case Ok(:final value):
        file = value;
      case Err(:final error):
        return Result.error(error);
    }

    _stage = ExportStage.uploading;
    notifyListeners();
    final UploadedFile uploaded;
    switch (await storage.upload(
      folder: UploadFolder.reports,
      ownerId: uid,
      fileName: file.fileName,
      bytes: file.bytes,
      onProgress: (progress) {
        _uploadProgress = progress.clamp(0, 1);
        notifyListeners();
      },
    )) {
      case Ok(:final value):
        uploaded = value;
      case Err(:final error):
        return Result.error(error);
    }

    _stage = ExportStage.saving;
    notifyListeners();
    return reports.save(uid: uid, fileName: file.fileName, file: uploaded);
  }

  void _log(Object error, StackTrace stack, String reason) {
    if (error is CancelledException) return;
    unawaited(crash.recordError(error is AppException ? error.cause ?? error : error, stack, reason: reason));
  }

  @override
  void dispose() {
    unawaited(_configUpdates?.cancel());
    unawaited(_reportsSub?.cancel());
    refreshConfig.dispose();
    recordTestError.dispose();
    exportAndUpload.dispose();
    super.dispose();
  }
}
