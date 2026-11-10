# Output of the AI review (T70)

- Tool: Claude Code, skill `/code-review` (model Claude Sonnet 5.5), effort `medium`.
- Run on: 10/11/2026, on `main` at commit `2dc91ab`, with the target `lib/data/repositories lib/ui/order_manage lib/ui/seller_shop lib/ui/seller_menu` (the repositories and the screens of P2 that the other owners' code depends on). It reviewed these directories, not the diff of one pull request; every finding below points to a file and a line.
- What happened next: each finding was opened in the code and checked before a decision was made. The decisions, the reasons and the fix commits are in [`docs/code-review.md`](../../docs/code-review.md). Two of the claims turned out to be partly wrong (see CR-10, and the rules that answer CR-07); that is why the decisions are recorded one by one.

The tool's answer, unchanged (10 findings, most severe first):

```json
[
  {
    "file": "lib/data/repositories/firestore/firestore_order_repository.dart",
    "line": 52,
    "summary": "placeOrder and editPendingOrder price the order from client-supplied CartItem prices and never read menu_items, so a tampered or stale price is written as the order total.",
    "failure_scenario": "The cart holds an item at 10,000 VND, but the menu price has since changed to 50,000 VND or the item is sold out. A modified client sends priceVnd: 1. `_price()` / `priceOrder()` only apply the voucher and the order is saved with the wrong total, because the transaction only reads the kiosk, voucher and slot. Staff then see a wrong subtotal. The edit-order docs claim the repository 'prices the order again on the server side', but it only re-multiplies the client's prices."
  },
  {
    "file": "lib/data/repositories/firestore/firestore_menu_repository.dart",
    "line": 91,
    "summary": "upsertItem for a new item (item.id empty) falls back to tx.update when the doc already exists, so it silently overwrites another item. The form's duplicate check is a separate, non-atomic getItem.",
    "failure_scenario": "Two staff add 'Cà phê sữa' at the same moment, or the item is created between the form's getItem check and the upsert. The transaction sees current.exists, runs tx.update and overwrites the other item's price, category and soldOut. Because the new MenuItem is built with default fields, the existing item's imageUrl may also be dropped. The repository should reject an existing doc when item.id is empty."
  },
  {
    "file": "lib/data/repositories/firestore/firestore_order_repository.dart",
    "line": 275,
    "summary": "In _step, the slot release does tx.update on the slot doc without reading it first. If the slot doc was deleted or rotated away, the whole transaction fails, so the cancel or reject cannot complete.",
    "failure_scenario": "A pending order holds pickupSlotId pointing at a kiosks/{id}/slots/{slot} doc that a cleanup job has removed. The customer cancels, or staff reject, with releaseSlot: true. tx.update on the missing doc throws NOT_FOUND, the status change is rolled back, and the order stays pending. The same applies to the `_bookedBy(-1)` update in editPendingOrder (line 144). `booked` can also go negative if the counter was already 0."
  },
  {
    "file": "lib/data/repositories/firestore/firestore_incident_repository.dart",
    "line": 98,
    "summary": "take() and resolve() check incident.status against the caller's stale in-memory object, then do a plain update with no transaction or precondition.",
    "failure_scenario": "Staff A and staff B both have the same open incident on screen. A resolves it with a refund. B, still holding status=open, resolves it with 'rejected'. The `resolved` check passes on B's stale copy and the update overwrites A's resolution, refundVnd and handledBy. A late take() can also flip a resolved incident back to inProgress. The check needs to run on a fresh read inside a transaction."
  },
  {
    "file": "lib/ui/seller_shop/view_models/shop_view_model.dart",
    "line": 134,
    "summary": "_apply returns Result.ok(null) without writing anything when a write is already in flight or the kiosk is null. The caller then shows the 'done' message for a change that was dropped.",
    "failure_scenario": "The staff member taps 'Tạm ngưng 15 phút' while a wait-time write is still running. `_applying` is true, so `_apply` returns ok. `_run` in the screen treats it as success, shows the success message, and the pause never happens. The kiosk keeps taking orders. It should return an error or a distinct 'busy' result."
  },
  {
    "file": "lib/data/repositories/firestore/firestore_notification_repository.dart",
    "line": 55,
    "summary": "markAllRead reads every unread notification and writes them in a single WriteBatch, which Firestore caps at 500 operations. The query has no limit.",
    "failure_scenario": "A user has more than 500 unread notifications. The list view only shows 100, so the user never clears them. `batch.commit()` throws on the oversized batch, markAllRead keeps failing, and the unread badge never clears. Chunk the batch or cap the query."
  },
  {
    "file": "lib/ui/seller_shop/view_models/shift_stats_view_model.dart",
    "line": 116,
    "summary": "Every stats load and refresh opens a snapshot listener on the whole kiosks collection through watchKiosks().first, just to read one kiosk's openTime.",
    "failure_scenario": "Each pull-to-refresh reads every kiosk document, which costs one document read per kiosk per refresh. A stream error is swallowed into null, so the shift silently starts at midnight and the figures are wrong with no message. A single kiosk doc get, or the id-filtered kiosk already available from the shop/session state, would avoid this."
  },
  {
    "file": "lib/ui/seller_menu/view_models/seller_menu_view_model.dart",
    "line": 41,
    "summary": "backOptions computes the first option from earliest.minute only. With minute == 0 and non-zero seconds, the first 'back at' time falls before now + 15 minutes.",
    "failure_scenario": "Now is 10:44:40, so earliest is 10:59:40. The minute is 59, so `first` is 11:00, which is fine. At 10:45:30, earliest is 11:00:30 and minute is 0, so `first` is 11:00:00. That is 30 seconds earlier than the promised 15-minute minimum, and `earliest` is not truncated to the minute. The 'Có lại lúc' option can then be earlier than intended, and shortly afterwards it displays as 'quá giờ dự kiến'."
  },
  {
    "file": "lib/ui/order_manage/view_models/incident_view_model.dart",
    "line": 128,
    "summary": "_submit sends the report without checking that the order is delivered or that no incident already exists. Only the UI state gates it, and the description is passed untrimmed to the repository's length check.",
    "failure_scenario": "The incident stream emits after the screen shows the form, or the status changes to something other than delivered, or the user double-taps submit. `_submit` still calls incidents.report. The second set is refused by the rules and surfaces as a generic permission-denied error instead of 'already reported'. The view model could validate against the current `state` and `_incident` before calling."
  },
  {
    "file": "lib/ui/order_manage/view_models/order_history_view_model.dart",
    "line": 98,
    "summary": "_loadMore appends a page that may contain no finished orders and does not keep paging, unlike load(). hasMore stays true but the list does not grow.",
    "failure_scenario": "The next page returned by fetchMyOrders is full of orders still in progress or otherwise filtered out by _isFinished. `_loadMore` appends nothing and sets `_next` to the next cursor, so the user taps 'load more' and sees no change. The history spend and group totals also silently cover only the loaded pages. It should loop like load() until it finds finished orders or runs out of pages."
  }
]
```
