import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

/// A10: who changed what on the admin website, newest first. Read-only, filtered by kind and by a word.
class AdminAuditViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminAuditViewModel({required this.audit}) {
    load();
  }

  static const emptyMessage = 'Chưa có thay đổi nào được ghi lại.';

  final AuditLogRepository audit;

  StreamSubscription<List<AuditEntry>>? _sub;
  ViewState<List<AuditEntry>> _state = const ViewLoading();
  String? _action;
  String _search = '';

  ViewState<List<AuditEntry>> get state => _state;
  String? get action => _action;

  void setAction(String? value) {
    _action = value;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  /// The entries that match the kind and the search (the name of the admin, the target or the summary).
  List<AuditEntry> get visible {
    final all = _state.dataOrNull ?? const <AuditEntry>[];
    final key = searchKey(_search.trim());
    return [
      for (final e in all)
        if ((_action == null || e.action == _action) &&
            (key.isEmpty || searchKey('${e.actorName} ${e.target} ${e.summary}').contains(key)))
          e,
    ];
  }

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = audit.watchRecent().listen(
      (list) {
        _state = list.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(list);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _state = ViewError(error is AppException ? error.message : 'Không tải được nhật ký.');
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
