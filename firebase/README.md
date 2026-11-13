# firebase/

| File | Role |
|---|---|
| `storage.rules` | `reports/{uid}` (PDF ≤ 5 MB), `incidents/{uid}` (incident photos), `menu/{kioskId}` (item photos, only that kiosk's staff can write) |
| `firestore.rules` | By role (user, staff, admin) and by the staff member's kiosk; the data model is in `docs/data-model.md` |
| `firestore.indexes.json` | Composite indexes for the queries in section 5 of `docs/data-model.md` |
| `remote-config-template.json` | Template used to push Remote Config (`firebase deploy --only remoteconfig`) |
| `remote-config-defaults.json` | Default values inside the app; changing one in the console changes behavior without a rebuild |

Remote Config parameters and where they are used:

| Parameter | Effect on screen |
|---|---|
| `quick_items_limit` | Number of items shown in the "Món nhanh · tối đa 5 phút" section (S02) |
| `promo_banner_enabled` | Show or hide the Golden Hour Combo banner (S02) |
| `pickup_slot_enabled` | Show or hide the pickup-time row in the cart (S05, S25) |
| `payment_gateway` | `sandbox`: MoMo and VNPAY open their sandbox gateway when the build has the keys (D41); `simulated`: the simulated gateway screen (D02), for example if the sandbox is down during a demo |

Deploy: `firebase deploy --only firestore:rules,firestore:indexes,remoteconfig` (needs the Firebase CLI and a login). Add `storage` once Storage is enabled (needs the Blaze plan).

Web admin on Hosting (https://breakbite-1315b.web.app). The Firebase CLI only serves a folder inside `firebase/`, and Flutter's shader compiler cannot write to a relative `--output` path, so build first and copy:

```powershell
cd web
flutter build web --release
Remove-Item -Recurse -Force ..\firebase\web-build -ErrorAction SilentlyContinue
Copy-Item -Recurse build\web ..\firebase\web-build
cd ..\firebase
firebase deploy --only hosting --project breakbite-1315b
```

`firebase/web-build/` is gitignored.

## Rules tests (Emulator)

`firebase/tests/rules.test.mjs` has an allowed case and a denied case for every role (user, staff, admin) and every collection, plus the Storage rules (folder owner, PDF, image, ≤ 5 MB, staff by kiosk).

**Latest run, 13/11/2026 on the Emulator: 172 tests (each with several allowed and denied assertions), 172 passed, 0 failed** (log: `evidence/rules/rules-run-2026-11-13.log`; the Appendix B matrix of 80 cases, an allowed and a denied case for each role on each collection, is listed in `docs/test-report.md` section 1). The first run, on 31/10/2026, had 81 tests. Covered: server timestamps on every write, users (no self-promotion, no email change, ≤ 5 FCM tokens), kiosks (staff edit operating fields only), slots (`increment(±1)` within capacity), menu items (category, `{kioskId}-{dishId}` id), vouchers (one discount shape, cap required), carts, orders (voucher discount recomputed, paused kiosks, server time of every step), reviews, incidents (one per order, refund ≤ total, explanation when rejected), reports, announcements (admins write, everyone signed in reads the published ones), audit logs (admins only, never edited), roles changed only by an admin, plus the fallback Storage rules. The lines `evaluation error …` printed for denied cases, and `Unexpected rules runtime error ... NullPointerException` when the Emulator shuts down, are harmless.

```bash
cd firebase/tests
npm install
npm test        # needs Java 21; the Firestore Emulator downloads about 140 MB the first time
```

**Java 21.** `firebase-tools` refuses older JDKs. Android Studio ships one, so you do not need to install another — in Git Bash: `export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"; export PATH="$JAVA_HOME/bin:$PATH"` (PowerShell: `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"; $env:Path = "$env:JAVA_HOME\bin;$env:Path"`). `npm run seed:emulator` also needs the `firebase` command: install it globally (`npm install -g firebase-tools`) or put `firebase/tests/node_modules/.bin` on `PATH`.

### The "Unable to establish loopback connection" error on Windows

If the Emulator exits with code 1 and `firestore-debug.log` or the Java log says `Unable to establish loopback connection`, Java cannot create a local socket in the default temp folder. The fix (already applied on the build machine):

```powershell
mkdir D:\tmp\java
setx JAVA_TOOL_OPTIONS "-Djava.io.tmpdir=D:/tmp/java -Djdk.net.unixdomain.tmpdir=D:/tmp/java"
```

Reopen the terminal and run again. This variable is also needed for `sdkmanager` and Gradle on a machine with the same problem.

## Sample data and roles (`firebase/seed/`)

Install once: `cd firebase/seed && npm install`.

| Task | Command |
|---|---|
| Try it on the Emulator (starts it, loads, verifies, shuts down) | `npm run seed:emulator` |
| Load into the real project | `node seed.mjs --project=breakbite-1315b --yes` |
| Clean reload (deletes kiosks and slots, menu_items, vouchers, then loads again; does not touch users or orders) | `node seed.mjs --project=breakbite-1315b --yes --reset` |
| Assign a role | `node set-role.mjs <email> <user\|staff\|admin> [kioskId] --project=breakbite-1315b --yes` |

The scripts use the Admin SDK (which bypasses the Security Rules), so the real project needs a **service-account key**: console, Project settings, Service accounts, Generate new private key. Save the file **outside the repo** (for example `D:\secrets\breakbite-admin.json`; `.gitignore` already blocks `*firebase-adminsdk*.json`), then in PowerShell:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "D:\secrets\breakbite-admin.json"
cd firebase\seed
node seed.mjs --project=breakbite-1315b --yes
node set-role.mjs staff-email@gmail.com staff q9-t2 --project=breakbite-1315b --yes
```

Never send the key file's contents to anyone, including in chat. `set-role.mjs` can only assign a role to an account that has signed in to the app at least once.

## Data migrations (`firebase/seed/`)

When the structure changes, existing documents in the real project are moved to the new structure by a script, not by hand in the console. The scripts:

| Script | Does | Writes? |
|---|---|---|
| `backup.mjs` | Saves every document (subcollections included) to one JSON file, by default `~/breakbite-backups/<project>-<time>.json`. On Spark this replaces `gcloud firestore export`, which needs a Cloud Storage bucket (Blaze) | No |
| `migrate.mjs` | Runs, in order, every migration in `migrations/index.mjs` that the project has not applied yet (each one leaves a `_migrations/<id>` document). `--status` lists them as applied or pending; `--only=<id>` runs one. **A dry run by default**: prints each planned change and warning. `--apply` writes, then verifies the result and checks that a second run would change nothing. On a real project `--apply` refuses to run without `--backup=<file>` of the same project taken in the last 24 hours | Only with `--apply` |
| `restore.mjs` | Rollback: writes a backup back exactly as it was. `--prune` also deletes documents that are not in the backup (the ones a migration moved to a new id) | Yes |

`npm run test:migrate` loads documents in the **old** structure into the Emulator and checks: a dry run writes nothing; `--apply` gives the new structure (every check in `verify()` passes); a second run plans 0 changes; `restore --prune` brings back exactly the old data. It also checks that every registered migration has a unique, dated id and `plan`, `apply`, `verify`, and runs `migrate.mjs` itself (`--status`, dry run, `--apply`, "Up to date"). Result on 01/11/2026: 8 tests, 8 passed. On data already in the new structure (`seed.mjs` then `migrate.mjs`) it plans 0 changes.

### What the T31 migration changes

| Collection | Old | New |
|---|---|---|
| every document | `createdAt`/`updatedAt` often missing | Both present; when missing, taken from the document's own create and update time in Firestore |
| `menu_items` | No `dishId`; `category` is a label (`Tacos`, `Đồ uống`, …) | `dishId` = the id without `{kioskId}-`; `category` `food`/`drink`/`other` (`Đồ uống` → `drink`; `Tacos`, `Mì trộn`, `Cơm`, `Bánh mì`, `Ăn vặt` → `food`; anything else → `other`) |
| `vouchers` | `discountVnd`, `percent`, `maxDiscountVnd` side by side | `discount: {type: 'fixed', amountVnd}` or `{type: 'percent', percent, maxVnd}`; the old fields are removed |
| `users/{uid}/favorites` | Id = menu item id; `itemId`, `kioskId`, `addedAt` | Id = `dishId`; `addedAt` → `createdAt`; the same dish saved at two kiosks becomes one favorite |
| `reviews` | No `dishId` | `dishId` from the item |
| `incidents` | Random id; `wrong_item`, `missing_item`, `in_progress`; free-text `resolution` | Id = `orderId`; camelCase values; free text moves to `resolutionNote` (with a warning, so someone sets `refunded`/`rejected`) |

A second incident on the same order, or a voucher with no usable amount, is **not** changed: the script prints a warning and a person decides.

### Adding a migration

Required whenever stored data has to change (`CONTRIBUTING.md` section 3.1). Copy the shape of `migrations/t31-data-model.mjs`:

1. Create `migrations/<yyyy-mm>-<task>-<name>.mjs` exporting `MIGRATION_ID` (the same name, ids sort by date), `plan(db, admin)` returning `{ ops, warnings, counts }` without writing, `apply(db, admin, plan)` that writes the ops and the `_migrations/<MIGRATION_ID>` document, and `verify(db, admin)` returning the list of documents that still break the new rules.
2. `plan` must be idempotent: a document already in the new shape gives no op, so a second run plans 0 changes. Anything a person must decide becomes a warning, not a guess.
3. Add it at the **end** of the list in `migrations/index.mjs`; never reorder or edit a migration that has already been rolled out, write a new one instead.
4. In `migrate.test.mjs`, load documents in the old shape into the Emulator and check: the dry run writes nothing, `apply` passes `verify`, a second run plans nothing, `restore --prune` brings the old data back.
5. `npm run test:migrate` (needs Java 21 and the Firebase CLI on `PATH`, for example `firebase/tests/node_modules/.bin`). The **Firebase checks** workflow runs the same tests on the PR.

After the merge the key holder runs the rollout below and posts the output of `node migrate.mjs --status` in the PR.

### Rolling it out to the real project

The project owner runs this, with the service-account key from the previous section. Do it when nobody is testing on the real project (about 15 minutes).

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "D:\secrets\breakbite-admin.json"
cd firebase\seed
npm install

# 1. Backup (read only). Note the file path it prints.
node backup.mjs --project=breakbite-1315b --yes

# 2. Pending migrations, then a dry run: read every change and WARNING line.
node migrate.mjs --project=breakbite-1315b --yes --status
# Stop here if something looks wrong.
node migrate.mjs --project=breakbite-1315b --yes

# 3. Indexes first: new indexes only add capability. If it asks to delete the old reviews(itemId, createdAt) index, answer yes.
cd ..\..
firebase deploy --only firestore:indexes --project breakbite-1315b

# 4. Data, while the old rules are still deployed (the old rules accept the new shape; the new rules reject the old one).
cd firebase\seed
node migrate.mjs --project=breakbite-1315b --yes --apply --backup=<file from step 1>
#    Must end with "Verify: 0 problems ... would change 0 documents".

# 5. Refresh the sample catalog (GIOVANG 10:15–10:30, pickup slots for the next 7 days).
node seed.mjs --project=breakbite-1315b --yes --overwrite

# 6. Rules last.
cd ..\..
firebase deploy --only firestore:rules --project breakbite-1315b
```

7. Smoke test on a phone with the real build: sign in, Home shows the menu with categories, apply `BBSTUDENT` to a 40K cart, a staff account marks an item sold out, the Firestore console shows `_migrations/2026-11-t31-data-model`.

Rolled out to `breakbite-1315b` on 01/11/2026: backup of 111 documents, 111 changes with 0 warnings, "Verify: 0 problems. A second run would change 0 documents.", catalog re-seeded (slots until 06/11), all 14 indexes ready before the new rules were released. Step 7 is still to do on a phone.

Wait for the index build in step 3 (console, Firestore, Indexes: every index **Enabled**) before step 6; a query whose index is still building fails with `failed-precondition`.

**Rollback** (if step 4, 6 or 7 goes wrong): deploy the previous rules, then restore the backup.

```powershell
git checkout 477d630 -- firebase/firestore.rules
firebase deploy --only firestore:rules --project breakbite-1315b
git checkout HEAD -- firebase/firestore.rules
cd firebase\seed
node restore.mjs --from=<file from step 1> --project=breakbite-1315b --yes --prune
```

The backup file contains personal data (names, emails, orders): keep it outside the repo and delete it once the new structure has run for a week.

After the merge everyone rebases their branch on `main`: `MenuItem.category` is now the `ItemCategory` enum and `Voucher` has `discount` instead of `discountVnd`/`percent`.
