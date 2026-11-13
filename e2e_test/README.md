# e2e_test/

The ARTEMIS test suite (pytest). See `docs/test-plan.md` for the test list and rules.

## One-time setup

1. The ARTEMIS server (Python 3.12, uv), pinned to commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`:
   ```powershell
   git clone https://github.com/google/artemis.git
   cd artemis
   git checkout 351ca8422f7b5b54e80a9c1ce03a222e02415b6b
   copy .env.example .env      # fill in a model API key (GEMINI_API_KEY, ANTHROPIC_API_KEY…), never commit it
   .\start.bat                 # installs ADB, scrcpy, FFmpeg; opens http://localhost:8000
   ```
   **Local patch to the pinned ARTEMIS (needed for every test that types).** At this commit `artemis/drivers/android/adb_driver.py` `input_text` puts the text on the clipboard and sends `KEYCODE_PASTE`. Flutter text fields ignore that key, so the tool reports "Typed 'BB20'" while the field stays empty (the cause of TC-04 0/3 and of the 4–6 retries in TC-06). The patch adds a first step that sends ASCII text with `adb input text`, as `drivers/android/input_ime.py` in the same commit already does; non-ASCII text still goes through the clipboard. Apply it from the ARTEMIS folder with `git apply <repo>/e2e_test/artemis-ascii-input.patch` (12 lines, marked `LOCAL PATCH (PRM393 Lab 3)`), and restart the server.
2. Android phone: turn on **Developer options** and **USB debugging**, plug in the cable, tap "Allow" on the phone. Check with `adb devices`.
   On the **emulator** (`BB_Pixel7`, Google Play image), turn Private DNS off once, or Google sign-in fails with "Account reauth failed" / "Network error" and the app shows "Bạn đã huỷ đăng nhập": `adb shell settings put global private_dns_mode off`.
3. Install the app on the phone: `flutter run` or `flutter install` (see the root README).

## Run the tests

```powershell
cd e2e_test
uv sync
$env:ARTEMIS_DEVICE_SERIAL = "<serial number from adb devices>"
$env:ARTEMIS_PROFILE = "flash"     # "pro" only for the exploratory session
$env:ARTEMIS_TRACES_DIR = "C:/src/artemis/traces"   # the traces folder of your ARTEMIS server
$env:TEST_GOOGLE_ACCOUNT = "<the customer test account>"   # TC-01 picks it in the account chooser
adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite   # TC-03 reads the purchase event from Logcat
$env:CROSS_ROLE_CUSTOMER_UID = "<uid of the customer test account>"   # TC-30, TC-32 to 34, TC-42, TC-43 (Firebase console, Authentication)
uv run pytest -v
```

TC-42 and TC-43 (`test_cross_role.py`, the mobile steps of the cross-role flow) play the kiosk while the agent waits on
"Theo dõi đơn": they approve or reject the customer's new order through the Firestore REST API, with the token of the
Firebase CLI (`firebase login` on this machine) or `$env:CROSS_ROLE_ACCESS_TOKEN`. The kiosk must be open at the time
of the run (K10 hours). Without `CROSS_ROLE_CUSTOMER_UID` (or `CUSTOMER_UID`) these tests are skipped.

TC-30 and TC-32 to TC-34 (`test_order.py`, `test_lab2_flows.py`, the Lab 2 flows F9, F6 and F8) use the same access (`project_data.py`) to set their starting point and clean up: an empty cart, one dish sold out as K09 writes it, and for TC-34 one of the customer's orders being prepared marked ready as K04 writes it, after the app has restarted and shows Home. They also read back what the app wrote (the favorite, the cart), so a misread screen cannot pass. Each TC-34 run uses one order in "Đang làm".

The pinned ARTEMIS version returns no structured output (`result.output` is empty), so `conftest.py` reads the agent's final JSON report from `<ARTEMIS_TRACES_DIR>/<session id>/stdout.log`; without `ARTEMIS_TRACES_DIR` the tests that compare values fail. The server and the tests must be on the same machine.

Run every test ≥ 3 times with `uv run python run_repeat.py -n 3` (add `-k tc03` to pick tests); it saves a JUnit report per run and the pass-rate table in `evidence/artemis/`. It refuses to overwrite an existing `run-N.xml`; pass `--start N` with the next free number. Record the results in the table in section 3 of `docs/test-plan.md` and keep the trace (trace ID) in `evidence/artemis/`.

The prompts sent to the agent are written in Vietnamese on purpose, because the app's UI is in Vietnamese and the agent matches the text it sees on screen.

Files by feature: `test_auth.py` (TC-01, 02), `test_order.py` (TC-03 with the Analytics `purchase` check that used to be TC-13, 04, 05, 17, 30, 31), `test_browse.py` (TC-06, 07, 08), `test_profile_firebase.py` (TC-09, 10, 14, 15, 16), `test_seller_push_analytics.py` (TC-11, 12), `test_order_manage.py` (TC-18 to 24), `test_seller_menu_shop.py` (TC-25 to 29), `test_lab2_flows.py` (TC-32 to 34), `test_ai_feature.py` (TC-40, 41), `test_cross_role.py` (TC-42, 43); `project_data.py` is the shared Firestore access.

The graded suite is the 11 cases that cover section 7 of the handout (TC-01 to TC-10 and TC-12); run them with `-k "tc01 or tc02 or tc03 or tc04 or tc05 or tc06 or tc07 or tc08 or tc09 or tc10 or tc12"`. TC-01 needs the app signed out, TC-12 the staff account, the others the customer account (see `docs/test-plan.md` section 3).

Exploratory session (Pro profile): `uv run python exploratory.py --minutes 15` sends two unscripted charters, stops each after `--per-charter` minutes, and writes the issues the agent reports to `evidence/artemis/exploratory-<date>.json`.
