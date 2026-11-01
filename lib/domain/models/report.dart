class Report {
  const Report({
    required this.id,
    required this.uid,
    required this.fileName,
    required this.url,
    required this.publicId,
    required this.sizeKb,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final String uid;
  final String fileName;
  final String url;
  final String publicId;
  final int sizeKb;
  final DateTime createdAt;
  final String? orderId;
}
