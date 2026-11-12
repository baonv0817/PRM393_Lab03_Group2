import 'dart:async';

import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/announcement.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// What the announcement form sends.
class AnnouncementInput {
  const AnnouncementInput({required this.title, required this.body, required this.publish, this.kioskId});

  final String title;
  final String body;
  final bool publish;

  /// `null` sends it to customers of every kiosk.
  final String? kioskId;
}

/// W05 Announcement form: an admin writes to `announcements`; published ones appear in the mobile inbox (S19) in
/// real time. Staff see the published list only (the rules let only admins write).
class AnnouncementsViewModel extends ChangeNotifier with SafeChangeNotifier {
  AnnouncementsViewModel({required AnnouncementRepository announcements, required this.uid, required this.canWrite})
    : _repo = announcements {
    submit = Command1(_submit);
    setStatus = Command1(_setStatus);
    _listen();
  }

  final AnnouncementRepository _repo;
  final String uid;

  /// Admins write; staff only read.
  final bool canWrite;
  StreamSubscription<List<Announcement>>? _sub;

  late final Command1<String, AnnouncementInput> submit;
  late final Command1<void, (Announcement, AnnouncementStatus)> setStatus;

  ViewState<List<Announcement>> _state = const ViewLoading();
  ViewState<List<Announcement>> get state => _state;

  /// The form's message for [title] and [body], or `null` when they can be sent.
  String? problemWith(String title, String body) => Announcement.problemWith(title: title, body: body);

  void retry() {
    _sub?.cancel();
    _state = const ViewLoading();
    notifyListeners();
    _listen();
  }

  void _listen() {
    _sub = (canWrite ? _repo.watchAll() : _repo.watchPublished()).listen(
      (items) {
        _state = ViewStateX.fromList(items, emptyMessage: 'Chưa có thông báo nào.');
        notifyListeners();
      },
      onError: (Object error) {
        _state = ViewError(error is AppException ? error.message : 'Không tải được thông báo. Thử lại.');
        notifyListeners();
      },
    );
  }

  Future<Result<String>> _submit(AnnouncementInput input) async {
    if (!canWrite) {
      return const Result.error(PermissionDeniedException(message: 'Chỉ quản trị viên được đăng thông báo.'));
    }
    return _repo.create(
      title: input.title,
      body: input.body,
      createdBy: uid,
      publish: input.publish,
      kioskId: input.kioskId,
    );
  }

  Future<Result<void>> _setStatus((Announcement, AnnouncementStatus) change) {
    final (announcement, status) = change;
    return _repo.setStatus(announcement.id, status);
  }

  @override
  void dispose() {
    _sub?.cancel();
    submit.dispose();
    setStatus.dispose();
    super.dispose();
  }
}
