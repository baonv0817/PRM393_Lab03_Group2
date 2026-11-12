/// Lifecycle of an announcement: admins write a [draft], [published] ones reach the mobile inbox (S19) in real
/// time, and [archived] ones leave it. Nobody deletes an announcement (docs/data-model.md section 3.10).
enum AnnouncementStatus { draft, published, archived }

/// A message from the web admin's announcement form (W05) to customers.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.createdBy,
    this.kioskId,
    this.createdAt,
    this.publishedAt,
  });

  static const maxTitleLength = 120;
  static const maxBodyLength = 1000;

  final String id;
  final String title;
  final String body;
  final AnnouncementStatus status;

  /// The uid of the admin who wrote it; it never changes.
  final String createdBy;

  /// Only customers who chose this kiosk see it; `null` means every kiosk.
  final String? kioskId;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  /// Whether a customer whose selected kiosk is [selectedKioskId] should see it.
  bool reaches(String? selectedKioskId) =>
      status == AnnouncementStatus.published && (kioskId == null || kioskId == selectedKioskId);

  /// The Vietnamese message to show next to the form, or `null` when the text can be saved. The rules check the
  /// same limits (firebase/firestore.rules, validAnnouncement).
  static String? problemWith({required String title, required String body}) {
    final t = title.trim(), b = body.trim();
    if (t.isEmpty) return 'Nhập tiêu đề thông báo.';
    if (t.length > maxTitleLength) return 'Tiêu đề tối đa $maxTitleLength ký tự.';
    if (b.isEmpty) return 'Nhập nội dung thông báo.';
    if (b.length > maxBodyLength) return 'Nội dung tối đa $maxBodyLength ký tự.';
    return null;
  }
}
