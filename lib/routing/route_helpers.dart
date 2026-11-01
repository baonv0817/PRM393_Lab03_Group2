import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

GoRoute placeholderRoute(String path, String code, String title, String owner, {bool showBack = true}) {
  return GoRoute(
    path: path,
    builder: (context, state) => PlaceholderScreen(
      code: code,
      title: title,
      owner: owner,
      showBack: showBack,
      onExit: () => context.go(AppRoutes.home),
    ),
  );
}
