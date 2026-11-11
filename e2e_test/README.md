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
2. Android phone: turn on **Developer options** and **USB debugging**, plug in the cable, tap "Allow" on the phone. Check with `adb devices`.
3. Install the app on the phone: `flutter run` or `flutter install` (see the root README).

## Run the tests

```powershell
cd e2e_test
uv sync
$env:ARTEMIS_DEVICE_SERIAL = "<serial number from adb devices>"
$env:ARTEMIS_PROFILE = "flash"     # "pro" only for the exploratory session
$env:ARTEMIS_TRACES_DIR = "C:/src/artemis/traces"   # the traces folder of your ARTEMIS server
uv run pytest -v
```

The pinned ARTEMIS version returns no structured output (`result.output` is empty), so `conftest.py` reads the agent's final JSON report from `<ARTEMIS_TRACES_DIR>/<session id>/stdout.log`; without `ARTEMIS_TRACES_DIR` the tests that compare values fail. The server and the tests must be on the same machine.

Run every test ≥ 3 times with `uv run python run_repeat.py -n 3` (add `-k tc03` to pick tests); it saves a JUnit report per run (it overwrites `run-1…`, so for extra runs use `uv run pytest -k "tc06" --junitxml=../evidence/artemis/run-N.xml` with a new N) and the pass-rate table in `evidence/artemis/`. Record the results in the table in section 3 of `docs/test-plan.md` and keep the trace (trace ID) in `evidence/artemis/`.

The prompts sent to the agent are written in Vietnamese on purpose, because the app's UI is in Vietnamese and the agent matches the text it sees on screen.

Files by feature: `test_auth.py` (TC-01, 02), `test_order.py` (TC-03, 04, 05, 17, 30, 31), `test_browse.py` (TC-06, 07, 08), `test_profile_firebase.py` (TC-09, 10, 14, 15, 16), `test_seller_push_analytics.py` (TC-11, 12, 13), `test_order_manage.py` (TC-18 to 24), `test_seller_menu_shop.py` (TC-25 to 29).
