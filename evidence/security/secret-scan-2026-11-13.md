# Secret scan, 13/11/2026

Final handout §9: no secrets committed. Scope: the whole Git history of every branch and tag (`git log --all -p`),
298 commits, `main` at `32cccd0`. Method: a pattern search over every added and removed line of every commit (no
dedicated tool such as gitleaks was installed on the machine; the patterns below are the ones such tools use for the
secrets this project could hold).

```bash
git log --all -p > allhist.txt
grep -ciE '<pattern>' allhist.txt
git log --all --diff-filter=A --name-only --format= | grep -iE 'service.?account|adminsdk|\.jks$|\.keystore$|key\.properties|app_check\.json$|\.env$'
```

## Result: no secret found

| Looked for | Pattern | Lines found |
|---|---|---|
| Gemini / AI Studio key (the ARTEMIS model key) | `AQ\.[A-Za-z0-9_-]{40,}` | 0 |
| Private key, service account | `BEGIN … PRIVATE KEY`, `"type": "service_account"`, `"private_key"` | 0 |
| Google OAuth client secret, OAuth access token | `GOCSPX-…`, `ya29\.…` | 0 |
| Bearer token written in code | `Bearer [A-Za-z0-9._-]{30,}` | 0 |
| Cloudinary API secret | `cloudinary://<key>:<secret>@`, `api_secret` / `client_secret` assignments | 0 |
| GitHub, AWS, Slack tokens | `gh[pousr]_…`, `AKIA…`, `xox[baprs]-…` | 0 |
| App Check debug token | a UUID next to `APP_CHECK_DEBUG_TOKEN` | 0 |
| Keystores, service-account files, `.env` files ever added | file names above | 0 (only `env/cloudinary.json`, see below) |
| Password literals | `password … = '…'` | 2, both fake accounts in tests (`breakbite1` for `linh@fpt.edu.vn` and `QUAN@fpt.edu.vn` against the fake auth service) |

## Committed on purpose (not secrets)

| What | Where | Why it may be public |
|---|---|---|
| Firebase API keys (`AIza…`, one Android, one web) | `mobile/android/app/google-services.json`, `mobile/lib/firebase_options.dart`, `web/lib/firebase_options.dart` | They only name the project; access is decided by the Security Rules and App Check (Firebase documentation, "API keys for Firebase") |
| Cloudinary cloud name and unsigned upload preset | `mobile/env/cloudinary.json` | An unsigned preset is meant to be used from a client app (`docs/setup.md` §4); the API key and API secret were never committed |
| reCAPTCHA Enterprise site key | `web/lib/config/firebase_setup.dart` | A site key is public by design; the secret side stays with Google |

## Kept out of the repository

| Secret | Where it lives | Guard |
|---|---|---|
| App Check debug token | `mobile/env/app_check.json` on the developer's machine | `.gitignore` line `mobile/env/app_check.json`; the format is in `mobile/env/app_check.example.json` |
| ARTEMIS model key | The ARTEMIS server's `.env`, outside this repository | `.gitignore` also covers `.env` and `.env.*` |
| Firebase CLI token used by `e2e_test/test_cross_role.py` | The Firebase CLI's own config in the user's home folder, read at run time | Never written to the repository; `CROSS_ROLE_ACCESS_TOKEN` is an environment variable |
| Demo account passwords | Given to the lecturer privately | README "Demo accounts" |
