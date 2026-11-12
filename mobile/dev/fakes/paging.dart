import 'dart:math';

import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';

/// Cursor of the in-memory fakes: the index of the first item of the next page.
final class IndexCursor implements PageCursor {
  const IndexCursor(this.offset);

  final int offset;
}

/// Cuts [all] (already sorted) into the page that starts at [after], with the same validation the
/// Firestore repositories apply.
Result<Paged<T>> pageOf<T>(List<T> all, {required int limit, PageCursor? after}) {
  if (Paged.checkLimit(limit) case final error?) return Result.error(error);
  final start = switch (after) {
    null => 0,
    IndexCursor(:final offset) => offset,
    _ => -1,
  };
  if (start < 0) return const Result.error(ValidationException('Con trỏ trang không hợp lệ.'));
  if (start >= all.length) return const Result.ok(Paged.empty());
  final end = min(start + limit, all.length);
  return Result.ok(Paged(all.sublist(start, end), next: end < all.length ? IndexCursor(end) : null));
}
