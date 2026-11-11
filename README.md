# BreakBite · Lab 3 (PRM393)

A pre-order, pick-up-at-the-counter food app for students who study on campus, built with Flutter on Firebase. It contains a **customer app** (S01–S30) and a **seller app** (K01–K15) following the Lab 2 design (`PRM323-Lab2-Group2`).

> This is the initial repo skeleton. The "How to run", "Versions" and "Video" sections get filled in as the work is finished. The work plan is in [`TASKS.md`](TASKS.md); who does what is in [`ASSIGNMENTS.md`](ASSIGNMENTS.md); how to contribute is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

- **Topic:** BreakBite, Campus District 9
- **Team:** `[fill in names and student IDs]`
- **Data source:** Cloud Firestore (user and shop data)
- **Demo video:** [BreakBite_demo.mp4 on Google Drive](https://drive.google.com/file/d/1gvb2ZAtyTcqP_V0hP5ttBreNs34HZVws/view?usp=sharing) (8 min 47 s, Vietnamese narration by an AI voice, recorded on an Android emulator against the real Firebase project)

## Deliverables map

| Looking for | Where |
|---|---|
| Design traceability | [`docs/design-traceability.md`](docs/design-traceability.md) |
| Architecture | [`docs/architecture.md`](docs/architecture.md) |
| Data model | [`docs/data-model.md`](docs/data-model.md) |
| Analytics event plan | [`docs/analytics-plan.md`](docs/analytics-plan.md) |
| Test plan and ARTEMIS results | [`docs/test-plan.md`](docs/test-plan.md), [`e2e_test/`](e2e_test/) |
| AI code review | [`docs/code-review.md`](docs/code-review.md) |
| Security rules | [`firebase/firestore.rules`](firebase/firestore.rules) (files: Cloudinary, see [`docs/data-model.md`](docs/data-model.md) section 6) |
| Environment setup | [`docs/setup.md`](docs/setup.md) |
| Evidence | [`evidence/`](evidence/) |
| Report, slides | [`report/`](report/), [`slides/`](slides/) |

## How to run (fill in when the app exists)

```bash
flutter pub get
flutter analyze
flutter test                                              # no device needed
flutter run -t dev/main_dev.dart                          # fake data (dev/, outside lib/), while Firebase is not connected
```

Running against the real Firebase needs T01 (Firebase project) and T22 (Firebase services) to be finished; see `lib/config/firebase_dependencies.dart`.

Run the E2E tests: see `e2e_test/README.md`.

## Pinned versions (fill in)

| Tool | Version |
|---|---|
| Flutter (stable) | 3.47.5 |
| Dart | 3.13.4 |
| Firebase SDK (FlutterFire) | firebase_core 5.1.0, firebase_auth 7.0.1, cloud_firestore 7.1.0, firebase_messaging 17.0.1, firebase_analytics 13.0.1, firebase_crashlytics 6.0.1, firebase_remote_config 7.0.1, google_sign_in 7.2.0 (see `pubspec.yaml`) |
| provider, go_router, flutter_svg | 6.1.5+1, 18.1.1, 2.3.2 |
| Google ARTEMIS | commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b` (main, 2026-10-01) |
| Python, uv | Python 3.12, uv 0.13.6 |
| Android SDK | platforms 36 and 35, build-tools 36.0.0, NDK 28.2.13676358 (see `docs/setup.md`) |
| Firebase CLI, FlutterFire CLI | 15.34.1, 1.4.1 |
| File storage | Cloudinary (free plan, unsigned upload preset), http 1.6.0 |

## AI tools used

Declare every AI tool (code generation, chat, review, slides) and its purpose:

| Tool | Used for |
|---|---|
| Claude Code (Claude Sonnet 5.5) | Writing and testing the code of P2 (S09–S12, S20, S23, S24, K08–K11, K14, K15, PDF export), the ARTEMIS cases of TC-18 to TC-29, the screenshots in `evidence/p2/` and the fixes of the code review |
| Google ARTEMIS with Gemini 3.5 Flash Lite | The UI test agent: [`e2e_test/`](e2e_test/), results in [`docs/test-plan.md`](docs/test-plan.md) |
| Claude Code, pptxgenjs | The slides: `scripts/build_slides.js` builds `slides/Lab03_SE193905_slides.pptx` from the repository's own evidence |
| Microsoft Edge TTS (vi-VN-HoaiMyNeural) | The narration of the demo video |
| Claude Code, skill `/code-review` | The AI code review: output in [`evidence/code-review/`](evidence/code-review/), decisions in [`docs/code-review.md`](docs/code-review.md) |
| `[the other members add theirs]` | `[fill in]` |

## Deviations from the handout

| Handout requirement | What we do | Why | Approval |
|---|---|---|---|
| Cloud Storage for Firebase | Files are stored on Cloudinary through the same `StorageService` interface | Cloud Storage now needs the Blaze plan (payment card); the team stays on the free Spark plan | The lecturer confirmed in writing that Cloudinary or S3 is acceptable |

## Security

Never commit service-account keys, API keys or keystores. Keys and test accounts go in environment variables. `android/app/google-services.json` may be committed.
