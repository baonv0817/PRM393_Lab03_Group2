/// Stored as the enum name (`missingItem`, not `missing_item`), like every enum in Firestore.
enum IncidentType { wrongItem, missingItem, quality, late, other }

enum IncidentStatus { open, inProgress, resolved }

/// K13: refund the customer, or reject with an explanation.
enum IncidentResolution { refunded, rejected }

class Incident {
  const Incident({
    required this.orderId,
    required this.kioskId,
    required this.uid,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
    this.customerName = '',
    this.photoUrl,
    this.resolution,
    this.resolutionNote,
    this.refundVnd,
    this.handledBy,
    this.resolvedAt,
    this.updatedAt,
  });

  /// At most one incident per order, so the document id is the order id.
  String get id => orderId;
  final String orderId;
  final String kioskId;
  final String uid;
  final String customerName;
  final IncidentType type;
  final String description;
  final String? photoUrl;
  final IncidentStatus status;
  final IncidentResolution? resolution;

  /// Required when [resolution] is [IncidentResolution.rejected].
  final String? resolutionNote;

  /// Simulated refund, at most the order total; set when [resolution] is [IncidentResolution.refunded].
  final int? refundVnd;
  final String? handledBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? updatedAt;
}
