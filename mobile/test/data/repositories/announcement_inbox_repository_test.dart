import 'dart:async';

import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

/// S19 and the Home bell: the web admin's announcements (W05) join the customer's own inbox, live.
void main() {
  const uid = 'u1';
  late FakeNotificationRepository own;
  late FakeAnnouncementRepository announcements;
  late InMemorySessionRepository session;
  late AnnouncementInboxRepository inbox;
  late List<List<AppNotification>> seen;
  late StreamSubscription<List<AppNotification>> sub;
  var minute = 0;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  List<AppNotification> latest() => seen.last;

  setUp(() async {
    minute = 0;
    DateTime clock() => DateTime(2026, 11, 12, 9, minute++);
    own = FakeNotificationRepository();
    announcements = FakeAnnouncementRepository(clock: clock);
    session = InMemorySessionRepository();
    inbox = AnnouncementInboxRepository(
      notifications: own,
      announcements: announcements,
      selectedKioskId: session.watchSelectedKioskId,
      clock: clock,
    );
    seen = [];
    sub = inbox.watch(uid).listen(seen.add);
    await settle();
  });

  tearDown(() => sub.cancel());

  test('an announcement published on the web appears at once, newest first, next to order notifications', () async {
    await own.save(
      uid,
      AppNotification(id: 'o1_ready', title: 'Đơn đã sẵn sàng', body: '', receivedAt: DateTime(2026, 11, 12, 8)),
    );
    await announcements.create(title: 'Nghỉ lễ 2/9', body: 'Mọi kiosk nghỉ', createdBy: 'a1', publish: true);
    await settle();
    expect(latest().map((n) => n.id), ['ann_a1', 'o1_ready']);
    final announcement = latest().first;
    expect(announcement.isAnnouncement, isTrue);
    expect(announcement.title, 'Nghỉ lễ 2/9');
    expect(announcement.read, isFalse);
    expect(announcement.orderId, isNull, reason: 'tapping it opens no order');
  });

  test('drafts never show; archiving removes the announcement live', () async {
    await announcements.create(title: 'Nháp', body: 'b', createdBy: 'a1', publish: false);
    final id = (await announcements.create(
      title: 'Khai trương',
      body: 'b',
      createdBy: 'a1',
      publish: true,
    )).valueOrNull!;
    await settle();
    expect(latest().map((n) => n.title), ['Khai trương']);
    await announcements.setStatus(id, AnnouncementStatus.archived);
    await settle();
    expect(latest(), isEmpty);
  });

  test("a kiosk announcement only reaches customers who chose that kiosk, and follows the customer's choice", () async {
    await announcements.create(title: 'Q9 hết sữa', body: 'b', createdBy: 'a1', publish: true, kioskId: 'q9-t2');
    await announcements.create(title: 'Cho mọi kiosk', body: 'b', createdBy: 'a1', publish: true);
    await settle();
    expect(latest().map((n) => n.title), ['Cho mọi kiosk']);
    await session.selectKiosk('q9-t2');
    await settle();
    expect(latest().map((n) => n.title), ['Cho mọi kiosk', 'Q9 hết sữa']);
    await session.selectKiosk('q9-t4');
    await settle();
    expect(latest().map((n) => n.title), ['Cho mọi kiosk']);
  });

  test('opening an announcement stores it as read in the own inbox, so it stays read', () async {
    await announcements.create(title: 'Khai trương', body: 'Giảm 10%', createdBy: 'a1', publish: true);
    await settle();
    final result = await inbox.markRead(uid, 'ann_a1');
    await settle();
    expect(result, isA<Ok<void>>());
    expect(own.of(uid).single.id, 'ann_a1');
    expect(own.of(uid).single.read, isTrue);
    expect(latest().single.read, isTrue);
    expect(latest().single.body, 'Giảm 10%', reason: 'the text comes from the announcement, not the stored copy');
  });

  test('"Đọc hết" also marks the announcements read', () async {
    await own.save(uid, AppNotification(id: 'o1_ready', title: 'Sẵn sàng', body: '', receivedAt: DateTime(2026)));
    await announcements.create(title: 'A', body: 'b', createdBy: 'a1', publish: true);
    await announcements.create(title: 'B', body: 'b', createdBy: 'a1', publish: true);
    await settle();
    expect(latest().where((n) => !n.read), hasLength(3));
    await inbox.markAllRead(uid);
    await settle();
    expect(latest().where((n) => !n.read), isEmpty);
  });

  test('order notifications keep working when announcements cannot be read', () async {
    final broken = AnnouncementInboxRepository(
      notifications: own,
      announcements: _BrokenAnnouncements(),
      selectedKioskId: session.watchSelectedKioskId,
    );
    final lists = <List<AppNotification>>[];
    final s = broken.watch(uid).listen(lists.add);
    await own.save(uid, AppNotification(id: 'o1_ready', title: 'Sẵn sàng', body: '', receivedAt: DateTime(2026)));
    await settle();
    expect(lists.last.map((n) => n.id), ['o1_ready']);
    await s.cancel();
  });

  test('merge keeps order notifications and drops stored copies of announcements that left', () {
    final merged = AnnouncementInboxRepository.merge(
      [
        AppNotification(id: 'ann_gone', title: 'cũ', body: '', receivedAt: DateTime(2026, 11, 1), read: true),
        AppNotification(id: 'o1_ready', title: 'Sẵn sàng', body: '', receivedAt: DateTime(2026, 11, 2)),
      ],
      const [],
      null,
      now: DateTime(2026, 11, 12),
    );
    expect(merged.map((n) => n.id), ['o1_ready']);
  });
}

class _BrokenAnnouncements extends FakeAnnouncementRepository {
  @override
  Stream<List<Announcement>> watchPublished() => Stream.error(Exception('permission-denied'));
}
