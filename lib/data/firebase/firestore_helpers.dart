import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/utils/paged.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class Stamp {
  static Map<String, Object> created() => {
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, Object> updated() => {'updatedAt': FieldValue.serverTimestamp()};
}

DateTime? readDate(Object? value) => switch (value) {
  Timestamp() => value.toDate(),
  DateTime() => value,
  _ => null,
};

DateTime readDateOr(Object? value, DateTime whenPending) => readDate(value) ?? whenPending;

T readEnum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    name is String ? values.asNameMap()[name] ?? fallback : fallback;

Future<Result<T>> runGuardedTransaction<T>(FirebaseFirestore db, Future<T> Function(Transaction tx) handler) async {
  AppException? rejected;
  try {
    final value = await db.runTransaction<T>((tx) async {
      rejected = null;
      try {
        return await handler(tx);
      } on AppException catch (error) {
        rejected = error;
        rethrow;
      }
    });
    return Result.ok(value);
  } catch (error, stack) {
    return Result.error(rejected ?? toAppException(error, stack));
  }
}

final class FirestorePageCursor implements PageCursor {
  const FirestorePageCursor(this.last);

  final DocumentSnapshot<Map<String, dynamic>> last;
}

Future<Result<Paged<T>>> fetchPage<T>(
  Query<Map<String, dynamic>> query, {
  required T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) fromDoc,
  int limit = Paged.defaultLimit,
  PageCursor? after,
}) async {
  if (Paged.checkLimit(limit) case final error?) return Result.error(error);
  final Query<Map<String, dynamic>> start;
  switch (after) {
    case null:
      start = query;
    case FirestorePageCursor(:final last):
      start = query.startAfterDocument(last);
    default:
      return const Result.error(ValidationException('Con trỏ trang không hợp lệ.'));
  }
  return guard(() async {
    final snapshot = await start.limit(limit + 1).get();
    return pageFromOverfetch(snapshot.docs, limit: limit, map: fromDoc, cursorOf: FirestorePageCursor.new);
  });
}
