import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/review_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxAuthorNameLength = 30;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  CollectionReference<Json> get _reviews => _db.collection('reviews');

  /// The document id is `<orderId>_<itemId>`, so each item of an order has one review. Saving again by the
  /// same customer changes only the rating, comment and tags, which is all the rules let the owner change.
  @override
  Future<Result<Review>> save({
    required Order order,
    required CartItem item,
    required int rating,
    String comment = '',
    List<String> tags = const [],
    String authorName = '',
  }) => guard(() async {
    if (rating < 1 || rating > 5) throw const ValidationException('Chọn số sao từ 1 đến 5.');
    final text = comment.trim();
    if (text.length > ReviewRepository.maxCommentLength) {
      throw const ValidationException('Nhận xét tối đa ${ReviewRepository.maxCommentLength} ký tự.');
    }
    if (tags.length > ReviewRepository.maxTags || tags.any((t) => !ReviewRepository.tags.contains(t))) {
      throw const ValidationException('Thẻ nhận xét không hợp lệ.');
    }
    final ref = _reviews.doc('${order.id}_${item.itemId}');
    final existing = await ref.get();
    final dishId = ReviewRepository.dishIdOf(order.kioskId, item.itemId);
    if (existing.exists) {
      await ref.update({
        'rating': rating,
        'comment': text.isEmpty ? FieldValue.delete() : text,
        'tags': tags,
        ...Stamp.updated(),
      });
      final before = reviewFromData(existing.id, existing.data()!, now: _clock());
      return Review(
        orderId: before.orderId,
        itemId: before.itemId,
        dishId: before.dishId,
        kioskId: before.kioskId,
        uid: before.uid,
        authorName: before.authorName,
        rating: rating,
        comment: text,
        tags: tags,
        createdAt: before.createdAt,
        updatedAt: _clock(),
      );
    }
    final name = Review.publicAuthorName(authorName);
    final publicName = name.length > maxAuthorNameLength ? name.substring(0, maxAuthorNameLength) : name;
    await ref.set({
      'orderId': order.id,
      'itemId': item.itemId,
      'dishId': dishId,
      'kioskId': order.kioskId,
      'uid': order.uid,
      if (authorName.trim().isNotEmpty) 'authorName': publicName,
      'rating': rating,
      if (text.isNotEmpty) 'comment': text,
      if (tags.isNotEmpty) 'tags': tags,
      ...Stamp.created(),
    });
    return Review(
      orderId: order.id,
      itemId: item.itemId,
      dishId: dishId,
      kioskId: order.kioskId,
      uid: order.uid,
      authorName: authorName.trim().isEmpty ? '' : publicName,
      rating: rating,
      comment: text,
      tags: tags,
      createdAt: _clock(),
    );
  });

  @override
  Stream<List<Review>> watchOfOrder(String uid, String orderId) => guardStream(
    _reviews
        .where('uid', isEqualTo: uid)
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) reviewFromData(doc.id, doc.data(), now: _clock())]),
  );
}
