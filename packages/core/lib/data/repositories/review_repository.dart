import 'package:breakbite_core/domain/models/cart_item.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/domain/models/review.dart';
import 'package:breakbite_core/utils/result.dart';

abstract interface class ReviewRepository {
  static const maxCommentLength = 500;
  static const maxTags = 4;

  /// The quick tags of S23, as they are stored.
  static const tags = ['tasty', 'fast', 'hot', 'wellPacked'];

  /// Menu item ids are `<kioskId>-<dishId>`; the dish id gathers the reviews of a dish across kiosks.
  static String dishIdOf(String kioskId, String itemId) {
    final prefix = '$kioskId-';
    return itemId.startsWith(prefix) ? itemId.substring(prefix.length) : itemId;
  }

  /// Saves the customer's review of one item of a delivered order (S23): creates it, or changes it when
  /// the customer reviewed that item before. [authorName] is the customer's display name; only its
  /// shortened public form is stored. Fails with `ValidationException` (rating outside 1–5, an unknown tag,
  /// too many tags, a comment longer than [maxCommentLength]), `PermissionDeniedException` (the order is
  /// not delivered or not the customer's) or `NetworkException`.
  Future<Result<Review>> save({
    required Order order,
    required CartItem item,
    required int rating,
    String comment = '',
    List<String> tags = const [],
    String authorName = '',
  });

  /// The reviews the customer already wrote for [orderId], live. Takes the uid so only the customer's own
  /// reviews are read.
  Stream<List<Review>> watchOfOrder(String uid, String orderId);
}
