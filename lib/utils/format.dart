import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi_VN');

/// `39000` becomes `39.000đ`.
String formatVnd(int amount) => '${_vnd.format(amount)}đ';

/// Status name shown to the user.
String orderStatusLabel(String name) => switch (name) {
  'pending' => 'Đã nhận đơn',
  'preparing' => 'Đang làm',
  'ready' => 'Sẵn sàng',
  'delivered' => 'Hoàn tất',
  'cancelled' => 'Đã huỷ',
  _ => name,
};
