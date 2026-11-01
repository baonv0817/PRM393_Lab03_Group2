import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/auth/widgets/sign_in_screen.dart';
import 'package:breakbite/ui/profile/view_models/profile_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_screen.dart';
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
  GoRoute(path: AppRoutes.signIn, builder: (context, state) => const SignInScreen()),
  placeholderRoute(AppRoutes.profileInfo, 'S16', 'Hồ sơ sinh viên', 'P3'),
  placeholderRoute(AppRoutes.profilePayment, 'S17', 'Phương thức thanh toán', 'P3'),
  placeholderRoute(AppRoutes.firebaseDemo, 'DEMO', 'Khu demo Firebase', 'P3'),
  placeholderRoute(AppRoutes.kiosks, 'S27', 'Chọn kiosk', 'P3'),
];
