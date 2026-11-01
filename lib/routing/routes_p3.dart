import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/auth/widgets/sign_in_screen.dart';
import 'package:breakbite/ui/auth/widgets/splash_screen.dart';
import 'package:breakbite/ui/kiosk_picker/view_models/kiosk_view_model.dart';
import 'package:breakbite/ui/kiosk_picker/widgets/kiosk_picker_screen.dart';
import 'package:breakbite/ui/profile/view_models/firebase_demo_view_model.dart';
import 'package:breakbite/ui/profile/view_models/payment_settings_view_model.dart';
import 'package:breakbite/ui/profile/view_models/profile_view_model.dart';
import 'package:breakbite/ui/profile/view_models/student_info_view_model.dart';
import 'package:breakbite/ui/profile/widgets/firebase_demo_screen.dart';
import 'package:breakbite/ui/profile/widgets/payment_settings_screen.dart';
import 'package:breakbite/ui/profile/widgets/profile_screen.dart';
import 'package:breakbite/ui/profile/widgets/student_info_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final GoRoute profileRoute = GoRoute(
  path: AppRoutes.profile,
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => ProfileViewModel(
      orders: context.read<OrderRepository>(),
      crash: context.read<CrashService>(),
      uid: context.read<AuthViewModel>().user?.uid ?? '',
    ),
    child: const ProfileScreen(),
  ),
);

final List<GoRoute> p3Routes = [
  GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
  GoRoute(path: AppRoutes.signIn, builder: (context, state) => const SignInScreen()),
  GoRoute(
    path: AppRoutes.profileInfo,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => StudentInfoViewModel(
        users: context.read<UserRepository>(),
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const StudentInfoScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.profilePayment,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => PaymentSettingsViewModel(
        users: context.read<UserRepository>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const PaymentSettingsScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.firebaseDemo,
    builder: (context, state) {
      final user = context.read<AuthViewModel>().user;
      return ChangeNotifierProvider(
        create: (_) => FirebaseDemoViewModel(
          remoteConfig: context.read<RemoteConfigService>(),
          crash: context.read<CrashService>(),
          analytics: context.read<AnalyticsService>(),
          storage: context.read<StorageService>(),
          reportFiles: context.read<ReportFileService>(),
          reports: context.read<ReportRepository>(),
          orders: context.read<OrderRepository>(),
          uid: user?.uid ?? '',
          customerName: user?.displayName ?? 'Khách',
        ),
        child: const FirebaseDemoScreen(),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.kiosks,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => KioskViewModel(
        menu: context.read<MenuRepository>(),
        session: context.read<SessionRepository>(),
        cart: context.read<CartRepository>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const KioskPickerScreen(),
    ),
  ),
];
