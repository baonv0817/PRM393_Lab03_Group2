import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/utils/paged.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Server timestamps every document carries (DB-16). Spread them into the data of each write:
/// `ref.set({...data, ...Stamp.created()})`, `ref.update({...changes, ...Stamp.updated()})`.
abstract final class Stamp {
  static Map<String, Object> created() => {
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, Object> updated() => {'updatedAt': FieldValue.serverTimestamp()};
}

/// Reads a Firestore date field. A server timestamp that is still pending on this device (the
/// local echo of our own write) reads as `null`, so pass [whenPending] where a value is required.
DateTime? readDate(Object? value) => switch (value) {
  Timestamp() => value.toDate(),
  DateTime() => value,
  _ => null,
};

DateTime readDateOr(Object? value, DateTime whenPending) => readDate(value) ?? whenPending;

/// Reads an enum stored by its `name`; unknown or missing values give [fallback].
T readEnum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    name is String ? values.asNameMap()[name] ?? fallback : fallback;

/// The Firestore [PageCursor]: the last document of the page that was returned.
final class FirestorePageCursor implements PageCursor {
  const FirestorePageCursor(this.last);

  final DocumentSnapshot<Map<String, dynamic>> last;
}

/// Reads one page of [query] (which must already have its `orderBy`) and maps each document with
/// [fromDoc]. Implements the `limit + 1` rule of `CONTRIBUTING.md` section 7.
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
