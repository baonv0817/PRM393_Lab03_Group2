import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/paged.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fakes/fakes.dart';

final class _ForeignCursor implements PageCursor {}

void main() {
  group('pageOf', () {
    test('walks a list page by page until next is null', () {
      final all = [0, 1, 2, 3, 4];

      final first = pageOf(all, limit: 2).valueOrNull!;
      final second = pageOf(all, limit: 2, after: first.next).valueOrNull!;
      final last = pageOf(all, limit: 2, after: second.next).valueOrNull!;

      expect(first.items, [0, 1]);
      expect(first.hasMore, isTrue);
      expect(second.items, [2, 3]);
      expect(last.items, [4]);
      expect(last.hasMore, isFalse);
    });

    test('an empty list gives an empty page without a next cursor', () {
      final page = pageOf(<int>[], limit: 20).valueOrNull!;
      expect(page.items, isEmpty);
      expect(page.next, isNull);
    });

    test('a page size outside 1..maxLimit or a cursor from another source is rejected', () {
      expect(pageOf([1], limit: 0).errorOrNull, isA<ValidationException>());
      expect(pageOf([1], limit: Paged.maxLimit + 1).errorOrNull, isA<ValidationException>());
      expect(pageOf([1], limit: 1, after: _ForeignCursor()).errorOrNull, isA<ValidationException>());
    });
  });

  group('pageFromOverfetch', () {
    test('an extra row means another page; the cursor points at the last row returned', () {
      final page = pageFromOverfetch(
        [10, 11, 12],
        limit: 2,
        map: (int row) => 'r$row',
        cursorOf: (int row) => IndexCursor(row),
      );
      expect(page.items, ['r10', 'r11']);
      expect((page.next! as IndexCursor).offset, 11);
    });

    test('no extra row means this is the last page', () {
      final page = pageFromOverfetch(
        [10, 11],
        limit: 2,
        map: (int row) => row,
        cursorOf: (int row) => IndexCursor(row),
      );
      expect(page.items, [10, 11]);
      expect(page.hasMore, isFalse);
    });
  });

  test('FakeOrderRepository.fetchMyOrders pages through only my orders, newest first', () async {
    final orders = FakeOrderRepository();
    final ids = <String>[];
    for (var i = 0; i < 3; i++) {
      final created = await orders.createOrder(
        uid: 'u1',
        items: const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000)],
        totalVnd: 39000,
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      ids.add(created.valueOrNull!);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await orders.createOrder(
      uid: 'someone-else',
      items: const [],
      totalVnd: 0,
      method: PaymentMethod.cash,
      kioskId: 'q9-t2',
    );

    final first = (await orders.fetchMyOrders('u1', limit: 2)).valueOrNull!;
    final rest = (await orders.fetchMyOrders('u1', limit: 2, after: first.next)).valueOrNull!;

    expect(first.items.map((o) => o.id), [ids[2], ids[1]]);
    expect(rest.items.map((o) => o.id), [ids[0]]);
    expect(rest.hasMore, isFalse);
  });
}
