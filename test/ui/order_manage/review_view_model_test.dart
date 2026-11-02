import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/order_manage/view_models/review_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

class _FailingReviews extends FakeReviewRepository {
  @override
  Stream<List<Review>> watchOfOrder(String uid, String orderId) => Stream.error(const NetworkException());
}

class _NeverAnswers extends FakeReviewRepository {
  @override
  Stream<List<Review>> watchOfOrder(String uid, String orderId) => const Stream.empty();
}

const _combo = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
const _tea = CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000);

class _Setup {
  _Setup({FakeOrderRepository? orders, FakeReviewRepository? reviews})
    : orders = orders ?? FakeOrderRepository(),
      reviews = reviews ?? FakeReviewRepository();

  final FakeOrderRepository orders;
  final FakeReviewRepository reviews;
  final crash = FakeCrashService();

  ReviewViewModel viewModel(String orderId) => ReviewViewModel(
    orders: orders,
    reviews: reviews,
    crash: crash,
    uid: 'u1',
    displayName: 'Nguyễn Minh Quân',
    orderId: orderId,
  );

  /// A delivered order of 'u1' with a combo and a tea.
  Future<String> deliveredOrder() async {
    final id = await placeTestOrder(orders, uid: 'u1', items: const [_combo, _tea]);
    await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
    await orders.markReady(orders.all.single);
    await orders.deliver(orders.all.single);
    return id;
  }
}

void main() {
  group('ReviewViewModel', () {
    test('a received order opens with every item unrated, and says to tap a star first', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.items.map((i) => i.itemId), ['m1', 'm2']);
      expect(vm.draftOf('m1').rating, 0);
      expect(vm.isReviewed('m1'), isFalse);
      expect(vm.canSubmit, isFalse);
      expect(vm.pendingCount, 0);
      expect(vm.missingHint, 'Chạm vào sao để chấm điểm ít nhất một món.');
      vm.dispose();
    });

    test('rating an item makes it ready to send; a rating outside 1–5 is ignored', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      vm.setRating('m1', 0);
      vm.setRating('m1', 6);
      expect(vm.draftOf('m1').rating, 0);

      vm.setRating('m1', 4);
      expect(vm.draftOf('m1').rating, 4);
      expect(vm.pendingCount, 1);
      expect(vm.canSubmit, isTrue);
      expect(vm.missingHint, isNull);
      vm.dispose();
    });

    test('tags switch on and off, and an unknown tag is ignored', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      vm.toggleTag('m1', 'tasty');
      vm.toggleTag('m1', 'hot');
      vm.toggleTag('m1', 'crispy');
      expect(vm.draftOf('m1').tags, ['tasty', 'hot']);
      vm.toggleTag('m1', 'tasty');
      expect(vm.draftOf('m1').tags, ['hot']);
      expect(vm.draftOf('m2').tags, isEmpty);
      vm.dispose();
    });

    test('a comment stops at the maximum length', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      vm.setComment('m1', 'x' * (ReviewViewModel.maxCommentLength + 25));
      expect(vm.draftOf('m1').comment.length, ReviewViewModel.maxCommentLength);
      vm.dispose();
    });

    test('sending saves only the rated items, with the public name, and they show as reviewed', () async {
      final setup = _Setup();
      final id = await setup.deliveredOrder();
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      vm.setRating('m1', 4);
      vm.toggleTag('m1', 'tasty');
      vm.setComment('m1', '  Vỏ giòn, nhân đầy  ');
      final result = await vm.submit.execute();
      await pumpEventQueue();

      expect((result! as Ok<int>).value, 1);
      expect(setup.reviews.saves, hasLength(1));
      final saved = setup.reviews.all.single;
      expect((saved.orderId, saved.itemId, saved.dishId, saved.kioskId, saved.uid), (id, 'm1', 'm1', 'q9-t2', 'u1'));
      expect(saved.authorName, 'Quân N.');
      expect((saved.rating, saved.comment), (4, 'Vỏ giòn, nhân đầy'));
      expect(saved.tags, ['tasty']);
      expect(vm.isReviewed('m1'), isTrue);
      expect(vm.isReviewed('m2'), isFalse);
      expect(vm.isDirty('m1'), isFalse);
      expect(vm.canSubmit, isFalse);
      expect(vm.missingHint, 'Bạn chưa thay đổi gì so với đánh giá đã gửi.');
      vm.dispose();
    });

    test('a review already sent shows in the form, and changing it saves the change once', () async {
      final setup = _Setup();
      final id = await setup.deliveredOrder();
      await setup.reviews.save(
        order: setup.orders.all.single,
        item: _tea,
        rating: 3,
        comment: 'Hơi ngọt',
        tags: const ['fast'],
        authorName: 'Nguyễn Minh Quân',
      );
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      final draft = vm.draftOf('m2');
      expect((draft.rating, draft.comment), (3, 'Hơi ngọt'));
      expect(draft.tags, ['fast']);
      expect(vm.isReviewed('m2'), isTrue);
      expect(vm.canSubmit, isFalse);

      vm.setRating('m2', 5);
      expect(vm.isDirty('m2'), isTrue);
      expect(vm.pendingCount, 1);
      final result = await vm.submit.execute();
      await pumpEventQueue();

      expect((result! as Ok<int>).value, 1);
      expect(setup.reviews.all, hasLength(1), reason: 'the same review is changed, not added');
      expect(setup.reviews.all.single.rating, 5);
      expect(setup.reviews.all.single.authorName, 'Quân N.');
      expect(setup.reviews.all.single.updatedAt, isNotNull);
      expect(vm.isDirty('m2'), isFalse);
      vm.dispose();
    });

    test('what is being typed is not overwritten when another review of the order arrives', () async {
      final setup = _Setup();
      final id = await setup.deliveredOrder();
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      vm.setComment('m1', 'Đang gõ dở');
      await setup.reviews.save(order: setup.orders.all.single, item: _tea, rating: 5);
      await pumpEventQueue();

      expect(vm.draftOf('m1').comment, 'Đang gõ dở');
      expect(vm.isReviewed('m2'), isTrue);
      vm.dispose();
    });

    test('a failed send reports the reason, is recorded, keeps the draft and can be tried again', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();
      vm.setRating('m1', 2);
      vm.setComment('m1', 'Nguội');
      setup.reviews.failNextSave = const NetworkException();

      final failed = await vm.submit.execute();
      expect((failed! as Err<int>).error.message, const NetworkException().message);
      expect(setup.crash.errors, hasLength(1));
      expect(vm.draftOf('m1').comment, 'Nguội');
      expect(vm.isReviewed('m1'), isFalse);

      final retry = await vm.submit.execute();
      await pumpEventQueue();
      expect((retry! as Ok<int>).value, 1);
      expect(vm.isReviewed('m1'), isTrue);
      vm.dispose();
    });

    test('an order that was not received yet cannot be reviewed', () async {
      final setup = _Setup();
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, ReviewViewModel.notDeliveredMessage);
      vm.dispose();
    });

    test('an unknown order id is the empty state, and sending then fails with a message', () async {
      final vm = _Setup().viewModel('nope');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, ReviewViewModel.notFoundMessage);
      final result = await vm.submit.execute();
      expect((result! as Err<int>).error.message, ReviewViewModel.notFoundMessage);
      vm.dispose();
    });

    test('it stays loading until both the order and the reviews have arrived', () async {
      final setup = _Setup(reviews: _NeverAnswers());
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      expect(vm.state, isA<ViewLoading<Order>>());
      vm.dispose();
    });

    test('a failed load, of the order or of the reviews, is an error that is recorded; retry loads again', () async {
      for (final setup in [_Setup(orders: _FailingOrders()), _Setup(reviews: _FailingReviews())]) {
        final vm = setup.viewModel('A-204');
        await pumpEventQueue();

        expect(vm.state, isA<ViewError<Order>>());
        expect((vm.state as ViewError<Order>).message, const NetworkException().message);
        expect(setup.crash.errors, isNotEmpty);

        vm.load();
        expect(vm.state, isA<ViewLoading<Order>>());
        await pumpEventQueue();
        expect(vm.state, isA<ViewError<Order>>());
        vm.dispose();
      }
    });

    test(
      'the fake refuses what the rules refuse: an undelivered order, a bad rating, an odd tag, a long comment',
      () async {
        final orders = FakeOrderRepository();
        final reviews = FakeReviewRepository();
        await placeTestOrder(orders, uid: 'u1');
        final pending = orders.all.single;
        expect(await reviews.save(order: pending, item: _combo, rating: 5), isA<Err<Review>>());

        final setup = _Setup();
        await setup.deliveredOrder();
        final delivered = setup.orders.all.single;
        Future<Result<Review>> save({int rating = 5, String comment = '', List<String> tags = const []}) =>
            setup.reviews.save(order: delivered, item: _combo, rating: rating, comment: comment, tags: tags);
        expect((await save(rating: 0) as Err<Review>).error, isA<ValidationException>());
        expect((await save(rating: 6) as Err<Review>).error, isA<ValidationException>());
        expect((await save(tags: const ['crispy']) as Err<Review>).error, isA<ValidationException>());
        expect((await save(comment: 'x' * 501) as Err<Review>).error, isA<ValidationException>());
        expect(await save(), isA<Ok<Review>>());
      },
    );
  });
}
