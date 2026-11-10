"""Builds report/Lab03_<StudentID>.pdf and slides/Lab03_<StudentID>_slides.pdf from the repo's own docs and evidence.

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
N_WIDGET_TESTS = 748
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
section 11 instead of being filled in. Screens of P2 were captured on an Android emulator with fake data (no real Firebase, no phone).</div>

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
preset, so the app holds no API secret; this is a deviation from the handout (listed in the README, approval of the lecturer still to be attached, section 11).</p>
<table><tr><td>{img('evidence/auth/2-signed-in.png', 105)}</td><td>{img('evidence/storage/4-cloudinary-library.png', 250)}<br/>{img('evidence/remote-config/2-console.png', 250)}</td><td>{img('evidence/crashlytics/1-non-fatal.png', 250)}</td></tr></table>
<p class="cap">Signed-in app (<code>evidence/auth</code>), the uploaded PDF in the Cloudinary library (<code>evidence/storage</code>), the Remote Config console (<code>evidence/remote-config</code>)
and a non-fatal error in Crashlytics (<code>evidence/crashlytics</code>), all from project <code>breakbite-1315b</code>.</p>

<h2>6. Analytics plan and evidence</h2>
<p>{link('docs/analytics-plan.md')} was written before the code: 11 events covering sign-in (<code>login</code>), sign-out (<code>logout</code>), search, opening an item
(<code>view_menu_item</code>), ordering (<code>add_to_cart</code>, <code>reorder</code>, <code>begin_checkout</code>, <code>purchase</code>, <code>payment_failed</code>), the seller steps
(<code>order_accepted</code>, <code>order_delivered</code>) and the export (<code>export_report</code>, with <code>source: order_detail</code> for the receipt of S12). Each event answers a product question and maps to a Lab 2 step; the one
that tests the success criterion is <code>purchase</code> (≤ 8 taps, &lt; 35 seconds). Names come from <code>AnalyticsEvents</code>, parameters are numbers and short strings, never a name or an e-mail.
All 11 are logged in code and covered by ViewModel tests. <b>The DebugView screenshots are not collected yet</b> (section 11).</p>

<h2>7. ARTEMIS test plan, results and exploratory session</h2>
<p>{link('docs/test-plan.md')} has 31 test cases (TC-01 to TC-31) covering sign-in and sign-out, F1–F3, search, export and upload, push, the seller flow, the seller menu, a sold-out item and a closed kiosk, with
happy paths, error paths and native interactions (airplane mode, notification). {link('e2e_test/')} has one pytest function per case; each sends one instruction and <b>asserts on the value the agent reports back</b>, not only on
<code>succeeded</code>; <code>run_repeat.py</code> runs the suite N times and writes the pass-rate table. P2's cases are TC-18 to TC-29 (<code>test_order_manage.py</code>, <code>test_seller_menu_shop.py</code>).</p>
<p><b>Results of ARTEMIS runs: none yet.</b> ARTEMIS needs the ARTEMIS server, a model API key and a device (T02); the tests are written and the "Result" column of the test plan is still "Not run". Nothing was filled in
without a run. What <b>was</b> run: {N_WIDGET_TESTS} unit, ViewModel, widget and full-app flow tests (<code>flutter test</code>, no device), {N_RULES_TESTS} Firestore rules tests (<code>firebase/tests</code>) and {N_INTEGRATION_TESTS}
integration tests of the real Firebase code against the Auth and Firestore emulators on an Android emulator (<code>integration_test/firebase_emulator_test.dart</code>). <code>flutter analyze</code> has no issue.</p>
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
<li><b>Cloud Storage is not free.</b> It needs the Blaze plan, so files go through Cloudinary behind the same <code>StorageService</code> interface; the lecturer's agreement is still to be attached (section 11).</li>
<li><b>Five people on 44 screens.</b> One folder per feature and one route file per owner kept merges small; a few shared files (theme, widgets, router) needed rules in <code>CONTRIBUTING.md</code>.</li>
<li><b>Rules and UI must agree.</b> A check done only in the UI is not a security rule: the incident rules let staff update a resolved report, and an order's prices are not checked against the menu (CR-01, CR-03). Testing the real rules on the emulator found both kinds of gap that fake data hides.</li>
<li><b>Stale data on screen.</b> Two staff members can hold different copies of the same document; the fixes read the document again inside a transaction.</li>
<li><b>Evidence needs accounts.</b> Real-Firebase screenshots need a staff role (set by P3 with <code>set-role.mjs</code>) and SHA-1 keys of every machine; until then the screens were captured with fake data.</li>
</ul>

<h2>10. Lessons learned</h2>
<ul>
<li>Write the traceability and the test plan <b>before</b> the screens: every deviation found later cost a table row and a Figma change.</li>
<li>Put logic in ViewModels from the start: moving it out of <code>build()</code> afterwards (T72) was three small changes only because the architecture test already blocked the worst cases.</li>
<li>Test against the real rules early. The emulator test caught assumptions that the fakes could not (for example that a customer may report an order that is not delivered yet: the rules allow it, the UI does not offer it).</li>
<li>An AI review is a list of questions, not of facts: four of ten findings were rejected after reading the code and the rules, and one claim in an accepted-looking finding was wrong.</li>
<li>Do not mark a test as passed without a run: the ARTEMIS "Result" column stays "Not run" until the server and a device are available.</li>
</ul>

<h2>11. Evidence still to be collected</h2>
<table><tr><th>Item</th><th>Why it is missing</th><th>Who</th></tr>
<tr><td>ARTEMIS results (3 runs per test, pass-rate table), one run for the video</td><td>Needs the ARTEMIS server, a model API key and a device (T02)</td><td>P5</td></tr>
<tr><td>Analytics DebugView screenshots, one per event</td><td>Not collected yet</td><td>P5</td></tr>
<tr><td>FCM screenshots in the three states, S19</td><td>Not collected yet</td><td>P5</td></tr>
<tr><td>Real-Firebase run of the seller screens K08–K15 with a staff account</td><td>Needs the staff role (<code>set-role.mjs</code>) and each machine's SHA-1</td><td>P3, P2</td></tr>
<tr><td>Receipt upload from S12 on a device and in the Cloudinary library (T43)</td><td>The demo-area upload is evidenced (section 5); the S12 receipt is not</td><td>P2</td></tr>
<tr><td>Written confirmation from the lecturer for Cloudinary, a team of 5 and D01 (T11)</td><td>Not obtained yet</td><td>P4</td></tr>
<tr><td>Figma updated for the deviations (D01–D33), the demo video, the submission checklist (T82, T83)</td><td>Done at the end by the team</td><td>P1, P4, all</td></tr>
<tr><td>Known limitation CR-01 (order prices are not checked against the menu on the server)</td><td>Needs a rules change on the ordering path</td><td>P3</td></tr></table>

<h2>12. AI tools used</h2>
<table><tr><th>Tool</th><th>Purpose</th></tr>
<tr><td>Claude Code (Claude Sonnet 5.5)</td><td>Writing and testing the code of P2, the ARTEMIS cases TC-18 to TC-29, the evidence screenshots of P2, the review fixes, this report and the slides (generated from the repository's own documents by <code>scripts/build_report.py</code>)</td></tr>
<tr><td>Claude Code, skill <code>/code-review</code></td><td>The AI code review of section 8</td></tr>
<tr><td>Other members</td><td>To be added by each member in the README and in {link('docs/code-review.md')}</td></tr></table>
"""


# ----------------------------------------------------------------------------------------- slides

def slide(title, body):
    return f'<h2>{title}</h2>{body}'


def slides_html():
    s = []
    s.append("""
<h1>BreakBite</h1>
<p class="big">Pre-order your food in the break between two classes, collect it at the counter.</p>
<p>PRM393 · Lab 3 · Cloud-Enabled Mobile App (Firebase, ARTEMIS, AI code review)</p>
<p>Team BreakBite · Campus District 9 · Flutter + Firebase</p>
<p class="cap">Repository: https://github.com/baonv0817/PRM393_Lab03_Group2 · deliverables map in README.md</p>
""")
    s.append(slide('Persona and Lab 2 success criterion', f"""
<p class="big">Students who study on campus and have a short break.</p>
<ul>
<li><b>Goal:</b> finish an order in <b>under 35 seconds</b> with <b>at most 8 taps</b>.</li>
<li><b>Customer app</b> S01–S30: order, pay (simulated), follow, edit, review.</li>
<li><b>Seller app</b> K01–K15: take orders, menu, shop status, shift statistics.</li>
<li>44 of 44 screens built; no placeholder route left.</li>
</ul>
<p class="cap">The <code>purchase</code> event measures the criterion (docs/analytics-plan.md).</p>"""))
    s.append(slide('Figma vs app: seller shop (K10) and history (S11)', f"""
<table><tr><td>{img('evidence/figma/p2-K10.png', 330)}</td><td>{img('evidence/figma/p2-S11.png', 330)}</td></tr></table>
<p class="cap">Left of each pair: Figma v2. Right: the app (Android emulator, fake data). Differences are recorded as D21 and D25 in docs/design-traceability.md.</p>"""))
    s.append(slide('Deviations from the design, and why', """
<ul>
<li><b>D01/D03</b> Google Sign-In replaces e-mail + OTP; a signed-out user only sees sign-in (handout).</li>
<li><b>D12/D13</b> stepper and floating cart button: add, correct and open the cart in reach of the thumb.</li>
<li><b>D18</b> S25 offers kiosk break slots with a capacity, not a typed timetable (the data model books slots).</li>
<li><b>D23/D24</b> no photo box, no "Xoá món": no Cloud Storage, and rules forbid deleting menu items.</li>
<li><b>D21–D27</b> P2 screens add what the data model already had (wait time, notice, hours, timeline, receipt).</li>
</ul>
<p class="cap">33 rows D01–D33 in docs/design-traceability.md section 5. "Figma updated" is still Not yet (T83).</p>"""))
    s.append(slide('Architecture: MVVM, layers only point down', """
<table>
<tr><td><b>Screen</b></td><td>draws <code>ViewState</code>, forwards taps (<code>ui/*/widgets</code>)</td></tr>
<tr><td><b>ViewModel</b></td><td>state, validation, <code>Command</code> (<code>ui/*/view_models</code>)</td></tr>
<tr><td><b>Repository</b></td><td>business data in Firestore (<code>data/repositories</code>)</td></tr>
<tr><td><b>Service</b></td><td>wraps one SDK (<code>data/services</code>)</td></tr>
<tr><td><b>Model</b></td><td>immutable data, pure rules (<code>domain/models</code>)</td></tr>
</table>
<p><code>test/architecture_test.dart</code> fails on an SDK import in a screen, a colour literal in a screen, or a ViewModel without <code>SafeChangeNotifier</code>. Fake data is in <code>dev/</code>, outside <code>lib/</code>.</p>
<p class="cap">T72: 3 pieces of logic moved out of <code>build()</code>, 2 kept with a reason (docs/architecture.md section 3).</p>"""))
    s.append(slide('Design system in code', """
<ul>
<li><b>Tokens</b> in <code>lib/ui/core/theme/</code>: colors (Figma v2, WCAG contrast tests), dimensions (48 dp tap target), theme.</li>
<li><b>Components</b> one widget each in <code>lib/ui/core/widgets/</code>: button, chip, top bar, stepper, state views.</li>
<li><b>Widget catalog</b> <code>dev/widget_catalog.dart</code>, tested at 360 and 412 dp, text 1.0 and 1.3: no overflow, every target ≥ 48 dp.</li>
<li>Screens hold no colour or text-style literal (architecture test).</li>
</ul>"""))
    s.append(slide('Firebase design: one service, one interface, typed failures', """
<table><tr><th>Service</th><th>What the app does</th></tr>
<tr><td>Auth</td><td>Google Sign-In, role chooses the app; cancelled / offline messages</td></tr>
<tr><td>Firestore</td><td>Rules deny by default; orders in transactions; 88 rules tests</td></tr>
<tr><td>Files</td><td>Cloudinary behind <code>StorageService</code>: PDF with progress, URL, <code>reports</code> metadata</td></tr>
<tr><td>FCM</td><td>Permission, token, in-app list, tap opens the order</td></tr>
<tr><td>Analytics</td><td>11 planned events, all logged, no personal data</td></tr>
<tr><td>Crashlytics</td><td>Uncaught + non-fatal with keys <code>role</code>, <code>kiosk_id</code></td></tr>
<tr><td>Remote Config</td><td>3 parameters, Home changes without a rebuild</td></tr></table>
<p class="cap">Why Cloudinary: Cloud Storage needs the Blaze plan. Details per service: docs/firebase-design.md.</p>"""))
    s.append(slide('Firebase evidence (project breakbite-1315b)', f"""
<table><tr><td>{img('evidence/storage/4-cloudinary-library.png', 330)}</td><td>{img('evidence/remote-config/2-console.png', 330)}</td></tr>
<tr><td>{img('evidence/crashlytics/1-non-fatal.png', 330)}</td><td>{img('evidence/auth/2-signed-in.png', 90)}</td></tr></table>
<p class="cap">Uploaded PDF in the Cloudinary library · Remote Config console · non-fatal error in Crashlytics · signed-in app.</p>"""))
    s.append(slide('Analytics: 11 events, each answers a question', """
<ul>
<li><b>Sign-in/out:</b> <code>login</code>, <code>logout</code> · <b>Find:</b> <code>search</code>, <code>view_menu_item</code></li>
<li><b>Order:</b> <code>add_to_cart</code>, <code>reorder</code>, <code>begin_checkout</code>, <code>purchase</code>, <code>payment_failed</code></li>
<li><b>Seller:</b> <code>order_accepted</code>, <code>order_delivered</code> · <b>Files:</b> <code>export_report</code></li>
<li><code>purchase</code> tests the success criterion (≤ 8 taps, &lt; 35 s). <code>setUserId</code> after sign-in.</li>
</ul>
<p class="warn">All 11 are logged in code and tested in ViewModels. DebugView screenshots: not collected yet.</p>"""))
    s.append(slide('Testing: what ran, what did not', f"""
<table><tr><th>Check</th><th>Result</th></tr>
<tr><td>Unit, ViewModel, widget, flow tests</td><td>{N_WIDGET_TESTS} pass (<code>flutter test</code>)</td></tr>
<tr><td>Firestore rules tests</td><td>{N_RULES_TESTS} pass</td></tr>
<tr><td>Integration vs real rules (emulators, Android emulator)</td><td>{N_INTEGRATION_TESTS} pass</td></tr>
<tr><td>ARTEMIS: 31 cases written (TC-01–TC-31)</td><td><b>Not run yet</b> (needs server, model key, device)</td></tr></table>
<p class="cap">Each ARTEMIS test asserts on the value the agent reports; results table comes from run_repeat.py (3 runs each).</p>"""))
    s.append(slide('ARTEMIS: cases and exploratory session', """
EXPLORATORY_SLIDE"""))
    s.append(slide('AI code review: 10 findings, 5 fixed', """
<table><tr><th>ID</th><th>Type</th><th>Decision</th><th>Fix</th></tr>
<tr><td>CR-01 order prices from client</td><td>security</td><td>Accepted, known limitation</td><td>—</td></tr>
<tr><td>CR-02 new item overwrites old</td><td>bug</td><td>Accepted</td><td>d6d8113</td></tr>
<tr><td>CR-03 stale incident answered twice</td><td>bug</td><td>Accepted</td><td>d1291a6</td></tr>
<tr><td>CR-04 batch over 500 writes</td><td>performance</td><td>Accepted</td><td>9243bf3</td></tr>
<tr><td>CR-05 older orders button does nothing</td><td>bug</td><td>Accepted</td><td>2980559</td></tr>
<tr><td>CR-06 time ignores seconds</td><td>bug</td><td>Accepted</td><td>ba8dc33</td></tr>
<tr><td>CR-07 – CR-10</td><td>mixed</td><td>Rejected, each with a reason</td><td>—</td></tr></table>
<p class="cap">Tool: Claude Code /code-review. Output: evidence/code-review/. Table and reasons: docs/code-review.md.</p>"""))
    s.append(slide('Challenges and lessons learned', """
<ul>
<li><b>Cloud Storage costs money</b> → Cloudinary behind the same interface; lecturer's agreement still to attach.</li>
<li><b>Check in the UI is not a rule</b> → real rules on the emulator found gaps the fakes hid (CR-01, CR-03).</li>
<li><b>Stale copies</b> → read again inside a transaction.</li>
<li><b>Write the plan first</b> → traceability and test plan before screens; every late change cost a row and a Figma edit.</li>
<li><b>An AI review is questions, not facts</b> → 4 of 10 findings rejected after reading the code.</li>
</ul>"""))
    s.append(slide('What is still missing (no evidence → not claimed)', """
<ul>
<li>ARTEMIS runs and pass-rate table (P5) · Analytics DebugView · FCM screenshots (P5)</li>
<li>Real-Firebase run of the seller screens with a staff account (P3 sets the role)</li>
<li>Receipt upload from S12 in the Cloudinary library (P2)</li>
<li>Lecturer's written confirmation (T11) · Figma update (T83) · demo video (T82)</li>
</ul>
<p class="cap">Full list with owners: report section 11.</p>"""))
    s.append(slide('Where to find everything', """
<table><tr><th>Looking for</th><th>File</th></tr>
<tr><td>Traceability and deviations</td><td><code>docs/design-traceability.md</code></td></tr>
<tr><td>Architecture</td><td><code>docs/architecture.md</code></td></tr>
<tr><td>Firebase design, analytics plan</td><td><code>docs/firebase-design.md</code>, <code>docs/analytics-plan.md</code></td></tr>
<tr><td>Test plan, ARTEMIS tests</td><td><code>docs/test-plan.md</code>, <code>e2e_test/</code></td></tr>
<tr><td>Code review</td><td><code>docs/code-review.md</code>, <code>evidence/code-review/</code></td></tr>
<tr><td>Evidence</td><td><code>evidence/</code></td></tr>
<tr><td>Demo video</td><td>link in README.md (not recorded yet)</td></tr></table>
<p class="cap">Slides and report were generated with Claude Code from these files (scripts/build_report.py).</p>"""))
    return s


EXPLORATORY = ''
EXPLORATORY_SLIDE = ''


def main():
    out_report = os.path.join(ROOT, 'report', f'Lab03_{STUDENT_ID}.pdf')
    out_slides = os.path.join(ROOT, 'slides', f'Lab03_{STUDENT_ID}_slides.pdf')
    exploratory = ''
    exploratory_slide = '<p>Not run yet.</p>'
    path = os.path.join(ROOT, 'scripts', 'exploratory.html')
    if os.path.exists(path):
        parts = open(path, encoding='utf-8').read().split('<!--SLIDE-->')
        exploratory = parts[0]
        exploratory_slide = parts[1] if len(parts) > 1 else exploratory_slide
    html = report_html().replace('EXPLORATORY_PLACEHOLDER', exploratory)
    n = write_pdf([html], REPORT_CSS, out_report, 'a4', 50, 'BreakBite · Lab 3 report')
    print('report pages', n)
    slides = [h.replace('EXPLORATORY_SLIDE', exploratory_slide) for h in slides_html()]
    m = write_pdf(slides, SLIDE_CSS, out_slides, 'a4-l', 40, 'BreakBite')
    print('slides pages', m)
    if not 8 <= n <= 12:
        print('WARNING: the report must have 8 to 12 pages', file=sys.stderr)
    if not 12 <= m <= 15:
        print('WARNING: the slides must have 12 to 15 pages', file=sys.stderr)


if __name__ == '__main__':
    main()
