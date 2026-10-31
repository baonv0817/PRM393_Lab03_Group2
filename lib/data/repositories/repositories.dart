/// Repositories: the source of truth for business data (Firestore). They turn documents into models in
/// `lib/domain/models/` and hide query details; ViewModels only know these interfaces.
library;

export 'cart_repository.dart';
export 'menu_repository.dart';
export 'order_repository.dart';
export 'session_repository.dart';
