import 'package:breakbite/ui/core/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// A route that uses the placeholder screen. The owner replaces `placeholderRoute(...)` with
/// `GoRoute(path: ..., builder: (context, state) => TenManThat())` once the screen is done.
GoRoute placeholderRoute(String path, String code, String title, String owner, {bool showBack = true}) {
  return GoRoute(
    path: path,
    builder: (context, state) => PlaceholderScreen(code: code, title: title, owner: owner, showBack: showBack),
  );
}
