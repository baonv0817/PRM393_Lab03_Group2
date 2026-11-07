import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/favorite_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

/// `users/{uid}/favorites/{dishId}`. The rules let only the owner read and write.
class FirestoreFavoriteRepository implements FavoriteRepository {
  FirestoreFavoriteRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> _favorites(String uid) => _db.collection('users').doc(uid).collection('favorites');

  @override
  Stream<List<Favorite>> watch(String uid) => guardStream(
    _favorites(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) favoriteFromData(doc.id, doc.data())]),
  );

  @override
  Future<Result<void>> add(String uid, MenuItem item) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    final favorite = Favorite.of(item);
    final ref = _favorites(uid).doc(favorite.dishId);
    // A second tap must not move the dish to the top of the list again.
    if ((await ref.get()).exists) return;
    await ref.set({
      'dishId': favorite.dishId,
      'name': favorite.name,
      'priceVnd': favorite.priceVnd,
      if (favorite.category != null) 'category': favorite.category!.name,
      'imageUrl': ?favorite.imageUrl,
      ...Stamp.created(),
    });
  });

  @override
  Future<Result<void>> remove(String uid, String dishId) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    await _favorites(uid).doc(dishId).delete();
  });
}

Favorite favoriteFromData(String id, Json data) => Favorite(
  dishId: id,
  name: data['name'] as String? ?? '',
  priceVnd: (data['priceVnd'] as num?)?.toInt() ?? 0,
  category: data['category'] is String ? ItemCategory.values.asNameMap()[data['category']] : null,
  imageUrl: data['imageUrl'] as String?,
  createdAt: readDate(data['createdAt']),
);
