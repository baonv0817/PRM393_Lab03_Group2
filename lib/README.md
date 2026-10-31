# lib/

MVVM following the official Flutter architecture guide. Full description: [`docs/architecture.md`](../docs/architecture.md).

| Folder | Contains |
|---|---|
| `config/` | `AppDependencies` (every service and repository) and how the Firebase versions are built |
| `routing/` | Router, `AppRoutes` path constants, `routes_p1.dart` to `routes_p5.dart` (one per owner) |
| `domain/models/` | Plain data classes, one file per model; import `models.dart` |
| `data/services/` | Interfaces wrapping an SDK (Auth, Analytics, Crashlytics, FCM, Storage, Remote Config) |
| `data/repositories/` | Interfaces for business data (menu, cart, orders…) and their Firestore versions |
| `ui/core/` | Theme, shared widgets, `ViewState` (owned by P1) |
| `ui/<feature>/` | `view_models/` and `widgets/` (screens) of one feature |
| `utils/` | Helpers that do not depend on the UI |

Fake data lives in `dev/` at the repo root, outside `lib/`, so it never ends up in the submitted build.
