import 'package:breakbite_core/domain/app_exception.dart';

/// One page of a list read with a cursor (Firestore has no page numbers or offsets).
/// [next] is `null` when there is nothing after this page.
final class Paged<T> {
  const Paged(this.items, {this.next});

  const Paged.empty() : items = const <Never>[], next = null;

  /// Page size used when the caller does not choose one.
  static const defaultLimit = 20;

  /// Largest page a repository accepts.
  static const maxLimit = 50;

  /// `null` when [limit] is acceptable, otherwise the error every repository returns.
  static ValidationException? checkLimit(int limit) =>
      limit < 1 || limit > maxLimit ? const ValidationException('Số mục mỗi trang phải từ 1 đến $maxLimit.') : null;

  final List<T> items;
  final PageCursor? next;

  bool get hasMore => next != null;
}

/// Builds a page from a query that asked for `limit + 1` rows: the extra row only proves that another
/// page exists, and the cursor points at the last row that is returned.
Paged<T> pageFromOverfetch<R, T>(
  List<R> rows, {
  required int limit,
  required T Function(R row) map,
  required PageCursor Function(R row) cursorOf,
}) {
  final hasMore = rows.length > limit;
  final kept = hasMore ? rows.sublist(0, limit) : rows;
  return Paged(kept.map(map).toList(), next: hasMore && kept.isNotEmpty ? cursorOf(kept.last) : null);
}

/// Opaque position after the last item of a page. Only the repository that created it can read it
/// (the Firestore version wraps a `DocumentSnapshot`); a view model keeps it and passes it back as
/// `after` to load the next page.
abstract interface class PageCursor {}
