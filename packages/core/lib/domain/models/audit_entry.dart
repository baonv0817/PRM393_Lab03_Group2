/// Who is acting on the admin website: written with every change in the audit log.
class AdminActor {
  const AdminActor({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// The kinds of change the audit log records (`action` of [AuditEntry]).
abstract final class AuditAction {
  static const userAccess = 'user.access';
  static const kioskSave = 'kiosk.save';
  static const slotsCreate = 'slots.create';
  static const voucherSave = 'voucher.save';
  static const announcementSave = 'announcement.save';
  static const catalogCopy = 'catalog.copy';
  static const catalogItem = 'catalog.item';
}

/// One line of the audit log (`audit_logs/{id}`): who changed what, and when.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.target,
    required this.summary,
    required this.at,
  });

  final String id;
  final String actorUid;
  final String actorName;

  /// One of [AuditAction].
  final String action;

  /// What was changed, as a path: `users/<uid>`, `kiosks/<id>`, `vouchers/<code>`…
  final String target;

  /// A sentence for people: "Đặt vai trò staff, kiosk q9-t2".
  final String summary;
  final DateTime at;
}
