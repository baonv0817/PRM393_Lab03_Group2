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

Deploy: `firebase deploy --only firestore:rules,firestore:indexes,remoteconfig` (needs the Firebase CLI and a login). Add `storage` once Storage is enabled (needs the Blaze plan).

## Rules tests (Emulator)

`firebase/tests/rules.test.mjs` has an allowed case and a denied case for every role (user, staff, admin) and every collection, plus the Storage rules (folder owner, PDF, image, ≤ 5 MB, staff by kiosk).

**Result of the run on 31/10/2026 on the Emulator: 81 tests (each with several allowed and denied assertions), 81 passed, 0 failed.** Covered: server timestamps on every write, users (no self-promotion, no email change, ≤ 5 FCM tokens), kiosks (staff edit operating fields only), slots (`increment(±1)` within capacity), menu items (category, `{kioskId}-{dishId}` id), vouchers (one discount shape, cap required), carts, orders (voucher discount recomputed, paused kiosks, server time of every step), reviews, incidents (one per order, refund ≤ total, explanation when rejected), reports, announcements, plus the fallback Storage rules. The lines `evaluation error …` printed for denied cases, and `Unexpected rules runtime error ... NullPointerException` when the Emulator shuts down, are harmless.

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
