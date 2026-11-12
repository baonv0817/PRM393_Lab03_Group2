import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_announcement_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_menu_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_order_repository.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/data/services/auth_service.dart';
import 'package:breakbite_core/data/services/firebase/firebase_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// The web admin's data layer: the same repositories as the mobile app, from packages/core. Screens and view
/// models only see the interfaces, so tests swap in fakes ([adminProviders]).
List<SingleChildWidget> firebaseProviders() {
  final db = FirebaseFirestore.instance;
  return adminProviders(
    auth: FirebaseAuthService.web(auth: FirebaseAuth.instance, db: db),
    orders: FirestoreOrderRepository(db),
    menu: FirestoreMenuRepository(db),
    announcements: FirestoreAnnouncementRepository(db),
  );
}

List<SingleChildWidget> adminProviders({
  required AuthService auth,
  required OrderRepository orders,
  required MenuRepository menu,
  required AnnouncementRepository announcements,
}) => [
  Provider<AuthService>.value(value: auth),
  Provider<OrderRepository>.value(value: orders),
  Provider<MenuRepository>.value(value: menu),
  Provider<AnnouncementRepository>.value(value: announcements),
  ChangeNotifierProvider<AdminSession>(
    create: (_) => AdminSession(auth: auth, menu: menu),
  ),
];
