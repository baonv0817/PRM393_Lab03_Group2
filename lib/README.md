# lib/

Folder skeleton following MVVM (see `docs/architecture.md`). Dependencies only point downward: `screens → widgets, viewmodels → services → firebase, models`.

| Folder | Contains |
|---|---|
| `models/` | Plain data classes (MenuItem, Order, Kiosk, Voucher…) |
| `services/` | Interfaces and implementations for every call to the outside (Auth, Firestore, Storage, FCM, Analytics, Crashlytics, Remote Config) |
| `firebase/` | Firebase initialization, `firebase_options.dart` |
| `viewmodels/` | Screen state and business logic |
| `screens/` | Screens (no SDK calls, no logic in `build()`) |
| `widgets/` | Reusable Lab 2 components |
| `theme/` | Tokens turned into `ThemeData` |
| `utils/` | Helper functions that do not depend on the UI |
