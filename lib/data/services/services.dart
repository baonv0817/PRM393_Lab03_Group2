/// Services: thin wrappers around external SDKs (Firebase Auth, Analytics, Crashlytics, FCM, Storage,
/// Remote Config). They hold no business data; ViewModels and repositories only know these interfaces.
library;

export 'analytics_events.dart';
export 'analytics_service.dart';
export 'auth_service.dart';
export 'crash_service.dart';
export 'messaging_service.dart';
export 'remote_config_service.dart';
export 'storage_service.dart';
