import 'package:breakbite_core/domain/models/announcement.dart';
import 'package:breakbite_core/utils/result.dart';

abstract interface class AnnouncementRepository {
  /// Every announcement, newest first, for the web admin (admins only; the rules refuse anyone else).
  Stream<List<Announcement>> watchAll();

  /// Published announcements, newest first, for the mobile inbox (S19).
  Stream<List<Announcement>> watchPublished();

  /// An admin writes a new announcement as a draft or published at once; returns its id. Fails with
  /// `ValidationException` when [Announcement.problemWith] says so.
  Future<Result<String>> create({
    required String title,
    required String body,
    required String createdBy,
    required bool publish,
    String? kioskId,
  });

  /// An admin publishes a draft or archives an announcement.
  Future<Result<void>> setStatus(String id, AnnouncementStatus status);
}
