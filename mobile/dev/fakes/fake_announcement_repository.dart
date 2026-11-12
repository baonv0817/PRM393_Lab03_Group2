import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

import 'live_value.dart';

/// Behaves like the Firestore version: newest first, archived ones leave the published list at once.
class FakeAnnouncementRepository implements AnnouncementRepository {
  FakeAnnouncementRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _all = LiveValue<List<Announcement>>(const []);
  var _nextId = 1;

  List<Announcement> get all => _all.value;

  List<Announcement> get _published => all.where((a) => a.status == AnnouncementStatus.published).toList();

  @override
  Stream<List<Announcement>> watchAll() => _all.stream;

  @override
  Stream<List<Announcement>> watchPublished() => _all.stream.map((_) => _published);

  @override
  Future<Result<String>> create({
    required String title,
    required String body,
    required String createdBy,
    required bool publish,
    String? kioskId,
  }) async {
    if (Announcement.problemWith(title: title, body: body) case final problem?) {
      return Result.error(ValidationException(problem));
    }
    final now = _clock();
    final announcement = Announcement(
      id: 'a${_nextId++}',
      title: title.trim(),
      body: body.trim(),
      status: publish ? AnnouncementStatus.published : AnnouncementStatus.draft,
      createdBy: createdBy,
      kioskId: kioskId,
      createdAt: now,
      publishedAt: publish ? now : null,
    );
    _all.set([announcement, ...all]);
    return Result.ok(announcement.id);
  }

  @override
  Future<Result<void>> setStatus(String id, AnnouncementStatus status) async {
    if (!all.any((a) => a.id == id)) return const Result.error(NotFoundException());
    _all.set([
      for (final a in all)
        if (a.id != id)
          a
        else
          Announcement(
            id: a.id,
            title: a.title,
            body: a.body,
            status: status,
            createdBy: a.createdBy,
            kioskId: a.kioskId,
            createdAt: a.createdAt,
            publishedAt: status == AnnouncementStatus.published ? (a.publishedAt ?? _clock()) : a.publishedAt,
          ),
    ]);
    return const Result.ok(null);
  }
}
