# BreakBite · Final assignment (PRM393)

A pre-order, pick-up-at-the-counter food system for students on Campus District 9, built with Flutter on one
Firebase project. It joins the Lab 2 design and the Lab 3 app into **one system**:

- **Mobile app** (`mobile/`, Flutter, Android): the customer app (S01–S30) and the kiosk staff app (K01–K15) of the Lab 2
  design (`PRM323-Lab2-Group2`), all on Firestore, with the announcement inbox and the AI feature.
- **Web admin** (`web/`, Flutter Web on Firebase Hosting): https://breakbite-1315b.web.app, for kiosk staff and admins.
- **Shared package** (`packages/core/`): models, Firestore repositories, services, the Lab 2 theme and widgets.
- **Backend** (`firebase/`): Firestore with role-based Security Rules and their tests, Remote Config, Hosting.

- **Topic:** BreakBite, Campus District 9 (unchanged from Lab 2 and Lab 3)
- **Team:** `[fill in names and student IDs]`
- **Firebase project:** `breakbite-1315b` (Spark, no-cost plan)
- **Demo video:** `[final assignment video: to add]` · Lab 3 video: [BreakBite_demo.mp4](https://drive.google.com/file/d/1gvb2ZAtyTcqP_V0hP5ttBreNs34HZVws/view?usp=sharing)

## Roles

| Role (`users/{uid}.role`) | Client | What they do |
|---|---|---|
| `user` (customer, the Lab 2 persona) | Mobile | Browse the menu, order and pay, follow the order (S07), inbox (S19) with order news and announcements, receipts, reviews, incidents |
| `staff` (with `kioskId`) | Mobile (seller app) and web | Mobile: take and hand over orders, manage the menu, add an item with Gemini (K14). Web: review queue (approve / reject with a reason), menu management, dashboard of their kiosk |
| `admin` | Web | Everything staff do for any kiosk (picker in the top bar), the announcement form (W05), and the system pages (users and roles, kiosks, slots, vouchers, every order, incidents, statistics, audit log). The mobile app turns an admin account away with a message pointing to the web admin |

Every new account starts as `user`. **Only an admin changes a role, and nobody changes their own** (rules: `users`
update, tests R-02, R-05). Each client turns away the wrong role with a clear message: the web admin refuses customers
(`webAdminAccessProblem`), the mobile app refuses admins (`mobileAccessProblem`).

**First admin:** Nguyễn Viết Bảo (`baonv0817`), set in the Firebase console (`users/{uid}.role = "admin"`).

### Demo accounts

Google accounts of the team, one per role (the password is given to the lecturer privately, never in the repository):

| Role | Account | Where |
|---|---|---|
| `user` | annguyen310002@gmail.com | Mobile (customer) |
| `staff`, Kiosk Q9 · Tầng 2 | annguyen310001@gmail.com | Mobile (seller app) and web |
| `admin` | annguyen382310@gmail.com | Web |

E-mail and password sign-in also works on both clients ("Tạo tài khoản"); such an account is a customer until an admin
gives it a role on the web ("Người dùng").

## Deliverables map

| Looking for | Where |
|---|---|
| Gap review of Lab 2 and Lab 3 | [`docs/gap-review.md`](docs/gap-review.md) |
| Data model (collections, fields, who may do what, status transitions) | [`docs/data-model.md`](docs/data-model.md) |
| Security Rules and their tests | [`firebase/firestore.rules`](firebase/firestore.rules), [`firebase/tests/rules.test.mjs`](firebase/tests/rules.test.mjs) |
| Cross-role flows (sequence diagrams, rules, measured times) | [`docs/cross-role-flow.md`](docs/cross-role-flow.md) |
| AI feature (Gemini fills K14 from a dish photo) | [`docs/ai-feature.md`](docs/ai-feature.md) |
| Test report (rules, web checklist, ARTEMIS, cross-role, AI code review) | [`docs/test-report.md`](docs/test-report.md) |
| Test plan and ARTEMIS runs | [`docs/test-plan.md`](docs/test-plan.md), [`e2e_test/`](e2e_test/) |
| Architecture | [`docs/architecture.md`](docs/architecture.md) |
| Design traceability and deviations | [`docs/design-traceability.md`](docs/design-traceability.md) |
| Analytics event plan (mobile and web) | [`docs/analytics-plan.md`](docs/analytics-plan.md) |
| Lab 3 AI code review | [`docs/code-review.md`](docs/code-review.md) |
| Environment setup | [`docs/setup.md`](docs/setup.md) |
| Evidence (screenshots, recordings, logs) | [`evidence/`](evidence/) |
| Final report (PDF, 10 pages), slides (PPTX and PDF, 15 slides) | [`report/Final_SE193905.pdf`](report/Final_SE193905.pdf), [`slides/Final_SE193905_slides.pptx`](slides/Final_SE193905_slides.pptx), [`slides/Final_SE193905_slides.pdf`](slides/Final_SE193905_slides.pdf); built by `scripts/build_final_report.py` and `scripts/build_final_slides.js` from the repository's evidence |

## How to run

Requirements: the versions below, an Android emulator or phone, and for the Firebase tools Node.js and Java 21.

### Mobile app

```powershell
cd mobile
flutter pub get
flutter test                                    # 819 tests, no device needed
# the real project; env/cloudinary.json is committed (cloud name and unsigned preset, not secrets),
# env/app_check.json is gitignored: copy env/app_check.example.json and put your debug token in it
flutter run --dart-define-from-file=env/cloudinary.json --dart-define-from-file=env/app_check.json
# fake data, no Firebase
flutter run -t dev/main_dev.dart --dart-define=DEV_SIGNED_IN=true --dart-define=DEV_ROLE=user
```

`env/app_check.json` holds an App Check debug token registered in the console (App Check → Apps → Manage debug
tokens). App Check is **enforced** for Firestore and Firebase AI Logic, so a build without a registered token gets
no data; the Android app has no Play Integrity registration, so use a debug build with the token.

### Web admin

```powershell
cd web
flutter pub get
flutter test                                    # no browser needed
flutter run -d chrome                           # the real project; sign in with a staff or admin account
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true   # against the local Emulator
```

Deploy to https://breakbite-1315b.web.app (the build is copied into `firebase/`, which the CLI requires):

```powershell
cd web; flutter build web --release
Remove-Item -Recurse -Force ..\firebase\web-build -ErrorAction SilentlyContinue; Copy-Item -Recurse build\web ..\firebase\web-build
cd ..\firebase; firebase deploy --only hosting --project breakbite-1315b
```

### Firebase (rules, Emulator, data)

```powershell
cd firebase
firebase emulators:start                        # Auth, Firestore and Storage Emulator (needs Java 21)
cd tests; npm install; npm test                 # Security Rules tests on the Emulator: 172 pass
firebase deploy --only firestore:rules,firestore:indexes --project breakbite-1315b
```

Seeding, roles (`firebase/seed/set-role.mjs`) and migrations: [`firebase/README.md`](firebase/README.md).

### End-to-end tests (Google ARTEMIS)

See [`e2e_test/README.md`](e2e_test/README.md): an ARTEMIS server on the same machine, the emulator serial, and
`uv run pytest -v` (or `uv run python run_repeat.py -n 3 -k <case>` for repeated runs).

## Pinned versions

| Tool | Version |
|---|---|
| Flutter (stable), Dart | 3.47.5, 3.13.4 |
| Firebase SDK (FlutterFire) | firebase_core 5.1.0, firebase_auth 7.0.1, cloud_firestore 7.1.0, firebase_messaging 17.0.1, firebase_analytics 13.0.1, firebase_crashlytics 6.0.1 (mobile), firebase_remote_config 7.0.1, firebase_ai 5.1.0 (mobile), firebase_app_check 0.5.1, google_sign_in 7.2.0 |
| Other packages | provider 6.1.5+1, go_router 18.1.1, flutter_svg 2.3.2, http 1.6.0, fl_chart 1.3.1 (web), web 1.1.2 (web) |
| Gemini model (AI feature) | `gemini-3.5-flash-lite` through Firebase AI Logic (Gemini Developer API), name set by Remote Config `ai_model` |
| Firebase CLI, FlutterFire CLI | 15.34.1, 1.4.1 |
| Node.js, Java (Emulator) | Node 26, OpenJDK 21 |
| Google ARTEMIS | commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b` (main, 2026-10-01), Flash profile |
| Python, uv | Python 3.12, uv 0.13.6 |
| Android SDK | platforms 36 and 35, build-tools 36.0.0, NDK 28.2.13676358 (see `docs/setup.md`) |
| File storage | Cloudinary (free plan, unsigned upload preset) |

## AI tools used

| Tool | Used for |
|---|---|
| Claude Code (Claude Sonnet 5.5) | Lab 3: the code of P2 (S09–S12, S20, S23, S24, K08–K11, K14, K15, PDF export), the ARTEMIS cases TC-18 to TC-29, the screenshots in `evidence/p2/` and the fixes of the Lab 3 code review |
| Claude Code (Claude Opus 5.5) | Final assignment: the AI feature (#96) and its tests; the web admin on the real project (web app, Hosting, Analytics, Remote Config, App Check, offline state, kiosk switch); the announcement inbox and the admin rejection on mobile; the cross-role runs and their measurements; ARTEMIS TC-40 to TC-43; the gap review, the test report, this README; the fixes of the final AI code review |
| Claude Code, skill `/code-review` | Lab 3 review ([`docs/code-review.md`](docs/code-review.md)) and the final review of the new code ([`evidence/code-review/final/`](evidence/code-review/final/), decisions in [`docs/test-report.md`](docs/test-report.md) section 5) |
| Google ARTEMIS with Gemini 3.5 Flash Lite | The UI test agent: [`e2e_test/`](e2e_test/), results in [`docs/test-plan.md`](docs/test-plan.md) |
| Gemini `gemini-3.5-flash-lite` through Firebase AI Logic | Inside the app: suggests the name, kind, price, time and description of a new item from its photo (K14), labelled and editable ([`docs/ai-feature.md`](docs/ai-feature.md)) |
| Claude Code, pptxgenjs | The Lab 3 slides: `scripts/build_slides.js` builds `slides/Lab03_SE193905_slides.pptx` from the repository's evidence |
| Microsoft Edge TTS (vi-VN-HoaiMyNeural) | The narration of the Lab 3 and final demo videos |
| Claude Code (Claude Opus 5.5), pptxgenjs, PyMuPDF | The final slides, report and demo video: the scripts that build them, the recording of the demo (scrcpy for the phone, the Chrome screencast for the web) and its assembly with ffmpeg. The team checked every slide and page against the repository's evidence |
| `[the other members add theirs]` | `[fill in]` |

## Deviations from the handout

| Handout requirement | What we do | Why | Approval |
|---|---|---|---|
| Cloud Storage for Firebase | Files (the PDF receipt, item and incident photos) are stored on Cloudinary through the same `StorageService` interface, with their metadata in Firestore (`reports`) | Cloud Storage now needs the Blaze plan (payment card); the team stays on the free Spark plan | The lecturer confirmed in writing that Cloudinary or S3 is acceptable |

## Security

Never commit service-account keys, API keys or keystores. Keys and test accounts go in environment variables.
`mobile/android/app/google-services.json` and the web app's `firebase_options.dart` may be committed (a Firebase web API
key only names the project; the Security Rules and App Check protect the data). The App Check debug token goes in
`mobile/env/app_check.json`, which is gitignored (`mobile/env/app_check.example.json` shows the format). The ARTEMIS
model key lives only in the ARTEMIS server's `.env`. A scan of the whole Git history on 13/11/2026 found no secret:
[`evidence/security/secret-scan-2026-11-13.md`](evidence/security/secret-scan-2026-11-13.md).
