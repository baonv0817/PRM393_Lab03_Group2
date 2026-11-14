# FtaCode menu

Source: https://ftacode.com/menu, captured 14 November 2026 in `firebase/seed/ftacode-source.json`.

The catalog contains the 20 products currently visible on the source: seven in its Tacos category and thirteen in Mi tron. The water/drinks category was empty. Product names, base prices and image URLs come from the source. One description typo (muoi/muoi with an incorrect tone) is corrected. Two products have no source photo and keep an empty image URL rather than an unrelated illustration.

Noodle topping prices match the source: egg 7,000 VND, sausage 10,000 VND, vegetables 3,000 VND and an extra noodle portion 7,000 VND. Preparation estimates (4 minutes for tacos/snacks, 5 minutes for noodles) are demo assumptions, not measured FtaCode service times. Products use the existing `food` category supported by the application. Existing kiosks, hours, slots, vouchers, users, carts and order history are preserved.

The migration creates source products with stable `ftacode-` IDs at each existing kiosk and archives old menu entries without deleting them. Historical order snapshots remain unchanged. Existing carts may contain archived products and should be emptied before recording a fresh demo. Product images are remote source URLs and require internet access. No new drinks, beef tacos or potato products are invented when they are absent from the current source.

## Rollout

Use the existing Firebase Admin credentials locally; never commit them. Run `backup.mjs` first, then dry-run `migrate.mjs --only=2026-11-t32-ftacode-menu --project=breakbite-1315b --yes`. Review the upsert/archive counts. Apply with `--apply --backup=<fresh-backup-path>`; the runner verifies the result and a second run must plan zero changes. Do not use seed `--reset` or `--overwrite` for this change.

Local validation: `node --test firebase/seed/ftacode-menu.test.mjs`. Live rollout and mobile/web visual checks must be recorded separately.
