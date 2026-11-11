"""Builds report/Lab03_<StudentID>.pdf from the repo's own docs and evidence. The slides are built by scripts/build_slides.js.

Run from the repo root:  python scripts/build_report.py
Needs PyMuPDF (`pip install pymupdf`). The text is HTML in this file; every claim points to a file in the repo.
Fonts: Arial from the Windows font folder (Vietnamese letters); other systems fall back to the built-in sans.
"""
import gc
import os
import sys

import fitz

STUDENT_ID = 'SE193905'
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
FONT_DIR = 'C:/Windows/Fonts'
REPO = 'https://github.com/baonv0817/PRM393_Lab03_Group2'

# Numbers that come from runs; update them when the runs are repeated.
N_WIDGET_TESTS = 752
N_RULES_TESTS = 88
N_INTEGRATION_TESTS = 15

FONT_CSS = """
@font-face{font-family:AR;src:url(arial.ttf)}
@font-face{font-family:AR;font-weight:bold;src:url(arialbd.ttf)}
@font-face{font-family:AR;font-style:italic;src:url(ariali.ttf)}
@font-face{font-family:CO;src:url(cour.ttf)}
"""

REPORT_CSS = FONT_CSS + """
body{font-family:AR;font-size:11pt;line-height:1.4}
h1{font-size:20pt;color:#1a5c3a;margin:0 0 4pt 0}
h2{font-size:14pt;color:#1a5c3a;margin:14pt 0 4pt 0;border-bottom:1px solid #1a5c3a}
h3{font-size:10pt;color:#333;margin:7pt 0 2pt 0}
p{margin:2pt 0 3pt 0}
code{font-family:CO;font-size:9.3pt}
table{border-collapse:collapse;width:100%;margin:4pt 0 6pt 0}
td,th{border:1px solid #aaa;padding:3pt 4pt;vertical-align:top;font-size:9.4pt}
th{background-color:#e6efe9;text-align:left}
.note{background-color:#fff4d6;border:1px solid #d9b44a;padding:3pt 5pt;margin:4pt 0}
.cap{font-size:7.5pt;color:#555;margin:0 0 4pt 0}
.cr{border:1px solid #aaa;padding:2pt 6pt;margin:0 0 5pt 0}
li{margin:0 0 1.5pt 0}
"""

SLIDE_CSS = FONT_CSS + """
body{font-family:AR;font-size:15pt;line-height:1.3}
h1{font-size:34pt;color:#1a5c3a;margin:0 0 8pt 0}
h2{font-size:25pt;color:#1a5c3a;margin:0 0 8pt 0}
p{margin:3pt 0 5pt 0}
li{margin:0 0 5pt 0}
code{font-family:CO;font-size:12pt}
table{border-collapse:collapse;width:100%;margin:4pt 0}
td,th{border:1px solid #aaa;padding:3pt 5pt;vertical-align:top;font-size:12.5pt}
th{background-color:#e6efe9;text-align:left}
.cap{font-size:11pt;color:#555}
.big{font-size:19pt}
.warn{background-color:#fff4d6;border:1px solid #d9b44a;padding:4pt 7pt}
"""


def archive():
    arch = fitz.Archive()
    arch.add(fitz.Archive(ROOT))
    if os.path.isdir(FONT_DIR):
        arch.add(fitz.Archive(FONT_DIR))
    return arch


def img(path, width):
    return f'<img src="{path}" width="{width}"/>'


def link(path, label=None):
    return f'<a href="{REPO}/blob/main/{path}">{label or path}</a>'


def write_pdf(pages_html, css, out, pagesize, margin, footer):
    """One Story per entry in [pages_html]; the report is a single Story that flows over pages, slides are one each."""
    page = fitz.paper_rect(pagesize)
    where = page + (margin, margin, -margin, -margin - 8)
    raw = out + '.raw'
    writer = fitz.DocumentWriter(raw)
    for html in pages_html:
        story = fitz.Story(html=html, user_css=css, archive=archive())
        more = 1
        while more:
            dev = writer.begin_page(page)
            more, _ = story.place(where)
            story.draw(dev)
            writer.end_page()
    writer.close()
    del writer
    gc.collect()
    doc = fitz.open(raw)
    total = len(doc)
    for i, p in enumerate(doc, 1):
        p.insert_text((page.width - margin - 60, page.height - 14), f'{footer} {i}/{total}', fontsize=7, color=(0.4, 0.4, 0.4))
    doc.save(out, garbage=3, deflate=True)
    doc.close()
    del doc
    gc.collect()
    try:
        os.remove(raw)
    except OSError:
        pass
    return total


# --------------------------------------------------------------------------------------- report

def report_html():
    return f"""
<h1>BreakBite · Lab 3 final report</h1>
<p><b>PRM393 · Cloud-Enabled Mobile App (Firebase, ARTEMIS, AI code review)</b> · Team BreakBite (5 members) · repository
<a href="{REPO}">{REPO}</a> · pinned versions and the map of deliverables: {link('README.md')}.</p>
<div class="note"><b>How to read this report.</b> Every claim that something works points to a file in the repository
(a test, a screenshot in <code>evidence/</code> or a document in <code>docs/</code>). What could not be shown yet is listed in
section 11 instead of being filled in. Screens of P1 come from a real Android phone with the real Firebase. Screens of P2 were captured on an Android emulator, first with fake data and then again with the real Firebase (<code>evidence/p2-real/</code>). The FCM, Analytics and ARTEMIS evidence comes from the real Firebase project <code>breakbite-1315b</code>.</div>

<h2>1. Project overview and Lab 2 recap</h2>
<p>BreakBite is a pre-order, pick-up-at-the-counter food app for students who study on Campus District 9 and have a short
break between classes. A <b>customer app</b> (S01–S30) lets them order, pay (simulated), follow, edit and review an order; a
<b>seller app</b> (K01–K15) lets kiosk staff take orders, run the menu and see their shift. Both are one Flutter project; the
account role chooses the app. The design is the Lab 2 Figma (<code>PRM323-Lab2-Group2</code>, frames with the v2 suffix).</p>
<p><b>Lab 2 success criterion:</b> finish an order in under 35 seconds with at most 8 taps ({link('docs/analytics-plan.md')}; the
<code>purchase</code> event is the one that measures it).
<b>Flows:</b> F1 quick order, F2 order with a voucher, F3 payment error then cash; plus sign-in, search, export and upload, push
notification and the seller side. Main screens built: <b>44 of 44</b> (K07 is not in Figma), no placeholder route is left
(checked in <code>lib/routing/routes_p*.dart</code>).</p>
<table><tr><th>Member</th><th>Area</th></tr>
<tr><td>P1</td><td>Ordering flow S03–S08, S21, S22, S25, S29; architecture doc, design traceability, shared theme and widgets</td></tr>
<tr><td>P2</td><td>After ordering S09–S12, S20, S23, S24; seller menu K08–K11, K14, K15; PDF receipt export</td></tr>
<tr><td>P3</td><td>Firebase: Auth, Firestore, rules, Cloudinary, Crashlytics, Remote Config; S15–S17, S26, S27, Firebase demo area</td></tr>
<tr><td>P4</td><td>Seller order handling K01–K06, K12, K13; code review; report, slides, video</td></tr>
<tr><td>P5</td><td>S13, S14, S18, S19, S28, S30; FCM; analytics; ARTEMIS tests</td></tr></table>

<h2>2. Design traceability and deviations</h2>
<p>{link('docs/design-traceability.md')} maps every Lab 2 screen, flow and component to a route, a widget and a data source, with a status.
Section 5 of that file records <b>every place where the app differs from Figma, with the reason</b> (D01–D33). The main ones:</p>
<ul>
<li><b>D01, D03:</b> Google Sign-In replaces the school e-mail + OTP, and a signed-out user only sees S26 (handout requirement).</li>
<li><b>D12, D13:</b> the add-to-cart stepper and the floating cart button replace the + icon and the cart icon of S02 (the cart must be reachable and correctable).</li>
<li><b>D18:</b> S25 offers the kiosk's break slots (with a capacity) instead of a typed timetable, because the data model books slots.</li>
<li><b>D23, D24:</b> K14/K15 have no photo box and no "Xoá món": the final assignment drops Cloud Storage and the rules forbid deleting menu items.</li>
<li><b>D21, D22, D25–D27:</b> the screens of P2 add what the data model already had (wait time, notice, hours and capacity in K10; the line "Đang xử lý" in K11; weekly and monthly groups in S11; a timeline, review and receipt in S12).</li>
</ul>
<p>The column "Figma updated" is still <b>Not yet</b> for these rows; updating Figma is task T83 (section 11). Two examples of
Figma (left) and the app (right) from {link('evidence/figma/')}:</p>
<table><tr><td>{img('evidence/figma/p2-K10.png', 255)}</td><td>{img('evidence/figma/p2-S11.png', 255)}</td></tr></table>
<p class="cap">K10 "Quán" (D21) and S11 "Lịch sử đơn" (D25). Fourteen such pairs for the screens of P2 are in <code>evidence/figma/</code>, thirteen more for P1.</p>

<h2>3. Architecture and MVVM</h2>
<p>MVVM with Provider and go_router, following the official Flutter architecture guide: a <b>UI layer</b> (screens and
ViewModels grouped by feature, <code>lib/ui/&lt;feature&gt;/</code>) above a <b>data layer</b> (repositories and services,
<code>lib/data/</code>) above pure models (<code>lib/domain/</code>). Dependencies only point down. {link('docs/architecture.md')}
explains why the folders differ from the handout's suggestion (five people working in parallel; the final assignment needs a shared
package).</p>
<table><tr><th>Layer</th><th>Responsibility</th><th>Knows about</th></tr>
<tr><td>Screen <code>ui/*/widgets</code></td><td>Draws the ViewModel's <code>ViewState</code>, forwards taps</td><td>Its ViewModel, <code>ui/core</code>, routes</td></tr>
<tr><td>ViewModel <code>ui/*/view_models</code></td><td>Screen state, validation, calls to repositories and services, <code>Command</code> for actions</td><td>Interfaces and models only</td></tr>
<tr><td>Repository <code>data/repositories</code></td><td>Business data in Firestore → models, queries, transactions</td><td>Models, Firestore (in its implementation)</td></tr>
<tr><td>Service <code>data/services</code></td><td>Wraps one SDK (Auth, FCM, Analytics, Crashlytics, Remote Config, Cloudinary)</td><td>The SDK (in its implementation)</td></tr>
<tr><td>Model <code>domain/models</code></td><td>Immutable data and pure rules</td><td>Nothing</td></tr></table>
<p><b>Enforced by a test:</b> <code>test/architecture_test.dart</code> fails if a screen, a ViewModel, a route or a model imports an SDK, if a
screen holds a <code>Color</code>, <code>Colors</code> or <code>TextStyle</code> literal, or if a ViewModel does not use <code>SafeChangeNotifier</code>. Fake data lives in
<code>dev/</code>, outside <code>lib/</code>, so the submitted build has no mock data. <b>MVVM check across the repo (T72):</b> every widget file was read
against the rules; three pieces of logic were moved out of <code>build()</code> into ViewModels (S11, S12, K11) and two cases were kept with a reason
(section 3 of the architecture document).</p>

<h2>4. Design system in code</h2>
<p>Tokens live in one place, <code>lib/ui/core/theme/</code>: <code>app_colors.dart</code> (colors from the Figma v2 frames, with contrast tests for
WCAG), <code>app_dimens.dart</code> (spacing, radius, minimum tap target 48 dp) and <code>app_theme.dart</code> (the Material theme built from them).
Components are one widget each in <code>lib/ui/core/widgets/</code> (<code>AppButton</code>, <code>AppChip</code>, <code>AppTopBar</code>, <code>QuantityStepper</code>,
<code>BottomActionButton</code>, <code>ViewError</code>/<code>ViewEmpty</code>/<code>LoadingView</code>, <code>StatusBadge</code>…); every screen uses them, and the architecture test forbids colour or text-style
literals in screens. The widget catalog <code>dev/widget_catalog.dart</code> shows every component and variant and is tested at 360 and 412 dp with text at 1.0 and 1.3:
no overflow, every tap target at least 48 dp, every one labelled. Every state a screen can be in (loading, empty, error with retry) is a shared widget, not a copy.</p>

<h2>5. Firebase design</h2>
<p>Project <code>breakbite-1315b</code>, Spark plan. Screens never call an SDK: each service is an interface in <code>lib/data/services/</code> with a Firebase
implementation, and every failure comes back as a typed <code>AppException</code> with a Vietnamese message ({link('docs/firebase-design.md')} has the full table per service).</p>
<table><tr><th>Service</th><th>What the app does</th><th>Failure handling</th></tr>
<tr><td><b>Authentication</b></td><td>Google Sign-In (S26); first sign-in creates <code>users/{{uid}}</code> with role <code>user</code>; the role (set with <code>set-role.mjs</code>) routes to the customer or the seller app; sign-out clears local data</td><td>Cancelled sign-in, no network and "no token" each show their own message; the router waits on a splash screen until the sign-in state is known</td></tr>
<tr><td><b>Firestore + rules</b></td><td>Menu, cart, orders (placed, edited and cancelled in one transaction), incidents, reviews, notifications; deny by default, access by role, staff only at their own kiosk; {N_RULES_TESTS} rules tests and an integration test against the real rules</td><td>A write that depends on current data runs in a transaction, so the user sees a clear reason (for example "Đơn này vừa được xử lý ở nơi khác") instead of a rules error</td></tr>
<tr><td><b>Files (Cloudinary)</b></td><td>The order receipt (S12) and the report in the demo area are PDFs uploaded with a progress bar to <code>breakbite/reports/{{uid}}/</code>; the URL and metadata are kept in <code>reports</code> (owner-only rules)</td><td>Not configured, larger than 5 MB, no network, timeout and "PDF cannot be made" each have a message; the retry button stays</td></tr>
<tr><td><b>Cloud Messaging</b></td><td>Permission on Android 13+, token per user in <code>users/{{uid}}.fcmTokens</code>, messages saved to the in-app list (S19) in foreground, background and terminated states; tapping opens the order</td><td>A refused permission or a failed token write never blocks sign-in or sign-out</td></tr>
<tr><td><b>Analytics</b></td><td>11 events in the plan, all logged in code; <code>setUserId</code> after sign-in, no personal data</td><td>Logging never throws</td></tr>
<tr><td><b>Crashlytics</b></td><td>Uncaught errors reported; handled errors from real error paths recorded as non-fatal with the keys <code>role</code> and <code>kiosk_id</code></td><td>Reporting never throws</td></tr>
<tr><td><b>Remote Config</b></td><td><code>quick_items_limit</code>, <code>promo_banner_enabled</code>, <code>pickup_slot_enabled</code>; the app listens for updates, so Home changes without a rebuild</td><td>Offline: last values, or the in-app defaults on a first launch</td></tr></table>
<p><b>Why Cloudinary:</b> Cloud Storage for Firebase needs the Blaze plan (a payment card). The upload goes through the same <code>StorageService</code> interface with an unsigned
preset, so the app holds no API secret; this is a deviation from the handout (listed in the README). The lecturer confirmed in writing that Cloudinary or S3 is acceptable.</p>
<table><tr><td>{img('evidence/auth/2-signed-in.png', 105)}</td><td>{img('evidence/storage/4-cloudinary-library.png', 250)}<br/>{img('evidence/remote-config/2-console.png', 250)}</td><td>{img('evidence/crashlytics/1-non-fatal.png', 250)}</td></tr></table>
<p class="cap">Signed-in app (<code>evidence/auth</code>), the uploaded PDF in the Cloudinary library (<code>evidence/storage</code>), the Remote Config console (<code>evidence/remote-config</code>)
and a non-fatal error in Crashlytics (<code>evidence/crashlytics</code>), all from project <code>breakbite-1315b</code>.</p>

<p><b>Push notifications in the three app states.</b> A test message from the Firebase console, sent to the device token with the data <code>orderId</code>, shows an in-app banner when the app is open, a system notification when it is in the background and again when it is closed. Tapping a notification opens the tracking screen of that order, and each message is saved in the notification list (S19). Evidence: <code>evidence/fcm/</code>.
<b>Bug found by this test:</b> from a closed app, the tap opened the order for a moment and Home replaced it when the splash screen redirected. <code>PushRouter</code> now waits until the app is ready (<code>lib/app.dart</code>). The screenshots before and after the fix are kept.</p>
<table><tr><td>{img('evidence/fcm/2-foreground.png', 105)}</td><td>{img('evidence/fcm/3-background.png', 105)}</td><td>{img('evidence/fcm/4-terminated-tap-before-fix.png', 105)}</td><td>{img('evidence/fcm/4-terminated-tap-after-fix.png', 105)}</td></tr></table>
<p class="cap">Open app (banner) · background (notification) · closed app, tap before the fix (ends on Home) · after the fix (opens the order).</p>

<h2>6. Analytics plan and evidence</h2>
<p>{link('docs/analytics-plan.md')} was written before the code: 11 events covering sign-in (<code>login</code>), sign-out (<code>logout</code>), search, opening an item
(<code>view_menu_item</code>), ordering (<code>add_to_cart</code>, <code>reorder</code>, <code>begin_checkout</code>, <code>purchase</code>, <code>payment_failed</code>), the seller steps
(<code>order_accepted</code>, <code>order_delivered</code>) and the export (<code>export_report</code>, with <code>source: order_detail</code> for the receipt of S12). Each event answers a product question and maps to a Lab 2 step; the one
that tests the success criterion is <code>purchase</code> (≤ 8 taps, &lt; 35 seconds). Names come from <code>AnalyticsEvents</code>, parameters are numbers and short strings, never a name or an e-mail.
All 11 are logged in code and covered by ViewModel tests. DebugView (debug mode on with <code>adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite</code>) shows the events arriving with their parameters.</p>
<table><tr><td>{img('evidence/analytics/debugview-top-events.png', 340)}</td><td>{img('evidence/analytics/debugview-timeline.png', 340)}</td></tr></table>
<p class="cap">DebugView: the events of the plan with their counts · the timeline of one session.</p>

<h2>7. ARTEMIS test plan, results and exploratory session</h2>
<p>{link('docs/test-plan.md')} has 31 test cases (TC-01 to TC-31) covering sign-in and sign-out, F1–F3, search, export and upload, push, the seller flow, the seller menu, a sold-out item and a closed kiosk, with
happy paths, error paths and native interactions (airplane mode, notification). {link('e2e_test/')} has one pytest function per case; each sends one instruction and <b>asserts on the value the agent reports back</b>, not only on
<code>succeeded</code>; <code>run_repeat.py</code> runs the suite N times and writes the pass-rate table. P2's cases are TC-18 to TC-29 (<code>test_order_manage.py</code>, <code>test_seller_menu_shop.py</code>).</p>
<p><b>Results.</b> Ten of the 31 cases were run (TC-04, 06, 07, 08, 09, 10, 14, 15, 16, 17), each at least 3 times, on an Android emulator (Pixel 7) against the real Firebase project, with the flash profile (Gemini 3.5 Flash Lite). The JUnit file of every run is in <code>evidence/artemis/run-*.xml</code>; the table with notes is section 3 of the test plan. The other 21 cases are "Not run": the free model quota was limited, and most of them need two devices, the staff role, airplane mode or the notification shade.</p>
<table><tr><th>Case</th><th>Runs</th><th>Pass</th><th>Reason for failures</th></tr>
<tr><td>TC-06 search with no result, TC-07 main tabs, TC-08 item and order detail, TC-09 export and upload</td><td>3 each</td><td>3/3</td><td>Stable</td></tr>
<tr><td>TC-10 Remote Config quick items</td><td>3</td><td>2/3</td><td>The agent counted 4 of 5 items in a list that needs scrolling</td></tr>
<tr><td>TC-17 quantity stepper</td><td>3</td><td>2/3</td><td>The agent tapped the stepper once instead of twice</td></tr>
<tr><td>TC-16 default payment method</td><td>4</td><td>3/4</td><td>The first failure was a check on a snackbar; the test now reads the saved choice</td></tr>
<tr><td>TC-14 change kiosk empties the cart</td><td>3</td><td>1/3</td><td>The agent misread the screen; by hand the warning shows and the cart is emptied</td></tr>
<tr><td>TC-15 student profile</td><td>3</td><td>1/3</td><td>The agent did not read the saved value; by hand it saves and persists</td></tr>
<tr><td>TC-04 wrong voucher</td><td>3</td><td>0/3</td><td>The agent does not type BB20 into the field; by hand the app shows "Mã BB20 đã hết hạn."</td></tr></table>
<p><b>Analysis.</b> The failures come from the agent typing into a field, reading a short-lived snackbar or counting a scrolling list. Repeated by hand, the app behaved correctly; the screenshots for TC-10 and TC-14 are in <code>evidence/artemis/manual/</code>. The fixes were made in the tests: clearer instructions (TC-04, 14), reading the saved value after reopening the screen instead of a snackbar (TC-15, 16), and a harness change. The pinned ARTEMIS version returns no structured output, so <code>e2e_test/conftest.py</code> reads the agent's final JSON report from the server trace.</p>
<p>Other checks that were run: {N_WIDGET_TESTS} unit, ViewModel, widget and full-app flow tests (<code>flutter test</code>, no device), {N_RULES_TESTS} Firestore rules tests (<code>firebase/tests</code>) and {N_INTEGRATION_TESTS} integration tests of the real Firebase code against the Auth and Firestore emulators (<code>integration_test/firebase_emulator_test.dart</code>). <code>flutter analyze</code> has no issue.</p>
EXPLORATORY_PLACEHOLDER

<h2>8. AI code review findings and decisions</h2>
<p>Tool: Claude Code, skill <code>/code-review</code>, run on the repositories and the screens of P2; the unchanged output is in {link('evidence/code-review/claude-code-review.md')} and the full table in
{link('docs/code-review.md')}. Each finding was opened in the code before it was decided, because the tool can be wrong (for CR-10 its text said the description is untrimmed, but the repository trims it).</p>
<div class="cr"><p><b>CR-01</b> · security · <code>firestore_order_repository.dart:52</code> · fix: —</p><p><b>Finding:</b> The order total is built from client prices, never read from <code>menu_items</code>.</p><p><b>Decision:</b> Accepted, not fixed: needs menu reads in the order transaction and a rules change on the ordering path of P1/P3; recorded as a known limitation.</p></div>
<div class="cr"><p><b>CR-02</b> · bug · <code>firestore_menu_repository.dart:91</code> · fix: <a href="{REPO}/commit/d6d8113">d6d8113</a></p><p><b>Finding:</b> A new item with an existing name overwrites that item.</p><p><b>Decision:</b> Accepted: silent data loss between two staff members.</p></div>
<div class="cr"><p><b>CR-03</b> · bug · <code>firestore_incident_repository.dart:98</code> · fix: <a href="{REPO}/commit/d1291a6">d1291a6</a></p><p><b>Finding:</b> Take/answer an incident checked a stale copy.</p><p><b>Decision:</b> Accepted: rules let staff update a resolved incident, so a second answer overwrote the first; now a transaction.</p></div>
<div class="cr"><p><b>CR-04</b> · performance · <code>firestore_notification_repository.dart:55</code> · fix: <a href="{REPO}/commit/9243bf3">9243bf3</a></p><p><b>Finding:</b> "Mark all read" in one write batch.</p><p><b>Decision:</b> Accepted: Firestore caps a batch at 500 writes; now batches of 400, tested with 450.</p></div>
<div class="cr"><p><b>CR-05</b> · bug · <code>order_history_view_model.dart:98</code> · fix: <a href="{REPO}/commit/2980559">2980559</a></p><p><b>Finding:</b> "Xem đơn cũ hơn" could add nothing while older orders exist.</p><p><b>Decision:</b> Accepted: the first load already skips such pages; test fails before, passes after.</p></div>
<div class="cr"><p><b>CR-06</b> · bug · <code>seller_menu_view_model.dart:41</code> · fix: <a href="{REPO}/commit/ba8dc33">ba8dc33</a></p><p><b>Finding:</b> First "Có lại lúc" option ignored seconds.</p><p><b>Decision:</b> Accepted: 10:15:20 offered 10:30, 20 s under the promised 15 minutes.</p></div>
<div class="cr"><p><b>CR-07</b> · bug · <code>firestore_order_repository.dart:275</code> · fix: —</p><p><b>Finding:</b> Slot release fails if the slot document is missing.</p><p><b>Decision:</b> Rejected: the rules allow no slot delete and keep <code>booked</code> ≥ 0; no script deletes slots.</p></div>
<div class="cr"><p><b>CR-08</b> · maintainability · <code>shop_view_model.dart:134</code> · fix: —</p><p><b>Finding:</b> <code>_apply</code> returns ok when busy.</p><p><b>Decision:</b> Rejected: the screen disables every control while a write runs, and a test covers the guard.</p></div>
<div class="cr"><p><b>CR-09</b> · performance · <code>shift_stats_view_model.dart:116</code> · fix: —</p><p><b>Finding:</b> K11 reads all kiosks to get one opening time.</p><p><b>Decision:</b> Rejected: 2 kiosks, 2 reads per refresh; a new repository method costs more than it saves.</p></div>
<div class="cr"><p><b>CR-10</b> · test gap · <code>incident_view_model.dart:128</code> · fix: —</p><p><b>Finding:</b> Submit does not check status or an earlier report.</p><p><b>Decision:</b> Rejected: partly wrong; the button is disabled while running and the rules refuse a second report.</p></div>
<p>Five fixes, each in its own commit that names the finding; the new tests fail on the old code and pass on the new (CR-05 was run both ways). CR-02, CR-03 and CR-04 are also covered by the emulator integration test.</p>

<h2>9. Challenges encountered</h2>
<ul>
<li><b>Cloud Storage is not free.</b> It needs the Blaze plan, so files go through Cloudinary behind the same <code>StorageService</code> interface; the lecturer agreed in writing.</li>
<li><b>Five people on 44 screens.</b> One folder per feature and one route file per owner kept merges small; a few shared files (theme, widgets, router) needed rules in <code>CONTRIBUTING.md</code>.</li>
<li><b>Rules and UI must agree.</b> A check done only in the UI is not a security rule: the incident rules let staff update a resolved report, and an order's prices are not checked against the menu (CR-01, CR-03). Testing the real rules on the emulator found both kinds of gap that fake data hides.</li>
<li><b>Stale data on screen.</b> Two staff members can hold different copies of the same document; the fixes read the document again inside a transaction.</li>
<li><b>Evidence needs accounts.</b> Real-Firebase screenshots need a staff role (set with <code>set-role.mjs</code>) and the SHA-1 key of every machine. The screens were first captured with fake data and then repeated on the real Firebase.</li>
<li><b>The real Firebase found what the emulator hid.</b> The seller shift screen (K11) failed because its composite indexes were missing (16 indexes are now in <code>firestore.indexes.json</code>), and a push tapped on a closed app ended on Home (fixed in <code>lib/app.dart</code>).</li>
<li><b>An AI test agent is a flaky tester.</b> On a free model quota ARTEMIS used 40 to 50 model requests per test. It mistyped, miscounted and missed snackbars that vanish in seconds. Each failure was repeated by hand to decide whether the app or the agent was wrong.</li>
</ul>

<h2>10. Lessons learned</h2>
<ul>
<li>Write the traceability and the test plan <b>before</b> the screens: every deviation found later cost a table row and a Figma change.</li>
<li>Put logic in ViewModels from the start: moving it out of <code>build()</code> afterwards (T72) was three small changes only because the architecture test already blocked the worst cases.</li>
<li>Test against the real rules early. The emulator test caught assumptions that the fakes could not (for example that a customer may report an order that is not delivered yet: the rules allow it, the UI does not offer it).</li>
<li>An AI review is a list of questions, not of facts: four of ten findings were rejected after reading the code and the rules, and one claim in an accepted-looking finding was wrong.</li>
<li>Judge a failing agent test by repeating the step by hand, and write into the test what the agent can read reliably (a saved value, not a snackbar that disappears).</li>
</ul>

<h2>11. Remaining work</h2>
<table><tr><th>Item</th><th>Note</th></tr>
<tr><td>ARTEMIS Pro-profile exploratory session on a phone (15 to 30 minutes)</td><td>The session in section 7 was done by hand on an emulator</td></tr>
<tr><td>Figma updated for the deviations D01 to D33</td><td>Listed as "Not yet" in the traceability table</td></tr>
<tr><td>Known limitation CR-01: order prices are not checked against the menu on the server</td><td>Needs a rules change on the ordering path</td></tr></table>

<h2>12. AI tools used</h2>
<table><tr><th>Tool</th><th>Purpose</th></tr>
<tr><td>Claude Code (Claude Sonnet 5.5)</td><td>Writing and testing the code of P2, the ARTEMIS cases TC-18 to TC-29, the evidence screenshots, the ARTEMIS runs and their analysis, the review fixes, this report (<code>scripts/build_report.py</code>) and the slides (<code>scripts/build_slides.js</code>, pptxgenjs)</td></tr>
<tr><td>Google ARTEMIS with Gemini 3.5 Flash Lite</td><td>The UI test agent of section 7</td></tr>
<tr><td>Microsoft Edge TTS (vi-VN-HoaiMyNeural)</td><td>The narration of the demo video</td></tr>
<tr><td>Claude Code, skill <code>/code-review</code></td><td>The AI code review of section 8</td></tr>
<tr><td>Other members</td><td>To be added by each member in the README and in {link('docs/code-review.md')}</td></tr></table>
"""


EXPLORATORY = ''
EXPLORATORY_SLIDE = ''


def main():
    out_report = os.path.join(ROOT, 'report', f'Lab03_{STUDENT_ID}.pdf')
    exploratory = ''
    path = os.path.join(ROOT, 'scripts', 'exploratory.html')
    if os.path.exists(path):
        parts = open(path, encoding='utf-8').read().split('<!--SLIDE-->')
        exploratory = parts[0]
    html = report_html().replace('EXPLORATORY_PLACEHOLDER', exploratory)
    n = write_pdf([html], REPORT_CSS, out_report, 'a4', 50, 'BreakBite · Lab 3 report')
    print('report pages', n)
    if not 8 <= n <= 12:
        print('WARNING: the report must have 8 to 12 pages', file=sys.stderr)


if __name__ == '__main__':
    main()
