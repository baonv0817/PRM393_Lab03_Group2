class Kiosk {
  const Kiosk({
    required this.id,
    required this.name,
    required this.open,
    required this.waitMinutes,
    this.location = '',
    this.openTime,
    this.closeTime,
    this.notice,
  });

  final String id;
  final String name;
  final bool open;
  final int waitMinutes;

  /// Địa điểm đầy đủ, ví dụ "Campus Q9, tầng 2".
  final String location;

  /// Giờ mở và đóng cửa dạng "HH:mm".
  final String? openTime;
  final String? closeTime;

  /// Thông báo hiện ở Trang chủ khi quán đóng hoặc có thay đổi (S21).
  final String? notice;
}
