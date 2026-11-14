"""Builds report/Final_SE193905.pdf, the final-assignment report (handout section 10: 10-15 pages on the changes since
Lab 3, the architecture, the data model and rules, the web admin, the cross-role flow, the AI feature, the tests, the
code review and the lessons learned, with evidence for every claim).

Run from the repo root after scripts/prepare_final_slides.py (it shares the images in slides/img-final/):
    python scripts/build_final_report.py
Needs PyMuPDF. Text is HTML in this file, in English; labels of the apps stay in Vietnamese, in quotes, with their
meaning in brackets. Every claim links to a file of the repository. Fonts: Arial from the Windows font folder (it has
the Vietnamese letters of those labels).
"""
import gc
import os

import fitz

STUDENT_ID = "SE193905"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FONT_DIR = "C:/Windows/Fonts"
REPO = "https://github.com/baonv0817/PRM393_Lab03_Group2"
WEB = "https://breakbite-1315b.web.app"

# Figures from runs (docs/test-report.md); update them when the runs are repeated.
N_RULES = 172
N_MOBILE_TESTS = 821
N_WEB_TESTS = 84

CSS = """
@font-face{font-family:AR;src:url(arial.ttf)}
@font-face{font-family:AR;font-weight:bold;src:url(arialbd.ttf)}
@font-face{font-family:AR;font-style:italic;src:url(ariali.ttf)}
@font-face{font-family:CO;src:url(cour.ttf)}
body{font-family:AR;font-size:10.5pt;line-height:1.4;color:#2B1B12}
h1{font-size:21pt;color:#622B14;margin:0 0 4pt 0}
h2{font-size:14pt;color:#622B14;margin:14pt 0 4pt 0}
h3{font-size:11pt;color:#B45309;margin:8pt 0 2pt 0}
p{margin:2pt 0 4pt 0}
ul{margin:2pt 0 4pt 0}
li{margin:0 0 2pt 0}
code{font-family:CO;font-size:9pt}
a{color:#B45309}
table{border-collapse:collapse;width:100%;margin:4pt 0 6pt 0}
td,th{border:1px solid #D6CEC4;padding:3pt 4pt;vertical-align:top;font-size:9.3pt}
th{text-align:left;color:#622B14;border-bottom:1.5px solid #B45309}
.note{background-color:#FAF8F5;border:1px solid #E4DFD8;padding:4pt 6pt;margin:4pt 0}
.cap{font-size:8.8pt;color:#6B5F55;margin:1pt 0 6pt 0}
.ok{color:#15803D;font-weight:bold}
"""


def archive():
    arch = fitz.Archive()
    arch.add(fitz.Archive(ROOT))
    if os.path.isdir(FONT_DIR):
        arch.add(fitz.Archive(FONT_DIR))
    return arch


def img(name, width):
    return f'<img src="slides/img-final/{name}.png" width="{width}"/>'


def link(path, label=None):
    return f'<a href="{REPO}/blob/main/{path}">{label or path}</a>'


def pr(n):
    return f'<a href="{REPO}/pull/{n}">#{n}</a>'


def write_pdf(html, out, footer, margin=48):
    page = fitz.paper_rect("a4")
    where = page + (margin, margin, -margin, -margin - 8)
    raw = out + ".raw"
    writer = fitz.DocumentWriter(raw)
    story = fitz.Story(html=html, user_css=CSS, archive=archive())
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
        p.insert_text((page.width - margin - 150, page.height - 16), f"{footer} · {i}/{total}", fontsize=7.5,
                      fontname="ar", fontfile=os.path.join(FONT_DIR, "arial.ttf"), color=(0.42, 0.37, 0.33))
    doc.set_metadata({"title": "BreakBite - PRM393 Final Assignment Report", "author": "PRM393 Group 2"})
    doc.save(out, garbage=3, deflate=True)
    doc.close()
    del doc
    gc.collect()
    os.remove(raw)
    return total


def report_html():
    return f"""
<h1>BreakBite · PRM393 Final Assignment Report</h1>
<p><b>One complete system on Firebase (Spark plan)</b> · Group 2 · 13 November 2026<br/>
Source code: <a href="{REPO}">{REPO}</a> · Web admin: <a href="{WEB}">{WEB}</a> ·
Demo video and demo accounts for each role: {link('README.md')}.</p>
<div class="note"><b>How to read this report.</b> Every claim that a part "works" points to a file in the repository: a test,
a screenshot in <code>evidence/</code> or a document in <code>docs/</code>. The web screenshots and all measurements were taken
on the deployed system and the real Firebase project <code>breakbite-1315b</code>. What is not done is listed in section 13
and is not written as if it were finished. Labels of the apps are quoted in Vietnamese, with their meaning in brackets.</div>

<h2>1. Changes since Lab 3</h2>
<p>Lab 3 was a Flutter Android app (folder <code>lib/</code>) for customers and kiosk staff, with its data on Firestore,
plus FCM, Analytics, Crashlytics, Remote Config and file storage on Cloudinary. The final assignment joins the Lab 2 design
and the Lab 3 app into <b>one system</b>: an Android app, a web admin and one shared Firebase backend.</p>
<table>
<tr><th>Change</th><th>What changed</th><th>Where</th></tr>
<tr><td>Repository split</td><td>Into <code>packages/core</code> (shared package), <code>mobile/</code>, <code>web/</code> and
<code>firebase/</code>. Models and repositories moved into the shared package so the web reuses them.</td>
<td>commit <code>5cd0019</code>; {link('docs/architecture.md')}</td></tr>
<tr><td>Web admin</td><td>W01–W05 for staff and admins, plus 8 system pages for admins; deployed on Firebase Hosting.</td>
<td>{pr(105)}, {pr(108)}–{pr(113)}</td></tr>
<tr><td>Notification inbox</td><td>The S19 inbox combines order status messages and the announcements an admin publishes,
updated live.</td><td>{pr(106)}</td></tr>
<tr><td>AI feature</td><td>Gemini pre-fills the dish details in K14 from a photo of the dish (level 2 of the handout).</td>
<td>{pr(96)}; {link('docs/ai-feature.md')}</td></tr>
<tr><td>Roles and rules</td><td>Three roles; only an admin changes a role; each app turns away accounts with the wrong
role. The rules tests grew from 88 to {N_RULES}.</td><td>{link('firebase/firestore.rules')}</td></tr>
<tr><td>App Check</td><td>Android uses the debug provider (debug builds) or Play Integrity; the web uses reCAPTCHA
Enterprise. Enforced for Firestore and AI Logic.</td><td>{pr(128)}; {link('docs/firebase-design.md')} section 8</td></tr>
<tr><td>Gap review closed</td><td>Every Lab 2 and Lab 3 requirement checked again; the bugs found were fixed and the missing
evidence added.</td><td>{link('docs/gap-review.md')}</td></tr>
</table>

<h2>2. Gap review: the scope of Lab 2 and Lab 3</h2>
<p>The team went through every flow, screen and requirement of Lab 2 and Lab 3 again and logged each gap as a G item (to
fix) or a V item (to verify). The full table, with evidence for each screen: {link('docs/gap-review.md')}. Result:
<b>16 of 21 items closed</b>; the 5 open items are listed in section 13.</p>
<table>
<tr><th>Item</th><th>Problem</th><th>Status</th></tr>
<tr><td>G01</td><td>S15 showed "Không tải được số đơn" (could not load the order count)</td><td>Closed: gone once the current
rules were deployed</td></tr>
<tr><td>G02</td><td>A receipt could be exported for a cancelled order that was never paid</td><td>Closed: button hidden and
export blocked ({pr(119)})</td></tr>
<tr><td>G03</td><td>"Outside opening hours" follows the phone clock</td><td>Open, see section 13</td></tr>
<tr><td>G04, G05, G06</td><td>The card of an active order could not be tapped; the label "Mã nhận tại…" was easy to mistake
for the pickup code; text was cut off at 200 % font size; status labels contradicted each other</td><td>Closed
({pr(125)}, {pr(126)})</td></tr>
<tr><td>G07</td><td>The "Âm báo đơn mới" (new order sound) switch in K10 was not built</td><td>Closed: reason recorded in D21
(Android already lets users mute the "Đơn mới" notification channel)</td></tr>
<tr><td>G08</td><td>Figma not updated with the changes to the design</td><td>Open, see section 13</td></tr>
<tr><td>G09, G10</td><td>The architecture document and a few other lines still described the Lab 3 structure</td><td>Closed
({pr(122)})</td></tr>
<tr><td>G11</td><td>README missing the names and student IDs of the team</td><td>Open: the team fills it in</td></tr>
<tr><td>G12</td><td>The AI events had no DebugView screenshot</td><td>Closed ({pr(124)})</td></tr>
<tr><td>V01, V02</td><td>Flows F6, F8 and F9 not yet run on a device</td><td>Closed: ARTEMIS TC-30 and TC-32 to TC-34, 3/3
each ({pr(127)})</td></tr>
<tr><td>V03</td><td>The offline screen S30 and a wrong code at K05 had no screenshot from a device</td><td>Closed:
{link('evidence/gap/', 'evidence/gap/')} ({pr(127)})</td></tr>
<tr><td>V04</td><td>Lab 2 flows F4, F5 and F7 not recorded in the repository</td><td>Closed: F4 to F13 in
{link('docs/design-traceability.md')} section 3</td></tr>
<tr><td>V05, V06</td><td>The phone side of the cross-role flow; enforcing App Check</td><td>Closed ({pr(128)})</td></tr>
<tr><td>V07</td><td>Cloudinary instead of Cloud Storage in the final assignment</td><td>Open: the lecturer agreed for Lab 3;
to be confirmed again for the final assignment</td></tr>
<tr><td>V08</td><td>No secrets in the git history</td><td>Closed ({pr(123)})</td></tr>
<tr><td>V09</td><td>The commits of every member visible on GitHub</td><td>Open: to check before the deadline</td></tr>
</table>

<h2>3. Architecture</h2>
<p>Both apps follow MVVM with Provider and go_router. Screens only draw the state and pass user actions to their ViewModel;
the ViewModel holds the state (loading, empty, error, data) and calls repositories and services through interfaces; only
the implementations of the repositories and services call Firebase or Cloudinary.</p>
<table>
<tr><th>Folder</th><th>Role</th></tr>
<tr><td><code>packages/core</code></td><td>Models, business rules, the repository interfaces and their Firestore
implementations, the shared Firebase services, the role check of each app, the Lab 2 theme and widgets.</td></tr>
<tr><td><code>mobile/</code></td><td>The Android app: screens S01–S30 for customers and K01–K15 for staff; the services that
need Android plugins (FCM, Crashlytics, AI Logic, image picker, PDF).</td></tr>
<tr><td><code>web/</code></td><td>The web admin: screens, ViewModels and the wiring of dependencies. No models or repositories
of its own.</td></tr>
<tr><td><code>firebase/</code></td><td>Security Rules, indexes, rules tests, the Remote Config template, the Hosting
configuration, seed and migration scripts.</td></tr>
</table>
<p>Architecture tests run with <code>flutter test</code> in both apps: screens and ViewModels may not import the Firebase
SDK, ViewModels only use <code>package:flutter/foundation.dart</code>, the shared package imports neither app, and the web
has no <code>lib/data</code> or <code>lib/domain</code> folder. Evidence: {link('mobile/test/architecture_test.dart')},
{link('web/test/architecture_test.dart')}; full description in {link('docs/architecture.md')}.</p>
<p><b>REST API.</b> Dish photos, incident photos and PDF receipts are uploaded to Cloudinary through its REST API (HTTP
POST, unsigned upload preset), with their metadata in Firestore. Cloud Storage is not used because it needs the Blaze
plan; the lecturer agreed to Cloudinary or S3 (README, section "Deviations from the handout").</p>

<h2>4. Data model and Security Rules</h2>
<p>The data has 12 collections: <code>users</code> (with <code>notifications</code> and <code>favorites</code>),
<code>kiosks</code> (with <code>slots</code>), <code>menu_items</code>, <code>vouchers</code>, <code>carts</code>,
<code>orders</code>, <code>reviews</code>, <code>incidents</code>, <code>reports</code>, <code>announcements</code> and
<code>audit_logs</code>. Each field, who may create, read, update and delete it, and which screens use it:
{link('docs/data-model.md')}.</p>
<h3>Who may do what (checked by tests)</h3>
<table>
<tr><th>Collection</th><th>Customer</th><th>Kiosk staff</th><th>Admin</th><th>Tests</th></tr>
<tr><td>users</td><td>Read and edit own profile; cannot change own role</td><td>Edit own name; cannot read customer
profiles</td><td>Change the role of other users</td><td>R-01 – R-06</td></tr>
<tr><td>notifications</td><td colspan="3">Only the owner of an inbox reads and writes it; nobody reads another user's
inbox</td><td>R-07 – R-12</td></tr>
<tr><td>kiosks, slots</td><td>Read kiosks; book a slot (+1)</td><td>Open and close own kiosk; create slots at own
kiosk</td><td>Create kiosks, change capacity</td><td>R-13 – R-24</td></tr>
<tr><td>menu_items</td><td>Read; cannot change prices</td><td>Edit and archive the items of own kiosk</td><td>Create items
at any kiosk</td><td>R-25 – R-31</td></tr>
<tr><td>vouchers</td><td>Read</td><td>Read; cannot switch a voucher off</td><td>Create, edit</td><td>R-32 – R-37</td></tr>
<tr><td>carts</td><td colspan="3">Only the owner of a cart reads and writes it</td><td>R-38 – R-43</td></tr>
<tr><td>orders</td><td>Create a pending order; cannot approve it</td><td>Approve, or reject with a reason, only at own
kiosk</td><td>Read the orders of every kiosk</td><td>R-44 – R-52</td></tr>
<tr><td>reviews</td><td>Review an order they collected</td><td>Read</td><td>Read</td><td>R-53 – R-58</td></tr>
<tr><td>incidents</td><td>Report and read own incidents</td><td>Handle the incidents of own kiosk</td><td>Reject with a
note</td><td>R-59 – R-64</td></tr>
<tr><td>reports</td><td colspan="3">The owner of a file saves and reads its metadata; nobody edits it</td><td>R-65 –
R-70</td></tr>
<tr><td>announcements</td><td>Read published ones</td><td>Read published ones; cannot publish</td><td>Write, publish,
archive</td><td>R-71 – R-80</td></tr>
</table>
<p class="cap">Nobody may delete business data (users, kiosks, slots, menu_items, vouchers, orders, reviews, incidents,
announcements): items and announcements are archived instead. The <code>audit_logs</code> are read by admins only and
written together with each change.</p>
<h3>Order lifecycle</h3>
<table>
<tr><th>From</th><th>To</th><th>Who may change it</th></tr>
<tr><td><code>pending</code></td><td><code>preparing</code></td><td>Staff of that kiosk, with an estimated ready time</td></tr>
<tr><td><code>pending</code></td><td><code>cancelled</code></td><td>The customer cancels, or kiosk staff reject it with a
reason</td></tr>
<tr><td><code>preparing</code></td><td><code>ready</code></td><td>Kiosk staff mark the food as ready</td></tr>
<tr><td><code>ready</code></td><td><code>delivered</code></td><td>Kiosk staff scan or type the pickup code</td></tr>
</table>
<h3>Principles of the rules</h3>
<ul>
<li>The last rule denies everything: <code>match /{{document=**}} {{ allow read, write: if false; }}</code>. There is no
<code>if true</code>.</li>
<li>The shape of the data is checked on create and update (<code>validNewOrder</code>, <code>validMenuItem</code>,
<code>validAnnouncement</code>…), each change of status is checked (<code>validTransition</code>), and times are server
times.</li>
<li>The role comes from <code>users/{{uid}}.role</code>. Only an admin changes a role, and nobody changes their own (R-02,
R-05). Staff only edit the orders and items of their own kiosk (R-27, R-28, R-50).</li>
</ul>
<p><b>Result:</b> <span class="ok">{N_RULES}/{N_RULES} rules tests pass</span> on the Firebase Emulator, including the matrix
of 80 allowed and denied pairs for each role on each collection. Evidence: {link('firebase/tests/rules.test.mjs')},
{link('evidence/rules/rules-run-2026-11-13.log')}; the matrix is in {link('docs/test-report.md')} section 1. The deployed
rules are the tested rules.</p>

<h2>5. Android app</h2>
<p>The app runs every Lab 2 flow on real data: quick order (F1), voucher (F2), payment error then cash (F3), editing and
cancelling an order (F4), history (F5), favourites and reorder (F6), account (F7), notifications and pickup (F8), closed
kiosk and sold-out item (F9), plus the selling flow of the staff. The table that maps each flow to its screens and test
cases: {link('docs/design-traceability.md')} section 3. The app turns away admin accounts and points them to the web
admin.</p>
<table><tr>
<td style="border:none;text-align:center">{img('s02-home', 120)}<div class="cap">Home</div></td>
<td style="border:none;text-align:center">{img('s07-tracking', 120)}<div class="cap">Order tracking</div></td>
<td style="border:none;text-align:center">{img('s19-inbox', 120)}<div class="cap">Notification inbox</div></td>
<td style="border:none;text-align:center">{img('k02-staff', 120)}<div class="cap">New orders at the kiosk</div></td>
</tr></table>

<h2>6. Web admin</h2>
<p>The web admin is written in Flutter Web, reuses the Lab 2 theme and widgets from the shared package with a layout for
wide screens, and runs at <a href="{WEB}">{WEB}</a>. Each screen was checked on the deployed site against four points: the
main action, turning away the wrong role, the empty state and the error state when offline. A screenshot for each cell:
{link('evidence/web/', 'evidence/web/')}; checklist: {link('docs/test-report.md')} section 2.</p>
<table>
<tr><th>Screen</th><th>Main action</th><th>Wrong role turned away</th></tr>
<tr><td>W01 Sign-in</td><td>Google or email</td><td>A customer account is signed out with a message</td></tr>
<tr><td>W02 Menu</td><td>Filter, add, edit, mark sold out and archive items</td><td>Staff only edit the items of their own
kiosk</td></tr>
<tr><td>W03 Review queue</td><td>Approve with a preparation time, or reject with a reason (the reasons come from Remote
Config)</td><td>Staff of another kiosk cannot approve</td></tr>
<tr><td>W04 Statistics</td><td>Aggregation queries (count, sum, average); today and the last 7 days</td><td>Staff only read
the orders of their own kiosk</td></tr>
<tr><td>W05 Announcements</td><td>Write, publish and archive announcements</td><td>Only admins can write</td></tr>
</table>
<table>
<tr><td style="border:none;text-align:center">{img('w03-queue', 235)}<div class="cap">W03 Review queue</div></td>
<td style="border:none;text-align:center">{img('w02-menu', 235)}<div class="cap">W02 Menu</div></td></tr>
<tr><td style="border:none;text-align:center">{img('w04-stats', 235)}<div class="cap">W04 Statistics</div></td>
<td style="border:none;text-align:center">{img('w05-ann', 235)}<div class="cap">W05 Published announcements</div></td></tr>
</table>
<p><b>Bugs found while checking, and fixed:</b> offline, W02 said "Kiosk chưa có món" (the kiosk has no items yet) because
Firestore returned an empty cache ({pr(110)}); an admin who switched kiosk with the review queue open still saw the queue of
the old kiosk ({pr(111)}); Hosting served the old build for an hour because of a cache header ({pr(112)}).</p>

<h2>7. Cross-role flow</h2>
<p><b>Flow 1, order:</b> the customer places an order on the phone (pending) → it appears at once in W03 of the kiosk →
staff approve it with a preparation time, or reject it with a reason → the customer's order tracking screen changes by
itself, without a reload, and the inbox gets a new message. <b>Flow 2, announcement:</b> an admin publishes in W05 → the
customer's inbox shows it at the top; archiving it removes it. Sequence diagram, related rules and how the times were
measured: {link('docs/cross-role-flow.md')}.</p>
<p>The times were measured on the deployed system: the phone was recorded with <code>screenrecord --bugreport</code> (the
phone clock is printed on each frame), the time of the click on the web came from the browser, and the offset between the
two clocks was measured separately.</p>
<table>
<tr><th>Run</th><th>On the web</th><th>The phone shows</th><th>Time</th></tr>
<tr><td>1 · order #QLOTIR</td><td>Approve, 10 minutes</td><td>Preparing · estimated ready time</td><td>1.22&nbsp;s</td></tr>
<tr><td>2 · order #25RPEH</td><td>Reject: "Quầy sắp đóng cửa" (the kiosk is closing soon)</td><td>Cancelled · with the
reason</td><td>1.09&nbsp;s</td></tr>
<tr><td>3 · order #S7SWIR</td><td>Approve, 15 minutes</td><td>Preparing · estimated ready time</td><td>1.14&nbsp;s</td></tr>
<tr><td>Flow 2</td><td>Publish an announcement</td><td>Top of the inbox</td><td>1.13&nbsp;s</td></tr>
<tr><td>Flow 2</td><td>Archive the announcement</td><td>Gone from the inbox</td><td>0.81&nbsp;s</td></tr>
</table>
<p>Evidence: {link('evidence/cross-role/measurements.json')}; the videos and the before and after screenshots are in
{link('evidence/cross-role/', 'evidence/cross-role/')}. The phone side of flow 1 is also covered by ARTEMIS TC-42 (approve)
and TC-43 (reject), 3/3 each. The second run found that a rejected cash order still promised a refund; fixed ({pr(114)}).</p>
<p>{img('x1-approved', 495)}</p>
<p class="cap">Frame of the demo video: the web has just approved order RMR1FE and the customer's phone has switched to
"Đang làm" (preparing).</p>

<h2>8. AI feature</h2>
<p>In K14, staff choose or take a photo of a dish and tap "Điền bằng AI" (fill with AI). The photo goes to Gemini
(<code>gemini-3.5-flash-lite</code>) through Firebase AI Logic, and the answer comes back in a fixed JSON schema with the
name, category, price, preparation time and description. Design, prompt and decisions: {link('docs/ai-feature.md')}.</p>
<table>
<tr><th>Level 2 requirement</th><th>How</th><th>Evidence</th></tr>
<tr><td>Remote Config</td><td><code>ai_enabled</code> switches it on and off, <code>ai_model</code> picks the model,
<code>ai_prompt</code> is the prompt</td><td>{link('firebase/remote-config-defaults.json')}; demo video</td></tr>
<tr><td>App Check</td><td>Enforced for AI Logic (and for Firestore)</td>
<td>{link('evidence/app-check/enforced-firestore-ai-logic-2026-11-13.png', 'App Check console screenshot')}</td></tr>
<tr><td>Fallback</td><td>Quota exceeded, no network, a photo that is not food, a malformed answer: the reason is shown and
the form can still be filled in by hand</td>
<td>{link('mobile/test/ui/seller_menu/menu_item_form_ai_test.dart', 'K14 AI tests')}; ARTEMIS TC-41</td></tr>
<tr><td>No personal data</td><td>Only the photo of the dish is sent; the prompt tells the model not to describe people in
the photo</td><td>{link('docs/ai-feature.md')}</td></tr>
<tr><td>Labelled and editable</td><td>Each field filled by the AI is labelled "Gợi ý từ AI" (AI suggestion); staff edit it
before saving; a field typed by hand is never overwritten (CR-F01)</td><td>{link('evidence/ai/', 'evidence/ai/')}</td></tr>
<tr><td>Analytics events</td><td><code>ai_request</code>, <code>ai_result_accepted</code>, <code>ai_error</code></td>
<td>{link('evidence/analytics/debugview-ai-events.png', 'DebugView')}</td></tr>
</table>
<table><tr>
<td style="border:none;text-align:center">{img('k14-filled', 130)}<div class="cap">The AI fills every field from a photo of a
bánh mì</div></td>
<td style="border:none;text-align:center">{img('k14-not-food', 130)}<div class="cap">A photo that is not food</div></td>
</tr></table>
<p>{img('x3-ai-off', 495)}</p>
<p class="cap">Frame of the demo video: Remote Config has published <code>ai_enabled = false</code>, and the add item screen
on the phone no longer has the "Điền bằng AI" button.</p>
<p>ARTEMIS TC-40 (photo of a dish) and TC-41 (photo that is not food) both pass 3/3.</p>

<h2>9. Testing</h2>
<table>
<tr><th>Type</th><th>Result</th><th>Evidence</th></tr>
<tr><td>Security Rules (Emulator)</td><td class="ok">{N_RULES}/{N_RULES} pass</td>
<td>{link('evidence/rules/rules-run-2026-11-13.log')}</td></tr>
<tr><td>Web admin W01–W05</td><td>All 4 points for each screen, with screenshots</td><td>{link('docs/test-report.md')}
section 2</td></tr>
<tr><td>ARTEMIS (Google), Android device</td><td>19 scenarios, 3/3 each</td><td>{link('docs/test-plan.md')} section 3;
<code>evidence/artemis/run-*.xml</code></td></tr>
<tr><td>Cross-role flow on the real system</td><td>3 runs, 1.09–1.22 s; flow 2: 1.13 s</td>
<td>{link('docs/cross-role-flow.md')}</td></tr>
<tr><td>Unit and widget tests</td><td>{N_MOBILE_TESTS} (mobile) and {N_WEB_TESTS} (web) pass</td><td><code>flutter test</code>
in <code>mobile/</code> and <code>web/</code></td></tr>
</table>
<h3>ARTEMIS</h3>
<table>
<tr><th>Flow</th><th>Test</th><th>Runs</th><th>Pass</th></tr>
<tr><td>F1 quick order (with the <code>purchase</code> event in Logcat)</td><td>TC-03</td><td>runs 12 to 14</td><td>3/3</td></tr>
<tr><td>F2 voucher and voucher errors</td><td>TC-04</td><td>runs 31 to 33</td><td>3/3</td></tr>
<tr><td>F3 payment error, then cash</td><td>TC-05</td><td>runs 22 to 24</td><td>3/3</td></tr>
<tr><td>F6 favourites, quick reorder</td><td>TC-32, TC-33</td><td>runs 61 to 63; runs 50 to 52</td><td>3/3; 3/3</td></tr>
<tr><td>F8 food ready → inbox → pickup code</td><td>TC-34</td><td>runs 50 to 52</td><td>3/3</td></tr>
<tr><td>F9 sold out → alternative dish</td><td>TC-30</td><td>runs 53 to 55</td><td>3/3</td></tr>
<tr><td>Selling flow, from accepting an order to handing it over</td><td>TC-12</td><td>runs 37 to 39</td><td>3/3</td></tr>
<tr><td>Sign-in, sign-out, search, tabs, detail screens, file export, Remote Config</td><td>TC-01, 02, 06–10</td><td>runs 1 to
8, 34 to 36</td><td>3/3 each</td></tr>
<tr><td>AI: photo of a dish, photo that is not food</td><td>TC-40, TC-41</td><td>runs 43, 44, 46; runs 43 to 45</td><td>3/3;
3/3</td></tr>
<tr><td>Cross-role, phone side: approve, reject</td><td>TC-42, TC-43</td><td>runs 47 to 49</td><td>3/3; 3/3</td></tr>
</table>
<p>The new ARTEMIS tests (TC-30, TC-32 to TC-34, TC-42, TC-43) prepare and clean up their own data, and they check the result
against Firestore instead of trusting the agent's report. This caught two runs where the agent reported "added to cart"
while the cart was still empty. Runs that failed because the emulator was overloaded, or because the ARTEMIS model returned
a 503 error or ran out of quota, were run again; the cause of each is in {link('docs/test-plan.md')} sections 3.3 to 3.6.</p>

<h2>10. AI code review</h2>
<p>Claude Code <code>/code-review</code> (medium level) was run on the new code of the final assignment: the web admin, the
inbox, the role checks in the shared package, and the AI feature. Raw output:
{link('evidence/code-review/final/review-2026-11-13.md')}. The team checked every finding against the code; all 10 were
real.</p>
<table>
<tr><th>ID</th><th>Type</th><th>Finding</th><th>Decision</th></tr>
<tr><td>CR-F01</td><td>Bug</td><td>The AI result overwrote a field staff had just typed; "Save" could be tapped while the AI
was running</td><td>Fixed ({pr(116)})</td></tr>
<tr><td>CR-F02</td><td>Bug</td><td>A failed publish or archive in W05 showed no error; the button could be clicked
twice</td><td>Fixed ({pr(117)})</td></tr>
<tr><td>CR-F03</td><td>Security</td><td>The background push handler wrote to Firestore without App Check</td><td>Fixed
({pr(118)})</td></tr>
<tr><td>CR-F04</td><td>Bug</td><td>Admins saw "Chưa có kiosk nào" (no kiosks yet) while the list of kiosks was loading; query
errors were swallowed</td><td>Fixed ({pr(117)})</td></tr>
<tr><td>CR-F05</td><td>Security</td><td>A release build given a debug token would use the App Check debug provider</td>
<td>Fixed ({pr(118)})</td></tr>
<tr><td>CR-F06</td><td>Bug</td><td>The photo was uploaded before the duplicate-name check, which left unused images on
Cloudinary</td><td>Fixed ({pr(116)})</td></tr>
<tr><td>CR-F07</td><td>Performance</td><td>"Đọc hết" (mark all as read) saved the notifications one by one</td><td>Fixed
({pr(118)})</td></tr>
<tr><td>CR-F08</td><td>Limitation</td><td>The 50 newest announcements are fetched before filtering by kiosk</td><td>Not fixed:
there are only a few announcements a week, and a correct fix needs two queries. Recorded as a known limitation</td></tr>
<tr><td>CR-F09</td><td>Maintenance</td><td>The length limits of K14 were declared in two places</td><td>Fixed
({pr(116)})</td></tr>
<tr><td>CR-F10</td><td>Maintenance</td><td>The account labels were written twice, once in the web app and once in the
mobile app</td><td>Fixed ({pr(117)})</td></tr>
</table>

<h2>11. Security</h2>
<ul>
<li><b>Permissions on the server:</b> every permission is in the Security Rules (section 4); the apps only hide what a role
may not do.</li>
<li><b>App Check is enforced</b> for Firestore and AI Logic. Android uses the debug provider (debug builds only, CR-F05) with
a token registered in the console; the web uses reCAPTCHA Enterprise. Before enforcing it, the metrics of the last 7 days
showed 80% of the requests verified, and the rest came from old builds of the app. After enforcing it, the phone still loaded
Home and wrote the cart, and the web read Firestore 9 times out of 9. {link('docs/firebase-design.md')} section 8.</li>
<li><b>No secrets in the repository:</b> a scan of the whole git history (298 commits) found no API keys, service account
keys, tokens or passwords. What is committed on purpose (the Firebase API key, the unsigned Cloudinary upload preset, the
reCAPTCHA site key) is explained in {link('evidence/security/secret-scan-2026-11-13.md')}.</li>
<li><b>Keys and passwords outside the repository:</b> the App Check debug token in <code>mobile/env/app_check.json</code>
(gitignored), the model keys of ARTEMIS in the <code>.env</code> of the ARTEMIS server, and the passwords of the demo
accounts, sent to the lecturer privately.</li>
</ul>

<h2>12. Lessons learned</h2>
<ul>
<li><b>Some bugs only show up on the real system.</b> The three bugs in sections 6 and 7 (the empty cache when offline, the
review queue that did not follow the kiosk, the wrong refund promise) all passed the tests that use fake data.</li>
<li><b>Automated tests must check the real data.</b> The ARTEMIS agent sometimes reported a step as done when it was not.
Reading Firestore again after each test is what showed whether a result was real.</li>
<li><b>Look at the metrics before enforcing App Check.</b> 20% of the requests were unverified, and they came from old builds
of the app. The team checked the tokens of both apps before enforcing it, then checked again afterwards: the phone still
loaded and wrote data, and the web read Firestore 9 times out of 9.</li>
<li><b>The free plan limits the design too.</b> Without Cloud Functions, the order status messages are written by the app
while it is open, and reminding a customer to collect the food after 10 minutes is not possible yet.</li>
<li><b>Split out the shared package early.</b> The models and repositories were already separate in Lab 3, so splitting the
repository for the final assignment only meant moving folders. The web reuses the repositories and the rules, so one fix
applies to both apps.</li>
<li><b>The test environment affects the results.</b> An overloaded emulator made the app report "not responding", and one
restart from an old snapshot brought back an old build of the app. Problems of the environment have to be separated from
bugs of the app before drawing a conclusion.</li>
</ul>

<h2>13. Limitations and open items</h2>
<table>
<tr><th>Limitation</th><th>Impact</th><th>Way forward</th></tr>
<tr><td>Android not registered with Play Integrity</td><td>With App Check enforced, only debug builds with a registered
debug token can read data</td><td>Register a debug token for the grader's device; publish the app on Google Play to use Play
Integrity</td></tr>
<tr><td>No server (Spark plan)</td><td>No reminder when a customer forgets to collect the food; status messages are only
written while the app is open</td><td>Cloud Functions after moving to the Blaze plan</td></tr>
<tr><td>Opening hours follow the phone clock (G03)</td><td>A phone with the wrong time may show the kiosk as open or closed
by mistake</td><td>Check against the server time when an order is placed</td></tr>
<tr><td>CR-F08</td><td>If one kiosk has more than 50 announcements, older announcements of other kiosks may be filtered
out</td><td>Two queries, merged on the client</td></tr>
<tr><td>Figma not updated (G08)</td><td>The changes to the design (D01–D39) are only recorded in the documents</td>
<td>{link('docs/design-traceability.md')} section 5</td></tr>
<tr><td>The persona is a proto-persona</td><td>No interviews with real users yet; the goal of 35 seconds and 8 taps has not
been measured with users</td><td>Interview real users and time them</td></tr>
</table>

<h2>14. AI tools used</h2>
<table>
<tr><th>Tool</th><th>Used for</th></tr>
<tr><td>Claude Code (Claude Opus 5.5, Claude Sonnet 5.5)</td><td>Writing and fixing code, tests and documents; running and
measuring the cross-role flow; code review (<code>/code-review</code>); building the slides, the report and the demo
video. The team checked every result before adding it to the repository.</td></tr>
<tr><td>Google ARTEMIS with Gemini 3.5 Flash Lite</td><td>The UI test agent on an Android device
({link('e2e_test/README.md')})</td></tr>
<tr><td>Gemini 3.5 Flash Lite through Firebase AI Logic</td><td>The AI feature in the app (K14)</td></tr>
<tr><td>Microsoft Edge TTS (vi-VN-HoaiMyNeural)</td><td>The narration of the demo video</td></tr>
</table>
"""


def main():
    out = os.path.join(ROOT, "report", f"Final_{STUDENT_ID}.pdf")
    n = write_pdf(report_html(), out, "BreakBite · PRM393 final report")
    print(out, n, "pages")
    if not 10 <= n <= 15:
        print("WARNING: the handout asks for 10 to 15 pages")


if __name__ == "__main__":
    main()
