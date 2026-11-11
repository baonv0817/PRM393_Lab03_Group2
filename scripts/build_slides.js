// Builds slides/Lab03_SE193905_slides.pptx (15 slides) from the repo's own evidence.
//
// Run from the repo root:
//   NODE_PATH=<folder with node_modules/pptxgenjs> node scripts/build_slides.js
// The theme is written into the file by apply_theme.js of the Claude pptx skill when it is available (SKILL_DIR);
// without it the file still opens, with Office's stock scheme colours.
//
// Layout rules used: one message per slide, the title is the conclusion, the evidence (screenshot, table, diagram)
// carries the slide, 16:9, two fonts (Cambria for titles, Calibri for text), one dominant brand colour.
const path = require('path');
const fs = require('fs');
const pptxgen = require('pptxgenjs');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'slides', 'Lab03_SE193905_slides.pptx');
const SKILL_DIR = process.env.SKILL_DIR || '';
const img = (...p) => path.join(ROOT, 'evidence', ...p);

const THEME = {
  name: 'BreakBite',
  headFontFace: 'Cambria',
  bodyFontFace: 'Calibri',
  colors: {
    dk1: '2B1810', lt1: 'FFFFFF', dk2: '622B14', lt2: 'FAF8F5',
    accent1: 'F69D39', accent2: 'B45309', accent3: '15803D', accent4: 'B91C1C', accent5: '6B5F55', accent6: 'E4DFD8',
    hlink: 'B45309', folHlink: '6B5F55',
  },
};

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.33 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = 'BreakBite - PRM393 Lab 3';
pres.author = 'Team BreakBite';
pres.company = 'PRM393';
const C = pres.SchemeColor;

const W = 13.33;
const MX = 0.6; // side margin
const CW = W - 2 * MX; // content width

pres.defineSlideMaster({
  title: 'CONTENT',
  background: { color: C.background1 },
  objects: [
    { text: { text: 'BreakBite · PRM393 Lab 3', options: { x: MX, y: 7.0, w: 6, h: 0.3, fontSize: 10, color: C.accent5, margin: 0 } } },
  ],
  slideNumber: { x: W - MX - 0.6, y: 7.0, w: 0.6, h: 0.3, fontSize: 10, color: C.accent5, align: 'right' },
  placeholders: [
    { placeholder: { options: { name: 'title', type: 'title', x: MX, y: 0.35, w: CW, h: 1.15, fontSize: 30, bold: true, color: C.text2, valign: 'top', margin: 0 }, text: '' } },
  ],
});
pres.defineSlideMaster({
  title: 'DARK',
  background: { color: C.text2 },
  objects: [],
  placeholders: [
    { placeholder: { options: { name: 'title', type: 'title', x: MX, y: 0.35, w: CW, h: 1.15, fontSize: 30, bold: true, color: C.background1, valign: 'top', margin: 0 }, text: '' } },
  ],
});

const TITLE = { placeholder: 'title', x: MX, y: 0.35, w: CW, h: 1.15, fontSize: 30, bold: true, fontFace: 'Cambria', color: C.text2, valign: 'top', margin: 0 };
function content(title, notes) {
  const s = pres.addSlide({ masterName: 'CONTENT' });
  s.addText(title, TITLE);
  if (notes) s.addNotes(notes);
  return s;
}

// -- small building blocks -------------------------------------------------------------------------------------
function text(s, str, o) {
  s.addText(str, Object.assign({ isTextBox: true, fontSize: 16, color: C.text1, margin: 0, valign: 'top' }, o));
}
function bullets(s, items, o) {
  const runs = items.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 8 } }));
  s.addText(runs, Object.assign({ isTextBox: true, fontSize: 16, color: C.text1, margin: 0, valign: 'top' }, o));
}
function picture(s, file, x, y, w, h, name) {
  s.addImage({ path: file, x, y, w, h, sizing: { type: 'contain', w, h }, objectName: name });
}
function caption(s, str, x, y, w) {
  text(s, str, { x, y, w, h: 0.5, fontSize: 12, color: C.accent5 });
}
function box(s, label, x, y, w, h, o) {
  s.addText(label, Object.assign({
    shape: pres.ShapeType.roundRect, rectRadius: 0.08, x, y, w, h, fontSize: 15, bold: true, align: 'center', valign: 'middle',
    color: C.text2, fill: { color: C.background2 }, line: { color: C.accent6, width: 1 }, margin: 0.08,
  }, o));
}
function arrow(s, x, y, w) {
  s.addShape(pres.ShapeType.rightArrow, { x, y, w, h: 0.28, fill: { color: C.accent2 }, line: { color: C.accent2, width: 0 } });
}
// A row of boxes joined by arrows. Returns the y of the bottom edge.
function flow(s, labels, x, y, w, h, o) {
  const gap = 0.45;
  const bw = (w - gap * (labels.length - 1)) / labels.length;
  labels.forEach((l, i) => {
    const bx = x + i * (bw + gap);
    box(s, l, bx, y, bw, h, o);
    if (i < labels.length - 1) arrow(s, bx + bw + 0.06, y + h / 2 - 0.14, gap - 0.12);
  });
  return y + h;
}
function stat(s, big, label, x, y, w, color) {
  s.addText(big, { isTextBox: true, x, y, w, h: 1.1, fontSize: 54, bold: true, fontFace: 'Cambria', color: color || C.accent2, margin: 0, valign: 'middle' });
  text(s, label, { x, y: y + 1.1, w, h: 0.7, fontSize: 16, color: C.text1 });
}
function failure(s, str, y) {
  s.addText([
    { text: 'If it fails  ', options: { bold: true, color: C.accent4 } },
    { text: str, options: { color: C.text1 } },
  ], {
    isTextBox: true, shape: pres.ShapeType.roundRect, rectRadius: 0.06, x: MX, y, w: CW, h: 0.7, fontSize: 15,
    fill: { color: C.background2 }, line: { color: C.accent6, width: 1 }, margin: [0.08, 0.2, 0.08, 0.2], valign: 'middle',
  });
}
const hdr = (t) => ({ text: t, options: { bold: true, color: C.background1, fill: { color: C.text2 }, fontSize: 13, valign: 'middle' } });
const cell = (t, o) => ({ text: t, options: Object.assign({ fontSize: 12.5, color: C.text1, valign: 'middle' }, o) });

// -- 1. title ---------------------------------------------------------------------------------------------------
{
  const s = pres.addSlide({ masterName: 'DARK' });
  s.addImage({ path: path.join(ROOT, 'assets', 'brand', 'breakbite_logo.png'), x: MX, y: 0.9, w: 1.5, h: 1.5, objectName: 'logo' });
  s.addText('BreakBite', { isTextBox: true, x: MX, y: 2.7, w: 9, h: 1.2, fontSize: 66, bold: true, fontFace: 'Cambria', color: C.background1, margin: 0 });
  text(s, 'Pre-order food in the break between two classes, collect it at the counter.', { x: MX, y: 4.0, w: 9.5, h: 0.9, fontSize: 26, color: C.accent1 });
  text(s, 'PRM393 · Lab 3 · Cloud-enabled mobile app: Firebase, ARTEMIS tests, AI code review', { x: MX, y: 5.35, w: 11, h: 0.4, fontSize: 18, color: C.background1 });
  text(s, 'Team BreakBite · Campus District 9 · Flutter + Firebase + Cloudinary', { x: MX, y: 5.8, w: 11, h: 0.4, fontSize: 18, color: C.background1 });
  text(s, 'github.com/baonv0817/PRM393_Lab03_Group2', { x: MX, y: 6.7, w: 8, h: 0.3, fontSize: 12, color: C.accent6 });
  s.addNotes('Topic: a pre-order app for students with a short break. Customer app and seller app are one Flutter project; the account role picks the app. Backend: Firebase on the free Spark plan plus Cloudinary for files.');
}

// -- 2. persona + success criterion ---------------------------------------------------------------------------
{
  const s = content('A student with a short break can order in under 35 seconds and 8 taps',
    'Persona and Lab 2 success criterion. The purchase analytics event measures the 35 seconds and 8 taps. 44 of 44 screens are built: 30 customer screens (S01-S30) and 15 seller screens (K01-K15), K07 is not in Figma.');
  text(s, 'Persona: a student who studies on Campus District 9 and has about 15 minutes between two classes.', { x: MX, y: 1.6, w: CW, h: 0.7, fontSize: 20 });
  stat(s, '35 s', 'to finish an order (Lab 2 success criterion)', MX, 2.7, 3.6);
  stat(s, '8 taps', 'at most, from Home to a placed order', MX + 4.2, 2.7, 3.6);
  stat(s, '44 / 44', 'screens built, customer app S01–S30 and seller app K01–K15', MX + 8.4, 2.7, 3.7);
  flow(s, ['F1  Quick order', 'F2  Voucher, with errors', 'F3  Payment error, then cash'], MX, 5.2, CW, 0.9);
  caption(s, 'The purchase event of the analytics plan (docs/analytics-plan.md) measures the criterion.', MX, 6.3, CW);
}

// -- 3. Figma vs app ---------------------------------------------------------------------------------------------
{
  const s = content('The app follows the Figma design, and every difference has a written reason',
    'Left of each pair is Figma v2, right is the app. 33 deviations D01-D33 are in docs/design-traceability.md section 5, each with a reason.');
  const pairs = ['p1-S02.png', 'p1-S05-VOUCHER-ERR.png', 'p2-K10.png'];
  pairs.forEach((f, i) => picture(s, img('figma', f), 0.8 + i * 4.04, 1.5, 3.64, 4.1, 'figma-pair-' + (i + 1)));
  caption(s, 'Home (S02) · cart with a voucher error (S05) · shop settings of the seller (K10). In each pair Figma is on the left and the app on the right.', MX, 5.65, CW);
  bullets(s, [
    'D01: Google Sign-In replaces e-mail + OTP (handout requirement).',
    'D12: add-to-cart stepper and floating cart button replace the + icon and cart icon.',
    'D23: no photo box on menu items, because files go to Cloudinary, not Cloud Storage.',
  ], { x: MX, y: 6.0, w: CW, h: 0.95, fontSize: 13 });
}

// -- 4. architecture ------------------------------------------------------------------------------------------------
{
  const s = content('Screens never touch an SDK: three layers, enforced by a test',
    'MVVM with Provider and go_router. Dependencies only point down. test/architecture_test.dart fails if a screen imports an SDK, holds a colour or text-style literal, or a ViewModel lacks SafeChangeNotifier. Fake data lives in dev/, outside lib/.');
  flow(s, ['Screen\nui/*/widgets\ndraws ViewState', 'ViewModel\nui/*/view_models\nstate, validation, Command', 'Repository / Service\ndata/\nwraps one SDK'], MX, 1.7, 8.2, 1.7, { fontSize: 14 });
  box(s, 'Model  domain/models  ·  immutable data and pure rules', MX, 3.7, 8.2, 0.8, { fontSize: 14 });
  box(s, 'Firebase Auth · Firestore · FCM · Analytics · Crashlytics · Remote Config · Cloudinary', MX, 4.8, 8.2, 0.8, { fontSize: 14, color: C.background1, fill: { color: C.text2 } });
  stat(s, '752', 'widget and ViewModel tests, no device needed', 9.6, 1.6, 3.2);
  stat(s, '88', 'Firestore rules tests', 9.6, 3.6, 3.2);
  text(s, 'Fakes in dev/ replace Firebase for tests, so the submitted build holds no mock data.', { x: MX, y: 5.95, w: 8.2, h: 0.8, fontSize: 16 });
}

// -- 5. design system ------------------------------------------------------------------------------------------------
{
  const s = content('One set of design tokens drives every screen',
    'Tokens in lib/ui/core/theme: app_colors (Figma v2 colours, WCAG contrast tests), app_dimens (48 dp tap target), app_theme. Components are one widget each in lib/ui/core/widgets. The widget catalog dev/widget_catalog.dart is tested at 360 and 412 dp with text 1.0 and 1.3.');
  flow(s, ['Tokens\ncolors, spacing,\nradius', 'Theme\nMaterial theme\nbuilt from tokens', 'Components\nAppButton, AppChip,\nQuantityStepper, state views', 'Screens'], MX, 1.8, 8.6, 1.6, { fontSize: 14 });
  bullets(s, [
    'Screens hold no colour or text-style literal; the architecture test fails if one appears.',
    'Widget catalog tested at 360 and 412 dp, text 1.0 and 1.3: no overflow, every tap target at least 48 dp.',
    'Loading, empty and error states are shared widgets, not copies.',
  ], { x: MX, y: 3.9, w: 8.6, h: 2.6, fontSize: 17 });
  picture(s, img('auth', '2-signed-in.png'), 9.9, 1.6, 2.8, 5.1, 'home-screen');
}

// -- Firebase service slides: how it works (left), evidence (right), failure strip (bottom) ---------------------------
// 6. Auth
{
  const s = content('Google verifies the user, Firebase issues the session',
    'GoogleSignIn returns a Google ID token; GoogleAuthProvider.credential then FirebaseAuth.signInWithCredential gives a Firebase ID token (JWT, about 1 hour) and a refresh token. SHA-1 of each build machine must be registered or Google returns no token.');
  flow(s, ['Google account picker', 'Google ID token', 'Firebase ID token + refresh token'], MX, 1.6, 7.6, 1.0, { fontSize: 14 });
  bullets(s, [
    'The app holds no password; the SDK keeps the tokens and refreshes them.',
    'SHA-1 of every build machine is registered in the project.',
    'The role in users/{uid} routes to the customer or the seller app.',
    'Firestore rules read request.auth.uid from the token.',
  ], { x: MX, y: 3.0, w: 7.6, h: 3.0, fontSize: 17 });
  picture(s, img('auth', '2-signed-in.png'), 8.7, 1.6, 1.9, 4.2, 'auth-signed-in');
  picture(s, img('auth', '3-cancelled.png'), 10.8, 1.6, 1.9, 4.2, 'auth-cancelled');
  caption(s, 'Signed in · cancelled picker', 8.7, 5.85, 4);
  failure(s, 'Cancelled sign-in, no network and no token each show their own message; the router waits on a splash screen until the sign-in state is known.', 6.25);
}
// 7. Firestore
{
  const s = content('The server decides who reads and writes, and 88 tests prove it',
    'Rules run on the Firebase server, deny by default, access by role, staff only at their own kiosk. Orders are placed, edited and cancelled in transactions. 16 composite indexes in firebase/firestore.indexes.json: the seller shift screen failed on the real project until they were added.');
  stat(s, '88', 'rules tests plus an integration test against the real rules', MX, 1.6, 3.6);
  stat(s, '16', 'composite indexes; missing ones only fail on the real Firestore', MX, 3.7, 3.6);
  bullets(s, [
    'Deny by default; customers reach only their own data; staff only their own kiosk.',
    'Place, edit and cancel an order in one transaction.',
    'Screens listen with snapshots(), so a sold-out item shows at once.',
  ], { x: 4.4, y: 1.7, w: 3.6, h: 4.0, fontSize: 16 });
  picture(s, img('storage', '5-firestore-reports.png'), 8.2, 1.6, 4.55, 2.9, 'firestore-console');
  caption(s, 'Firestore console: a document in reports with uid, url and size.', 8.2, 4.55, 4.55);
  failure(s, 'A write that depends on current data runs in a transaction, so the user reads “Đơn này vừa được xử lý ở nơi khác”, not a rules error.', 6.15);
}
// 8. Cloudinary
{
  const s = content('Files go to Cloudinary because Cloud Storage needs a paid plan',
    'Cloud Storage for Firebase needs the Blaze plan (payment card). The same StorageService interface sends the PDF to Cloudinary with an unsigned upload preset, so the app holds no secret. The lecturer confirmed in writing that Cloudinary or S3 is acceptable.');
  flow(s, ['App builds PDF', 'Upload with unsigned preset', 'Cloudinary returns a URL', 'URL saved in Firestore reports'], MX, 1.6, CW, 1.0, { fontSize: 14 });
  bullets(s, [
    'No API secret in the app; limits live in the preset.',
    'Owner-only read rules on the reports collection.',
    'StorageService interface: S3 would replace Cloudinary without touching screens.',
  ], { x: MX, y: 2.95, w: 4.3, h: 3.0, fontSize: 16 });
  picture(s, img('storage', '2-url.png'), 5.2, 2.85, 2.4, 3.05, 'upload-done');
  picture(s, img('storage', '4-cloudinary-library.png'), 7.8, 2.85, 4.95, 3.05, 'cloudinary-library');
  caption(s, 'Upload finished · the PDF in the Cloudinary library', 5.2, 5.95, 7);
  failure(s, 'Not configured, larger than 5 MB, no network and timeout each have a message, and the retry button stays.', 6.3);
}
// 9. FCM
{
  const s = content('Push notifications arrive in all three app states and open the right order',
    'The token identifies one app install on one device, issued by FCM through Google Play Services. The app saves it in users/{uid}.fcmTokens (up to 5 devices). The message here was sent from Firebase Console, Messaging, Send test message. Bug found by this test: from a closed app the tap opened the order and Home replaced it when the splash redirected; PushRouter now waits until the app is ready (lib/app.dart).');
  picture(s, img('fcm', '2-foreground.png'), MX, 1.6, 1.85, 4.15, 'fcm-foreground');
  picture(s, img('fcm', '3-background.png'), MX + 2.05, 1.6, 1.85, 4.15, 'fcm-background');
  picture(s, img('fcm', '4-terminated-tap-before-fix.png'), MX + 4.1, 1.6, 1.85, 4.15, 'fcm-before');
  picture(s, img('fcm', '4-terminated-tap-after-fix.png'), MX + 6.15, 1.6, 1.85, 4.15, 'fcm-after');
  caption(s, 'App open · background · closed, tap before the fix (ends on Home) · after the fix (opens the order)', MX, 5.8, 8.0);
  bullets(s, [
    'The FCM token identifies one install; the app stores it in users/{uid}.fcmTokens, up to 5 devices.',
    'Sent from Firebase Console (Send test message) or an Admin SDK script.',
    'Android 13+ asks for permission; a refusal never blocks the app.',
    'Every message is saved to the in-app list (S19).',
  ], { x: 9.0, y: 1.6, w: 3.75, h: 4.6, fontSize: 15 });
  failure(s, 'A refused permission or a failed token write never blocks sign-in or sign-out.', 6.25);
}
// 10. Analytics
{
  const s = content('11 planned events reach DebugView with their parameters',
    'docs/analytics-plan.md was written before the code. Each event answers a product question; purchase tests the 35 s and 8 tap criterion. setUserId is called after sign-in; parameters hold no name or e-mail. DebugView is enabled with adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite.');
  picture(s, path.join(ROOT, 'slides', 'img', 'debugview-top-events.png'), MX, 1.6, 8.5, 4.25, 'debugview');
  caption(s, 'DebugView with debug mode on: the events of the plan and their counts.', MX, 5.95, 8.5);
  bullets(s, [
    'Sign-in: login, logout',
    'Find: search, view_menu_item',
    'Order: add_to_cart, reorder, begin_checkout, purchase, payment_failed',
    'Seller: order_accepted, order_delivered',
    'Files: export_report',
    'purchase measures the success criterion. No personal data in parameters.',
  ], { x: 9.4, y: 1.7, w: 3.35, h: 4.8, fontSize: 15 });
}
// 11. Crashlytics + Remote Config
{
  const s = content('Crashlytics records errors, and Remote Config changes the app without a rebuild',
    'Crashlytics: uncaught errors plus handled errors recorded as non-fatal, with the keys role and kiosk_id. A crash is sent on the next app start. Remote Config: quick_items_limit was changed from 5 to 2 and published; Home showed 2 items without a restart because the app listens to onConfigUpdated.');
  text(s, 'Crashlytics', { x: MX, y: 1.6, w: 5.8, h: 0.4, fontSize: 20, bold: true, color: C.text2 });
  picture(s, img('crashlytics', '1-non-fatal.png'), MX, 2.1, 5.8, 3.1, 'crashlytics-nonfatal');
  bullets(s, ['Uncaught and handled errors, keys role and kiosk_id.', 'A crash is sent on the next app start.'], { x: MX, y: 5.4, w: 5.8, h: 1.2, fontSize: 14 });
  text(s, 'Remote Config', { x: 6.9, y: 1.6, w: 5.8, h: 0.4, fontSize: 20, bold: true, color: C.text2 });
  picture(s, img('remote-config', '2-console.png'), 6.9, 2.1, 3.7, 3.1, 'rc-console');
  picture(s, img('remote-config', '3-after.png'), 10.8, 2.1, 1.9, 3.1, 'rc-after');
  bullets(s, ['quick_items_limit 5 → 2: Home shows 2 items at once.', 'Offline: last values, or the defaults in the app.'], { x: 6.9, y: 5.4, w: 5.8, h: 1.2, fontSize: 14 });
}
// 12. ARTEMIS
{
  const s = content('ARTEMIS ran 10 cases at least 3 times each; 4 pass every run',
    'ARTEMIS flash profile with Gemini 3.5 Flash Lite on an Android emulator against the real Firebase project; 10 of 31 cases run, 21 not run (free model quota; most need two devices, the staff role, airplane mode or the notification shade). Failures: the agent counted 4 of 5 items in a list that needs scrolling, tapped a stepper once, did not type into a field, and missed short-lived snackbars; repeated by hand, the app behaved correctly where checked (screenshots in evidence/artemis/manual).');
  const rows = [
    [hdr('Case'), hdr('Runs'), hdr('Pass'), hdr('Why it failed, or note')],
    ['TC-06 search, no result', '3', '3/3', 'Stable'],
    ['TC-07 main tabs', '3', '3/3', 'Stable'],
    ['TC-08 item and order detail', '3', '3/3', 'Stable'],
    ['TC-09 export and upload', '3', '3/3', 'Stable'],
    ['TC-10 Remote Config items', '3', '2/3', 'Agent counted 4 of 5 in a scrolling list'],
    ['TC-17 quantity stepper', '3', '2/3', 'Agent tapped the stepper once'],
    ['TC-16 default payment', '4', '3/4', 'First run read a vanishing snackbar'],
    ['TC-14 change kiosk', '3', '1/3', 'Agent misread; by hand the cart empties'],
    ['TC-15 student profile', '3', '1/3', 'Agent did not read the saved value'],
    ['TC-04 wrong voucher', '3', '0/3', 'Agent did not type BB20 into the field'],
  ].map((r, i) => (i === 0 ? r : r.map((t, j) => cell(t, {
    align: j === 1 || j === 2 ? 'center' : 'left',
    bold: j === 2,
    color: j === 2 ? (t === '3/3' ? C.accent3 : C.accent4) : C.text1,
    fill: { color: i % 2 ? C.background1 : C.background2 },
  }))));
  s.addTable(rows, { x: MX, y: 1.55, w: 8.3, colW: [2.6, 0.65, 0.75, 4.3], rowH: 0.43, border: { type: 'solid', pt: 0.5, color: C.accent6 }, margin: [0, 0.08, 0, 0.08] });
  stat(s, '10 / 31', 'cases run; 21 not run', 9.3, 1.6, 3.4);
  bullets(s, [
    'Each failure was traced to the agent, then checked by hand.',
    'Fix in the tests: read a saved value instead of a snackbar.',
    'Harness: the final report is read from the server trace.',
  ], { x: 9.3, y: 3.6, w: 3.45, h: 2.8, fontSize: 14 });
  caption(s, 'Table and run files: docs/test-plan.md section 3, evidence/artemis/run-*.xml', MX, 6.45, 8.3);
}
// 13. code review
{
  const s = content('Of 10 AI review findings, 5 were fixed with a test, 1 is a known limit, 4 were rejected',
    'Tool: Claude Code /code-review. Each finding was opened in the code before deciding, because the tool can be wrong. The new tests fail on the old code and pass on the new (CR-05 was run both ways). CR-07 to CR-10 rejected with a reason each; CR-10 was partly wrong in its own text.');
  const rows = [
    [hdr('ID'), hdr('Finding'), hdr('Decision'), hdr('Fix commit')],
    ['CR-01', 'Order total uses client prices, never the menu', 'Accepted, known limit', '—'],
    ['CR-02', 'A new item with an existing name overwrites it', 'Fixed', 'd6d8113'],
    ['CR-03', 'Incident answered twice from a stale copy', 'Fixed (transaction)', 'd1291a6'],
    ['CR-04', '“Mark all read” over the 500-write batch cap', 'Fixed (batches of 400)', '9243bf3'],
    ['CR-05', '“Xem đơn cũ hơn” could add nothing', 'Fixed, test fails before', '2980559'],
    ['CR-06', 'First “Có lại lúc” option ignored seconds', 'Fixed', 'ba8dc33'],
    ['CR-07 – 10', 'Slot release, busy guard, extra reads, submit check', 'Rejected, a reason each', '—'],
  ].map((r, i) => (i === 0 ? r : r.map((t, j) => cell(t, {
    bold: j === 0,
    color: j === 2 ? (t.startsWith('Fixed') ? C.accent3 : t.startsWith('Rejected') ? C.accent5 : C.accent2) : C.text1,
    fill: { color: i % 2 ? C.background1 : C.background2 },
  }))));
  s.addTable(rows, { x: MX, y: 1.7, w: CW, colW: [1.3, 5.9, 3.3, 1.62], rowH: 0.55, fontSize: 14, border: { type: 'solid', pt: 0.5, color: C.accent6 }, margin: [0, 0.1, 0, 0.1] });
  caption(s, 'Unchanged tool output: evidence/code-review/ · full table with reasons: docs/code-review.md', MX, 6.3, CW);
}
// 14. challenges and lessons
{
  const s = content('The real Firebase and a real test agent exposed what fakes and emulators hid',
    'Challenges and lessons. The shared change in each: test against the real thing early, and check what an AI tool says before acting on it.');
  const items = [
    ['Cloud Storage is paid', 'Files go to Cloudinary behind the same StorageService interface.'],
    ['A UI check is not a rule', 'Real rules on the emulator found gaps that fake data hid (CR-01, CR-03).'],
    ['Real Firebase found two bugs', 'Missing indexes broke the shift screen; a push tapped on a closed app ended on Home.'],
    ['An AI test agent is flaky', 'It mistyped, miscounted and missed snackbars; each failure was checked by hand.'],
    ['An AI review is a list of questions', '4 of 10 findings were rejected after reading the code and the rules.'],
    ['Write the plan first', 'Traceability and the test plan before the screens; late changes cost a row and a Figma edit.'],
  ];
  const cw = (CW - 0.4) / 2;
  items.forEach((it, i) => {
    const x = MX + (i % 2) * (cw + 0.4);
    const y = 1.7 + Math.floor(i / 2) * 1.7;
    s.addShape(pres.ShapeType.roundRect, { x, y, w: cw, h: 1.5, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.accent6, width: 1 } });
    s.addText(String(i + 1), { shape: pres.ShapeType.ellipse, x: x + 0.2, y: y + 0.2, w: 0.55, h: 0.55, fontSize: 16, bold: true, align: 'center', valign: 'middle', color: C.background1, fill: { color: C.accent2 }, margin: 0 });
    text(s, it[0], { x: x + 0.95, y: y + 0.18, w: cw - 1.15, h: 0.4, fontSize: 17, bold: true, color: C.text2 });
    text(s, it[1], { x: x + 0.95, y: y + 0.65, w: cw - 1.15, h: 0.8, fontSize: 14 });
  });
}
// 15. where to find everything
{
  const s = pres.addSlide({ masterName: 'DARK' });
  s.addText('Everything on these slides links to a file in the repository', Object.assign({}, TITLE, { color: C.background1 }));
  const rows = [
    ['Traceability and deviations', 'docs/design-traceability.md'],
    ['Architecture, Firebase design', 'docs/architecture.md · docs/firebase-design.md'],
    ['Analytics plan', 'docs/analytics-plan.md'],
    ['ARTEMIS test plan, results, tests', 'docs/test-plan.md · e2e_test/ · evidence/artemis/'],
    ['Code review', 'docs/code-review.md · evidence/code-review/'],
    ['Screenshots', 'evidence/'],
    ['Demo video', 'link in README.md'],
  ].map((r) => r.map((t, j) => ({ text: t, options: { fontSize: 15, color: j ? C.accent1 : C.background1, valign: 'middle', border: [{ type: 'none' }, { type: 'none' }, { type: 'solid', pt: 0.5, color: C.accent5 }, { type: 'none' }] } })));
  s.addTable(rows, { x: MX, y: 1.7, w: 8.0, colW: [3.2, 4.8], rowH: 0.52, margin: [0, 0.05, 0, 0.05] });
  text(s, 'AI tools used for the slides', { x: 9.1, y: 1.7, w: 3.7, h: 0.4, fontSize: 18, bold: true, color: C.accent1 });
  text(s, 'Claude Code (Claude Sonnet 5.5) wrote the generator scripts/build_slides.js with pptxgenjs; layout follows assertion-evidence slide design. Screenshots come from evidence/.', { x: 9.1, y: 2.2, w: 3.7, h: 2.6, fontSize: 14, color: C.background1 });
  text(s, 'Report: report/Lab03_SE193905.pdf', { x: MX, y: 6.0, w: 8, h: 0.4, fontSize: 15, color: C.background1 });
  s.addNotes('Every claim on the slides links to a file in the repo. List of AI tools used is also in the README and the report.');
}

(async () => {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  await pres.writeFile({ fileName: OUT });
  if (SKILL_DIR) {
    const { applyTheme } = require(path.join(SKILL_DIR, 'scripts', 'apply_theme.js'));
    await applyTheme(OUT, THEME);
  }
  console.log('written', OUT);
})();
