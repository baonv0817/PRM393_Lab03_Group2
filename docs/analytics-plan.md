# Analytics event plan

Write this **before** writing the tracking code. At least 7 events that together cover: sign-in, sign-out, the primary action (search, ordering), opening a detail screen, and exporting and uploading a file. Use Firebase's recommended names where one exists (`login`, `search`, `add_to_cart`, `begin_checkout`, `purchase`), `snake_case` otherwise. Parameters must not contain personal data (no email, no name).

Lab 2 success goal: finish an order in under 35 seconds with at most 8 taps.

| Event | When | Parameters (type) | Product question | Lab 2 flow step |
|---|---|---|---|---|
| `login` | Successful sign-in | `method` (string) | How many people come back each week? | S26 |
| `logout` | Sign-out | `session_minutes` (int) | How long does a session last? | S15 |
| `search` | A search runs | `search_term` (string), `result_count` (int) | What do people search for, and which terms return nothing? | S28 |
| `view_menu_item` | Item detail opens | `item_id` (string), `item_name` (string), `category` (string) | Which items are viewed a lot but rarely added? | S04 |
| `add_to_cart` | Item added to the cart | `item_id` (string), `quantity` (int), `source` (string: home, menu, detail) | Where is adding fastest from? | S02, S03, S04 |
| `begin_checkout` | Enter the checkout screen | `value_vnd` (int), `item_count` (int) | How many carts reach checkout? | S05 → S06 |
| `purchase` | Order placed successfully | `transaction_id` (string), `value_vnd` (int), `payment_method` (string), `taps_from_home` (int) | Is the goal of ≤ 8 taps and < 35 seconds met? | S06-GATEWAY → S07 |
| `payment_failed` | Payment declined or network lost | `payment_method` (string), `reason` (string) | Which method fails most, and how many switch to cash? | S06-ERR |
| `export_report` | A file is generated and uploaded | `file_size_kb` (int), `source` (string: firebase_demo, order_detail), `order_id` (string, only for a single-order receipt) | Which orders get a receipt exported? | Demo area, S12 |
| `order_accepted` | Seller accepts an order | `order_id` (string), `wait_seconds` (int) | How fast does the counter accept orders? | K03 |
| `order_delivered` | Seller hands over the order | `order_id` (string), `paid_cash` (bool) | How many orders are paid in cash? | K06 |

User property: `setUserId(uid)` after sign-in; never put an email or name in a user property.

## Evidence

Every event needs a DebugView screenshot (Analytics debug mode on) saved in `evidence/analytics/`. Write the file name in the table when you have it.

| Event | DebugView screenshot |
|---|---|
| | |
