import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.analytics,
    required this.crash,
    required this.connectivity,
    required this.messaging,
    required this.orderAlerts,
    required this.photoPicker,
    required this.menuAi,
    required this.reminders,
    required this.storage,
    required this.remoteConfig,
    required this.reportFiles,
    required this.menu,
    required this.cart,
    required this.orders,
    required this.reports,
    required this.session,
    required this.users,
    required this.vouchers,
    required this.slots,
    required this.incidents,
    required this.reviews,
    required this.favorites,
    required this.notifications,
  });

  final AuthService auth;
  final AnalyticsService analytics;
  final CrashService crash;
  final ConnectivityService connectivity;
  final MessagingService messaging;
  final OrderAlertService orderAlerts;
  final PhotoPickerService photoPicker;
  final MenuAiService menuAi;
  final ReminderService reminders;
  final StorageService storage;
  final RemoteConfigService remoteConfig;
  final ReportFileService reportFiles;

  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;
  final ReportRepository reports;
  final SessionRepository session;
  final UserRepository users;
  final VoucherRepository vouchers;
  final SlotRepository slots;
  final IncidentRepository incidents;
  final ReviewRepository reviews;
  final FavoriteRepository favorites;
  final NotificationRepository notifications;

  List<SingleChildWidget> get providers => [
    Provider<AuthService>.value(value: auth),
    Provider<AnalyticsService>.value(value: analytics),
    Provider<CrashService>.value(value: crash),
    Provider<ConnectivityService>.value(value: connectivity),
    Provider<MessagingService>.value(value: messaging),
    Provider<OrderAlertService>.value(value: orderAlerts),
    Provider<PhotoPickerService>.value(value: photoPicker),
    Provider<MenuAiService>.value(value: menuAi),
    Provider<ReminderService>.value(value: reminders),
    Provider<StorageService>.value(value: storage),
    Provider<RemoteConfigService>.value(value: remoteConfig),
    Provider<ReportFileService>.value(value: reportFiles),
    Provider<MenuRepository>.value(value: menu),
    Provider<CartRepository>.value(value: cart),
    Provider<OrderRepository>.value(value: orders),
    Provider<ReportRepository>.value(value: reports),
    Provider<SessionRepository>.value(value: session),
    Provider<UserRepository>.value(value: users),
    Provider<VoucherRepository>.value(value: vouchers),
    Provider<SlotRepository>.value(value: slots),
    Provider<IncidentRepository>.value(value: incidents),
    Provider<ReviewRepository>.value(value: reviews),
    Provider<FavoriteRepository>.value(value: favorites),
    Provider<NotificationRepository>.value(value: notifications),
  ];
}
