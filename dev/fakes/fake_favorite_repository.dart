import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

/// Behaves like the Firestore version: a dish is hearted once, the last one added comes first.
class FakeFavoriteRepository implements FavoriteRepository {
  final _byUser = <String, LiveValue<List<Favorite>>>{};
  var _clock = DateTime(2026, 11, 2, 8);
  AppException? failNextWrite;

  LiveValue<List<Favorite>> _of(String uid) => _byUser.putIfAbsent(uid, () => LiveValue(const []));

  List<Favorite> of(String uid) => _of(uid).value;

  @override
  Stream<List<Favorite>> watch(String uid) => _of(uid).stream;

  @override
  Future<Result<void>> add(String uid, MenuItem item) async {
    if (failNextWrite case final error?) {
      failNextWrite = null;
      return Result.error(error);
    }
    final favorite = Favorite.of(item);
    if (of(uid).any((f) => f.dishId == favorite.dishId)) return const Result.ok(null);
    _clock = _clock.add(const Duration(minutes: 1));
    _of(uid).set([
      Favorite(
        dishId: favorite.dishId,
        name: favorite.name,
        priceVnd: favorite.priceVnd,
        category: favorite.category,
        imageUrl: favorite.imageUrl,
        createdAt: _clock,
      ),
      ...of(uid),
    ]);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> remove(String uid, String dishId) async {
    if (failNextWrite case final error?) {
      failNextWrite = null;
      return Result.error(error);
    }
    _of(uid).set([
      for (final f in of(uid))
        if (f.dishId != dishId) f,
    ]);
    return const Result.ok(null);
  }
}
