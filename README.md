# BreakBite · Lab 3 (PRM393)

App đặt món trước, nhận tại quầy cho sinh viên học trên campus, xây bằng Flutter trên Firebase. Gồm **app khách** (S01–S30) và **app người bán** (K01–K15) theo thiết kế Lab 2 (`PRM323-Lab2-Group2`).

> Đây là khung repo ban đầu. Mục "Cách chạy", "Phiên bản", "Video" được điền khi làm xong. Kế hoạch việc nằm ở [`TASKS.md`](TASKS.md).

- **Chủ đề:** BreakBite, campus Quận 9
- **Nhóm:** `[điền tên, MSSV các thành viên]`
- **Nguồn dữ liệu:** Cloud Firestore (dữ liệu của người dùng và quán)
- **Video demo:** `[điền link]`

## Bản đồ sản phẩm nộp

| Cần tìm | Ở đâu |
|---|---|
| Truy vết thiết kế | [`docs/design-traceability.md`](docs/design-traceability.md) |
| Kiến trúc | [`docs/architecture.md`](docs/architecture.md) |
| Kế hoạch sự kiện analytics | [`docs/analytics-plan.md`](docs/analytics-plan.md) |
| Kế hoạch test và kết quả ARTEMIS | [`docs/test-plan.md`](docs/test-plan.md), [`e2e_test/`](e2e_test/) |
| AI code review | [`docs/code-review.md`](docs/code-review.md) |
| Quy tắc bảo mật | [`firebase/storage.rules`](firebase/storage.rules), [`firebase/firestore.rules`](firebase/firestore.rules) |
| Bằng chứng | [`evidence/`](evidence/) |
| Báo cáo, slide | [`report/`](report/), [`slides/`](slides/) |

## Cách chạy (điền khi có app)

```bash
flutter pub get
flutter run
```

Chạy test E2E: xem `e2e_test/README.md`.

## Phiên bản đã ghim (điền)

| Công cụ | Phiên bản |
|---|---|
| Flutter (stable) | `[điền]` |
| Dart | `[điền]` |
| Firebase SDK (FlutterFire) | `[điền trong pubspec.yaml]` |
| Google ARTEMIS | `[commit đã ghim]` |
| Python, uv | `[điền]` |

## Công cụ AI đã dùng

Khai báo mọi công cụ AI (sinh code, chat, review, làm slide) và mục đích:

| Công cụ | Dùng để |
|---|---|
| `[điền]` | `[điền]` |

## Bảo mật

Không commit khoá service-account, API key, keystore. Khoá và tài khoản test đặt trong biến môi trường. `android/app/google-services.json` được phép commit.
