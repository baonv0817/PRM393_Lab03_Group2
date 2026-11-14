# Task: Modernize Web Admin Review Queue with Novel Studio Design Language

- Workspace: breakbite
- Target: Redesign and modernize `https://breakbite-1315b.web.app/#/review` (`ReviewQueueScreen`) with global components inspired by Novel Studio.
- Repo: PRM393_Lab03_Group2
- Branch: feat/review-queue-studio-ui
- Source reference: novel-studio (`ui.tsx`, `ReviewWorkspace.tsx`, `styles.css`)
- Scope: `web/lib/ui/review_queue/view_models/review_queue_view_model.dart`, `web/lib/ui/review_queue/widgets/review_queue_screen.dart`
- Completed changes:
  1. Segmented tabs with count pills (`_StudioTabButton`) for 'Chờ duyệt' and 'Đang làm' in Novel Studio style.
  2. Studio search and sort toolbar (FIFO, Mới nhất, Giá trị đơn).
  3. Studio-styled order list items (`_StudioOrderTile`) with active border indicator (`border-left` primary 4px), urgent/waiting time badge, clean metadata.
  4. In-card collapsible dish preview (`AnimatedSize` expand/collapse toggle) right on the list card.
  5. Studio detail panel (`_StudioOrderDetail`) with eyebrow, status badges (`OrderStage`), customer info grid, collapsible dish accordion (`_itemsCollapsed`), and customer order notes callout.
  6. Refined ready-in selection pills (`_StudioReadyInPicker`) with checkmark icons.
  7. Modernized reject dialog (`_StudioRejectDialog`) with reason chips and custom input.
- Verification:
  - `flutter analyze` in `web/`: 0 issues found.
  - `flutter test` in `web/`: 92/92 tests passed cleanly (including `architecture_test.dart` and `view_models_test.dart`).
- Status: completed
