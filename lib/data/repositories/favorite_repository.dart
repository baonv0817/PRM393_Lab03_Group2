import 'package:breakbite/domain/models/favorite.dart';
import 'package:breakbite/domain/models/menu_item.dart';
import 'package:breakbite/utils/result.dart';

/// The dishes a customer hearted (S04, S13). `users/{uid}/favorites/{dishId}`.
abstract interface class FavoriteRepository {
  /// The favorites, the one added last first. Emits again after every change.
  Stream<List<Favorite>> watch(String uid);

  /// Hearts [item]'s dish. Hearting it twice changes nothing.
  Future<Result<void>> add(String uid, MenuItem item);

  /// Takes the heart off the dish [dishId]. Removing one that is not there is not an error.
  Future<Result<void>> remove(String uid, String dishId);
}
