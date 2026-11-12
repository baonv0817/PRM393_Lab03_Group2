import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

import 'live_value.dart';

/// Behaves like the Firestore version: one review per item per order, changed by saving again, validated
/// like the rules, and only delivered orders can be reviewed.
class FakeReviewRepository implements ReviewRepository {
  final _reviews = LiveValue<List<Review>>(const []);
  var _clock = DateTime(2026, 11, 2, 12);
  AppException? failNextSave;

  /// Every save, in order, including the ones that changed an existing review.
  final saves = <Review>[];

  List<Review> get all => _reviews.value;

  @override
  Future<Result<Review>> save({
    required Order order,
    required CartItem item,
    required int rating,
    String comment = '',
    List<String> tags = const [],
    String authorName = '',
  }) async {
    if (failNextSave case final error?) {
      failNextSave = null;
      return Result.error(error);
    }
    if (rating < 1 || rating > 5) return const Result.error(ValidationException('Chọn số sao từ 1 đến 5.'));
    final text = comment.trim();
    if (text.length > ReviewRepository.maxCommentLength) {
      return const Result.error(ValidationException('Nhận xét tối đa ${ReviewRepository.maxCommentLength} ký tự.'));
    }
    if (tags.length > ReviewRepository.maxTags || tags.any((t) => !ReviewRepository.tags.contains(t))) {
      return const Result.error(ValidationException('Thẻ nhận xét không hợp lệ.'));
    }
    if (order.status != OrderStatus.delivered) return const Result.error(PermissionDeniedException());
    _clock = _clock.add(const Duration(minutes: 1));
    final before = all.where((r) => r.orderId == order.id && r.itemId == item.itemId).firstOrNull;
    final review = Review(
      orderId: order.id,
      itemId: item.itemId,
      dishId: before?.dishId ?? ReviewRepository.dishIdOf(order.kioskId, item.itemId),
      kioskId: order.kioskId,
      uid: order.uid,
      authorName: before?.authorName ?? _public(authorName),
      rating: rating,
      comment: text,
      tags: List.unmodifiable(tags),
      createdAt: before?.createdAt ?? _clock,
      updatedAt: before == null ? null : _clock,
    );
    _reviews.set([review, ...all.where((r) => r.id != review.id)]);
    saves.add(review);
    return Result.ok(review);
  }

  @override
  Stream<List<Review>> watchOfOrder(String uid, String orderId) =>
      _reviews.stream.map((list) => list.where((r) => r.uid == uid && r.orderId == orderId).toList());

  static String _public(String displayName) {
    final name = Review.publicAuthorName(displayName);
    return name.length > 30 ? name.substring(0, 30) : name;
  }
}
