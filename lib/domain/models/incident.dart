enum IncidentType { wrongItem, missingItem, quality, late, other }

enum IncidentStatus { open, inProgress, resolved }

class Incident {
  const Incident({
    required this.id,
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
    this.handledBy,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String kioskId;
  final String uid;
  final String customerName;
  final IncidentType type;
  final String description;
  final String? photoUrl;
  final IncidentStatus status;
  final String? resolution;
  final String? handledBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}
