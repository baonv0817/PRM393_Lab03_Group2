import 'package:breakbite_core/domain/models/kiosk.dart';
import 'package:breakbite_core/domain/models/voucher.dart';

/// What must hold for a voucher to be saved: the same checks as `firestore.rules`, so a wrong voucher is refused
/// with a sentence before it reaches the database.
abstract final class VoucherRules {
  static final code = RegExp(r'^[A-Z0-9]{3,20}$');
  static const maxTitleLength = 60;

  /// Why [voucher] cannot be saved, or `null`.
  static String? problemOf(Voucher voucher, {required bool isNew}) {
    if (isNew && !code.hasMatch(voucher.code)) return 'Mã gồm chữ in hoa và số, 3 đến 20 ký tự.';
    if (voucher.title.trim().isEmpty) return 'Nhập tên chương trình.';
    if (voucher.title.trim().length > maxTitleLength) return 'Tên tối đa $maxTitleLength ký tự.';
    switch (voucher.discount) {
      case FixedDiscount(:final amountVnd):
        if (amountVnd <= 0) return 'Số tiền giảm phải lớn hơn 0.';
      case PercentDiscount(:final percent, :final maxVnd):
        if (percent < 1 || percent > 100) return 'Phần trăm giảm từ 1 đến 100.';
        if (maxVnd <= 0) return 'Mức giảm tối đa phải lớn hơn 0.';
    }
    if (voucher.minOrderVnd < 0) return 'Đơn tối thiểu không được âm.';
    final from = voucher.activeFrom;
    final to = voucher.activeTo;
    if ((from == null) != (to == null)) return 'Nhập đủ giờ bắt đầu và giờ kết thúc, hoặc để trống cả hai.';
    if (from != null && (!KioskSettings.isClockTime(from) || !KioskSettings.isClockTime(to!))) {
      return 'Giờ phải có dạng 10:15.';
    }
    final starts = voucher.startsAt;
    if (starts != null && !starts.isBefore(voucher.expiresAt)) return 'Ngày bắt đầu phải trước ngày hết hạn.';
    return null;
  }
}
