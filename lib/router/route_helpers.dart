import 'package:go_router/go_router.dart';

import '../screens/placeholder_screen.dart';

/// Route dùng màn tạm. Người phụ trách thay `placeholderRoute(...)` bằng
/// `GoRoute(path: ..., builder: (context, state) => TenManThat())` khi làm xong màn.
GoRoute placeholderRoute(String path, String code, String title, String owner, {bool showBack = true}) {
  return GoRoute(
    path: path,
    builder: (context, state) => PlaceholderScreen(code: code, title: title, owner: owner, showBack: showBack),
  );
}
