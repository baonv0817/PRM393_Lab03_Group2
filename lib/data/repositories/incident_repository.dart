import 'package:breakbite/domain/models/incident.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class IncidentRepository {
  static const maxDescriptionLength = 500;

  /// The customer reports a problem with one of their orders (S24). There is at most one report per
  /// order: a second one is refused. Fails with `ValidationException` when the description is empty or
  /// longer than [maxDescriptionLength], `PermissionDeniedException` when the order already has a report
  /// or is not the customer's, or `NetworkException`.
  Future<Result<Incident>> report({
    required Order order,
    required IncidentType type,
    required String description,
    String customerName = '',
  });

  /// The customer's report about [orderId], `null` while there is none; it follows the kiosk's handling.
  /// Takes the uid because the rules only let the owner (or the kiosk's staff) read it.
  Stream<Incident?> watchOfOrder(String uid, String orderId);
}
