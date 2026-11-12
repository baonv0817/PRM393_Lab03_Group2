import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite_core/ui/core/placeholder_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Builds a seller screen for the staff member's kiosk. The profile is read live, so the kiosk can arrive
/// after the screen was first built (a tab opens before the profile loads, or an admin assigns a kiosk while
/// the app is open) or change later. Give the provider `key: ValueKey(kioskId)` so a fresh ViewModel is built
/// then; a ViewModel that read `kioskId` once would keep saying "no kiosk" until the app restarted.
Widget forKiosk(Widget Function(BuildContext context, String? kioskId) build) =>
    Builder(builder: (context) => build(context, context.select<AuthViewModel, String?>((a) => a.user?.kioskId)));

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
