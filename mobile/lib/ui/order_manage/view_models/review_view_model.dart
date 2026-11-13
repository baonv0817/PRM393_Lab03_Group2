import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// What the customer has chosen for one item so far: 0 stars means "not rated".
class ReviewDraft {
  const ReviewDraft({this.rating = 0, this.tags = const [], this.comment = ''});

  final int rating;
  final List<String> tags;
  final String comment;

  ReviewDraft copyWith({int? rating, List<String>? tags, String? comment}) =>
      ReviewDraft(rating: rating ?? this.rating, tags: tags ?? this.tags, comment: comment ?? this.comment);
}

/// S23: rate the items of a delivered order. Each item gets its own stars, quick tags and comment; the
/// ones already reviewed show what was written and can be changed.
class ReviewViewModel extends ChangeNotifier with SafeChangeNotifier {
  ReviewViewModel({
    required this.orders,
    required this.reviews,
    required this.crash,
    required this.uid,
    required this.displayName,
    required this.orderId,
  }) {
    submit = Command0(_submit);
    load();
  }

  static const notFoundMessage = 'Không tìm thấy đơn này.';
  static const notDeliveredMessage = 'Bạn đánh giá được món sau khi đã nhận đơn.';
  static const maxCommentLength = ReviewRepository.maxCommentLength;

  /// The quick tags, in the order they are offered.
  static const tags = ReviewRepository.tags;

  final OrderRepository orders;
  final ReviewRepository reviews;
  final CrashService crash;
  final String uid;
  final String displayName;
  final String orderId;

  /// Runs the save of every changed item; its value is how many reviews were saved.
  late final Command0<int> submit;

  StreamSubscription<Order?>? _orderSub;
  StreamSubscription<List<Review>>? _reviewsSub;
  Order? _order;
  Map<String, Review> _stored = const {};
  final Map<String, ReviewDraft> _drafts = {};
  bool _orderLoaded = false;
  bool _reviewsLoaded = false;
  String? _loadError;

  Order? get order => _order;

  ViewState<Order> get state {
    if (_loadError case final message?) return ViewError(message);
    if (!_orderLoaded || !_reviewsLoaded) return const ViewLoading();
    final o = _order;
    if (o == null) return const ViewEmpty(notFoundMessage);
    if (o.status != OrderStatus.delivered) return const ViewEmpty(notDeliveredMessage);
    return ViewData(o);
  }

  /// One entry per dish: a review is about the dish, so the same dish ordered twice with other options is rated once.
  List<CartItem> get items {
    final seen = <String>{};
    return [
      for (final line in _order?.items ?? const <CartItem>[])
        if (seen.add(line.itemId)) line,
    ];
  }

  void load() {
    unawaited(_orderSub?.cancel());
    unawaited(_reviewsSub?.cancel());
    _order = null;
    _stored = const {};
    _drafts.clear();
    _orderLoaded = false;
    _reviewsLoaded = false;
    _loadError = null;
    notifyListeners();
    _orderSub = orders.watchOrder(orderId).listen((value) {
      _order = value;
      _orderLoaded = true;
      _fillDrafts();
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => _fail(error, stack, 'review.watchOrder'));
    _reviewsSub = reviews.watchOfOrder(uid, orderId).listen((value) {
      _stored = {for (final review in value) review.itemId: review};
      _reviewsLoaded = true;
      _fillDrafts();
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => _fail(error, stack, 'review.watchReviews'));
  }

  void _fail(Object error, StackTrace stack, String where) {
    crash.recordNonFatal(error, stack, where);
    _loadError = error is AppException ? error.message : 'Không tải được đơn hàng.';
    notifyListeners();
  }

  /// Starts every item from what was already written, once both the order and the reviews are known. Later
  /// changes of the stored reviews never overwrite what the customer is typing.
  void _fillDrafts() {
    if (!_orderLoaded || !_reviewsLoaded) return;
    for (final item in items) {
      _drafts.putIfAbsent(item.itemId, () {
        final review = _stored[item.itemId];
        return review == null
            ? const ReviewDraft()
            : ReviewDraft(rating: review.rating, tags: review.tags, comment: review.comment);
      });
    }
  }

  ReviewDraft draftOf(String itemId) => _drafts[itemId] ?? const ReviewDraft();

  /// This item already has a saved review.
  bool isReviewed(String itemId) => _stored.containsKey(itemId);

  /// The draft has a rating and differs from what is saved (or nothing is saved yet).
  bool isDirty(String itemId) {
    final draft = draftOf(itemId);
    if (draft.rating < 1) return false;
    final saved = _stored[itemId];
    if (saved == null) return true;
    return saved.rating != draft.rating ||
        saved.comment.trim() != draft.comment.trim() ||
        !setEquals(saved.tags.toSet(), draft.tags.toSet());
  }

  void setRating(String itemId, int stars) {
    if (stars < 1 || stars > 5) return;
    _drafts[itemId] = draftOf(itemId).copyWith(rating: stars);
    notifyListeners();
  }

  void toggleTag(String itemId, String tag) {
    if (!tags.contains(tag)) return;
    final draft = draftOf(itemId);
    final next = [...draft.tags];
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    if (next.length > ReviewRepository.maxTags) return;
    _drafts[itemId] = draft.copyWith(tags: next);
    notifyListeners();
  }

  void setComment(String itemId, String value) {
    final text = value.length > maxCommentLength ? value.substring(0, maxCommentLength) : value;
    _drafts[itemId] = draftOf(itemId).copyWith(comment: text);
    notifyListeners();
  }

  /// How many items will be saved by the next send.
  int get pendingCount => items.where((i) => isDirty(i.itemId)).length;

  bool get canSubmit => pendingCount > 0;

  /// What is still missing before something can be sent.
  String? get missingHint {
    if (canSubmit) return null;
    final anyRating = items.any((i) => draftOf(i.itemId).rating >= 1);
    return anyRating ? 'Bạn chưa thay đổi gì so với đánh giá đã gửi.' : 'Chọn số điểm cho ít nhất một món.';
  }

  Future<Result<int>> _submit() async {
    final o = _order;
    if (o == null) return const Result.error(NotFoundException(message: notFoundMessage));
    var saved = 0;
    for (final item in items.where((i) => isDirty(i.itemId))) {
      final draft = draftOf(item.itemId);
      final result = await reviews.save(
        order: o,
        item: item,
        rating: draft.rating,
        comment: draft.comment,
        tags: draft.tags,
        authorName: displayName,
      );
      if (result case Err(:final error)) {
        crash.recordNonFatal(error, error.stackTrace, 'review.save');
        return Result.error(error);
      }
      saved++;
    }
    return Result.ok(saved);
  }

  @override
  void dispose() {
    unawaited(_orderSub?.cancel());
    unawaited(_reviewsSub?.cancel());
    submit.dispose();
    super.dispose();
  }
}
