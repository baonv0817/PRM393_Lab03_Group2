import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/models/models.dart';

import '../live_value.dart';

/// The audit log in memory. The other fake admin repositories write into it, as the Firestore ones do in the
/// same batch as the change.
class FakeAuditLog implements AuditLogRepository {
  FakeAuditLog({this.actor = const AdminActor(uid: 'dev-admin', name: 'Quản trị viên')});

  AdminActor actor;
  final _entries = LiveValue<List<AuditEntry>>(const []);
  var _count = 0;

  /// Newest first.
  List<AuditEntry> get entries => _entries.value;

  void record(String action, String target, String summary) {
    _entries.set([
      AuditEntry(
        id: 'audit-${++_count}',
        actorUid: actor.uid,
        actorName: actor.name,
        action: action,
        target: target,
        summary: summary,
        at: DateTime.now(),
      ),
      ..._entries.value,
    ]);
  }

  @override
  Stream<List<AuditEntry>> watchRecent({int limit = 200}) => _entries.stream.map((list) => list.take(limit).toList());
}
