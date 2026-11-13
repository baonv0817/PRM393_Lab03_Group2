"""Builds report/Final_SE193905.pdf, the final-assignment report (handout section 10: 10-15 pages on the changes since
Lab 3, the architecture, the data model and rules, the web admin, the cross-role flow, the AI feature, the tests, the
code review and the lessons learned, with evidence for every claim).

Run from the repo root after scripts/prepare_final_slides.py (it shares the images in slides/img-final/):
    python scripts/build_final_report.py
Needs PyMuPDF. Text is HTML in this file; every claim links to a file of the repository. Fonts: Arial from the Windows
font folder (Vietnamese letters).
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
    doc.set_metadata({"title": "BreakBite - Báo cáo bài cuối kỳ PRM393", "author": "Nhóm 2 PRM393"})
    doc.save(out, garbage=3, deflate=True)
    doc.close()
    del doc
    gc.collect()
    os.remove(raw)
    return total


def report_html():
    return f"""
<h1>BreakBite · Báo cáo bài cuối kỳ PRM393</h1>
<p><b>Một hệ thống hoàn chỉnh trên Firebase (gói Spark)</b> · Nhóm 2 · 13/11/2026<br/>
Mã nguồn: <a href="{REPO}">{REPO}</a> · Web admin: <a href="{WEB}">{WEB}</a> ·
Video demo và tài khoản demo theo vai trò: {link('README.md')}.</p>
<div class="note"><b>Cách đọc báo cáo.</b> Mỗi ý nói rằng một phần "chạy được" đều chỉ tới một file trong repository: test,
ảnh chụp trong <code>evidence/</code> hoặc tài liệu trong <code>docs/</code>. Ảnh chụp web và các lần đo đều làm trên hệ thống
đã deploy và dự án Firebase thật <code>breakbite-1315b</code>. Những gì chưa làm được nằm ở mục 13, không viết như thể đã xong.</div>

<h2>1. Thay đổi so với Lab 3</h2>
<p>Lab 3 là một ứng dụng Android Flutter (thư mục <code>lib/</code>) cho khách và nhân viên quầy, dữ liệu trên Firestore, có
FCM, Analytics, Crashlytics, Remote Config và lưu file trên Cloudinary. Bài cuối kỳ nối thiết kế Lab 2 và ứng dụng Lab 3 thành
<b>một hệ thống</b> gồm ứng dụng Android, web admin và một backend Firebase dùng chung.</p>
<table>
<tr><th>Thay đổi</th><th>Nội dung</th><th>Ở đâu</th></tr>
<tr><td>Tách repository</td><td>Thành <code>packages/core</code> (gói dùng chung), <code>mobile/</code>, <code>web/</code>, <code>firebase/</code>.
Model và repository chuyển vào gói dùng chung để web dùng lại.</td><td>commit <code>5cd0019</code>; {link('docs/architecture.md')}</td></tr>
<tr><td>Web admin</td><td>W01–W05 cho nhân viên và quản trị viên, thêm 8 trang hệ thống cho quản trị viên; deploy lên Firebase Hosting.</td>
<td>{pr(105)}, {pr(108)}–{pr(113)}</td></tr>
<tr><td>Hộp thư nhận thông báo</td><td>Hộp thư S19 gộp thông báo trạng thái đơn và thông báo do quản trị viên đăng, cập nhật tức thì.</td><td>{pr(106)}</td></tr>
<tr><td>Tính năng AI</td><td>Gemini điền sẵn thông tin món ở K14 từ ảnh món, mức 2 của đề.</td><td>{pr(96)}; {link('docs/ai-feature.md')}</td></tr>
<tr><td>Phân quyền và rules</td><td>Ba vai trò, chỉ quản trị viên đổi vai trò; mỗi ứng dụng từ chối tài khoản sai vai trò. Bộ test rules tăng từ 88 lên {N_RULES}.</td>
<td>{link('firebase/firestore.rules')}</td></tr>
<tr><td>App Check</td><td>Android dùng debug provider (bản debug) hoặc Play Integrity; web dùng reCAPTCHA Enterprise. Đã bật bắt buộc cho Firestore và AI Logic.</td>
<td>{pr(128)}; {link('docs/firebase-design.md')} mục 8</td></tr>
<tr><td>Đóng gap review</td><td>Rà lại mọi yêu cầu của Lab 2 và Lab 3; sửa các lỗi tìm được, bổ sung minh chứng còn thiếu.</td><td>{link('docs/gap-review.md')}</td></tr>
</table>

<h2>2. Gap review: phạm vi Lab 2 và Lab 3</h2>
<p>Nhóm rà lại mọi luồng, màn hình và yêu cầu của Lab 2 và Lab 3, ghi từng chỗ thiếu thành một mục G (cần sửa) hoặc V (cần kiểm
chứng). Bảng đầy đủ, kèm bằng chứng cho từng màn hình: {link('docs/gap-review.md')}. Kết quả: <b>16/21 mục đã đóng</b>, 5 mục còn mở
được ghi ở mục 13.</p>
<table>
<tr><th>Mục</th><th>Vấn đề</th><th>Trạng thái</th></tr>
<tr><td>G01</td><td>S15 báo "Không tải được số đơn"</td><td>Đóng: hết lỗi sau khi deploy rules hiện tại</td></tr>
<tr><td>G02</td><td>Xuất được biên nhận cho đơn huỷ chưa trả tiền</td><td>Đóng: ẩn nút và chặn xuất ({pr(119)})</td></tr>
<tr><td>G03</td><td>"Ngoài giờ mở cửa" theo đồng hồ điện thoại</td><td>Mở, xem mục 13</td></tr>
<tr><td>G04, G05, G06</td><td>Thẻ đơn đang xử lý không bấm được; chữ "Mã nhận tại…" dễ nhầm với mã nhận món; chữ bị cắt khi phóng to 200 %; nhãn trạng thái mâu thuẫn</td><td>Đóng ({pr(125)}, {pr(126)})</td></tr>
<tr><td>G07</td><td>Công tắc "Âm báo đơn mới" ở K10 chưa làm</td><td>Đóng: ghi lý do ở D21 (Android đã cho tắt kênh thông báo "Đơn mới")</td></tr>
<tr><td>G08</td><td>Figma chưa cập nhật các thay đổi so với thiết kế</td><td>Mở, xem mục 13</td></tr>
<tr><td>G09, G10</td><td>Tài liệu kiến trúc và vài dòng tài liệu còn tả cấu trúc Lab 3</td><td>Đóng ({pr(122)})</td></tr>
<tr><td>G11</td><td>README thiếu tên và mã số sinh viên của nhóm</td><td>Mở: nhóm tự điền</td></tr>
<tr><td>G12</td><td>Sự kiện AI chưa có ảnh DebugView</td><td>Đóng ({pr(124)})</td></tr>
<tr><td>V01, V02</td><td>Luồng F6, F8, F9 chưa chạy trên thiết bị</td><td>Đóng: ARTEMIS TC-30, TC-32 tới TC-34, mỗi test 3/3 ({pr(127)})</td></tr>
<tr><td>V03</td><td>Màn mất mạng S30 và nhập sai mã ở K05 chưa có ảnh trên thiết bị</td><td>Đóng: {link('evidence/gap/', 'evidence/gap/')} ({pr(127)})</td></tr>
<tr><td>V04</td><td>Luồng F4, F5, F7 của Lab 2 chưa được ghi trong repository</td><td>Đóng: F4 tới F13 trong {link('docs/design-traceability.md')} mục 3</td></tr>
<tr><td>V05, V06</td><td>Phía điện thoại của luồng liên vai trò; bật bắt buộc App Check</td><td>Đóng ({pr(128)})</td></tr>
<tr><td>V07</td><td>Cloudinary thay Cloud Storage trong bài cuối kỳ</td><td>Mở: giảng viên đã đồng ý ở Lab 3, cần xác nhận lại cho bài cuối kỳ</td></tr>
<tr><td>V08</td><td>Không có secret trong lịch sử git</td><td>Đóng ({pr(123)})</td></tr>
<tr><td>V09</td><td>Commit của từng thành viên hiện trên GitHub</td><td>Mở: kiểm tra trước hạn nộp</td></tr>
</table>

<h2>3. Kiến trúc</h2>
<p>Cả hai ứng dụng theo MVVM với Provider và go_router. Màn hình chỉ vẽ trạng thái và chuyển thao tác cho ViewModel; ViewModel giữ
trạng thái (loading, rỗng, lỗi, có dữ liệu) và gọi repository hay service qua interface; chỉ phần cài đặt của repository và service
mới gọi Firebase hoặc Cloudinary.</p>
<table>
<tr><th>Thư mục</th><th>Vai trò</th></tr>
<tr><td><code>packages/core</code></td><td>Model, quy tắc nghiệp vụ, interface và bản Firestore của repository, service Firebase dùng chung,
kiểm tra vai trò cho từng ứng dụng, theme và widget của Lab 2.</td></tr>
<tr><td><code>mobile/</code></td><td>Ứng dụng Android: màn hình S01–S30 cho khách, K01–K15 cho nhân viên; các service cần plugin Android
(FCM, Crashlytics, AI Logic, chọn ảnh, tạo PDF).</td></tr>
<tr><td><code>web/</code></td><td>Web admin: màn hình, ViewModel và phần nối dependency. Không có model hay repository riêng.</td></tr>
<tr><td><code>firebase/</code></td><td>Security Rules, index, test rules, mẫu Remote Config, cấu hình Hosting, script seed và migration.</td></tr>
</table>
<p>Test kiến trúc chạy cùng <code>flutter test</code> ở cả hai ứng dụng: màn hình và ViewModel không được import SDK Firebase,
ViewModel chỉ dùng <code>package:flutter/foundation.dart</code>, gói dùng chung không import ứng dụng nào, và web không có thư mục
<code>lib/data</code> hay <code>lib/domain</code>. Minh chứng: {link('mobile/test/architecture_test.dart')},
{link('web/test/architecture_test.dart')}, mô tả đầy đủ ở {link('docs/architecture.md')}.</p>
<p><b>REST API.</b> Ảnh món, ảnh sự cố và biên nhận PDF được tải lên Cloudinary qua API REST (HTTP POST, upload preset không
ký), với metadata lưu trong Firestore. Lý do không dùng Cloud Storage: dịch vụ này cần gói Blaze; giảng viên đã đồng ý dùng
Cloudinary hoặc S3 (README, mục "Deviations from the handout").</p>

<h2>4. Mô hình dữ liệu và Security Rules</h2>
<p>Dữ liệu gồm 12 collection: <code>users</code> (kèm <code>notifications</code>, <code>favorites</code>), <code>kiosks</code> (kèm
<code>slots</code>), <code>menu_items</code>, <code>vouchers</code>, <code>carts</code>, <code>orders</code>, <code>reviews</code>,
<code>incidents</code>, <code>reports</code>, <code>announcements</code>, <code>audit_logs</code>. Từng trường, ai được tạo, đọc, sửa,
xoá và màn hình nào dùng: {link('docs/data-model.md')}.</p>
<h3>Ai được làm gì (đã kiểm bằng test)</h3>
<table>
<tr><th>Collection</th><th>Khách</th><th>Nhân viên kiosk</th><th>Quản trị viên</th><th>Test</th></tr>
<tr><td>users</td><td>Đọc, sửa hồ sơ mình; không tự đổi vai trò</td><td>Sửa tên mình; không đọc hồ sơ khách</td><td>Đổi vai trò người khác</td><td>R-01 – R-06</td></tr>
<tr><td>notifications</td><td colspan="3">Chỉ chủ hộp thư đọc và ghi; không ai đọc hộp thư người khác</td><td>R-07 – R-12</td></tr>
<tr><td>kiosks, slots</td><td>Đọc kiosk; đặt chỗ +1</td><td>Mở, đóng kiosk mình; tạo khung giờ ở kiosk mình</td><td>Tạo kiosk, đổi sức chứa</td><td>R-13 – R-24</td></tr>
<tr><td>menu_items</td><td>Đọc; không đổi giá</td><td>Sửa, lưu trữ món của kiosk mình</td><td>Tạo món ở mọi kiosk</td><td>R-25 – R-31</td></tr>
<tr><td>vouchers</td><td>Đọc</td><td>Đọc; không tắt voucher</td><td>Tạo, sửa</td><td>R-32 – R-37</td></tr>
<tr><td>carts</td><td colspan="3">Chỉ chủ giỏ đọc và ghi</td><td>R-38 – R-43</td></tr>
<tr><td>orders</td><td>Tạo đơn chờ xác nhận; không tự duyệt</td><td>Duyệt, từ chối kèm lý do, chỉ ở kiosk mình</td><td>Đọc đơn của mọi kiosk</td><td>R-44 – R-52</td></tr>
<tr><td>reviews</td><td>Đánh giá đơn đã nhận</td><td>Đọc</td><td>Đọc</td><td>R-53 – R-58</td></tr>
<tr><td>incidents</td><td>Báo và đọc sự cố của mình</td><td>Xử lý sự cố của kiosk mình</td><td>Từ chối kèm ghi chú</td><td>R-59 – R-64</td></tr>
<tr><td>reports</td><td colspan="3">Chủ file lưu và đọc metadata; không ai sửa</td><td>R-65 – R-70</td></tr>
<tr><td>announcements</td><td>Đọc bản đã đăng</td><td>Đọc bản đã đăng; không đăng</td><td>Viết, đăng, lưu trữ</td><td>R-71 – R-80</td></tr>
</table>
<p class="cap">Không ai được xoá dữ liệu nghiệp vụ (users, kiosks, slots, menu_items, vouchers, orders, reviews, incidents,
announcements): món và thông báo được lưu trữ thay vì xoá. Nhật ký <code>audit_logs</code> chỉ quản trị viên đọc, ghi cùng lúc với thay đổi.</p>
<h3>Vòng đời đơn hàng</h3>
<table>
<tr><th>Từ</th><th>Sang</th><th>Ai được đổi</th></tr>
<tr><td>Chờ xác nhận (pending)</td><td>Đang làm (preparing)</td><td>Nhân viên của đúng kiosk, kèm thời gian dự kiến</td></tr>
<tr><td>Chờ xác nhận</td><td>Đã huỷ (cancelled)</td><td>Khách tự huỷ, hoặc nhân viên kiosk từ chối kèm lý do</td></tr>
<tr><td>Đang làm</td><td>Sẵn sàng (ready)</td><td>Nhân viên kiosk báo món xong</td></tr>
<tr><td>Sẵn sàng</td><td>Hoàn tất (delivered)</td><td>Nhân viên kiosk quét hoặc nhập mã nhận món</td></tr>
</table>
<h3>Nguyên tắc của rules</h3>
<ul>
<li>Quy tắc cuối cùng cấm mọi thứ: <code>match /{{document=**}} {{ allow read, write: if false; }}</code>. Không có <code>if true</code>.</li>
<li>Kiểm tra dữ liệu đúng dạng khi tạo và sửa (<code>validNewOrder</code>, <code>validMenuItem</code>, <code>validAnnouncement</code>…)
và kiểm tra bước chuyển trạng thái (<code>validTransition</code>), giờ ghi theo server.</li>
<li>Vai trò lấy từ <code>users/{{uid}}.role</code>. Chỉ quản trị viên đổi vai trò, không ai tự đổi vai trò của mình (R-02, R-05).
Nhân viên chỉ sửa đơn và món của kiosk mình (R-27, R-28, R-50).</li>
</ul>
<p><b>Kết quả:</b> <span class="ok">{N_RULES}/{N_RULES} test rules đạt</span> trên Firebase Emulator, gồm ma trận 80 cặp được phép và
bị cấm cho từng vai trò trên từng collection. Minh chứng: {link('firebase/tests/rules.test.mjs')},
{link('evidence/rules/rules-run-2026-11-13.log')}, ma trận ở {link('docs/test-report.md')} mục 1. Rules đã deploy chính là bản đã test.</p>

<h2>5. Ứng dụng Android</h2>
<p>Ứng dụng làm đủ các luồng của Lab 2 trên dữ liệu thật: đặt nhanh (F1), mã giảm giá (F2), lỗi thanh toán rồi trả tiền mặt (F3),
sửa và huỷ đơn (F4), lịch sử (F5), yêu thích và đặt lại (F6), tài khoản (F7), thông báo và nhận món (F8), quán đóng và món hết (F9),
cùng luồng bán hàng của nhân viên. Bảng nối từng luồng với màn hình và test case: {link('docs/design-traceability.md')} mục 3.
Ứng dụng từ chối tài khoản quản trị viên và chỉ sang web admin.</p>
<table><tr>
<td style="border:none;text-align:center">{img('s02-home', 120)}<div class="cap">Trang chủ</div></td>
<td style="border:none;text-align:center">{img('s07-tracking', 120)}<div class="cap">Theo dõi đơn</div></td>
<td style="border:none;text-align:center">{img('s19-inbox', 120)}<div class="cap">Hộp thư thông báo</div></td>
<td style="border:none;text-align:center">{img('k02-staff', 120)}<div class="cap">Đơn mới của quầy</div></td>
</tr></table>

<h2>6. Web admin</h2>
<p>Web admin viết bằng Flutter Web, dùng lại theme và widget của Lab 2 từ gói dùng chung, bố cục cho màn hình rộng, chạy tại
<a href="{WEB}">{WEB}</a>. Mỗi màn được kiểm tra trên trang đã deploy theo bốn ý: thao tác chính, từ chối tài khoản sai vai trò,
trạng thái rỗng và trạng thái lỗi khi mất mạng. Ảnh của từng ô: {link('evidence/web/', 'evidence/web/')}; bảng kiểm tra:
{link('docs/test-report.md')} mục 2.</p>
<table>
<tr><th>Màn</th><th>Thao tác chính</th><th>Từ chối sai vai trò</th></tr>
<tr><td>W01 Đăng nhập</td><td>Google hoặc email</td><td>Tài khoản khách bị đăng xuất kèm thông báo</td></tr>
<tr><td>W02 Thực đơn</td><td>Lọc, thêm, sửa, tạm hết, lưu trữ món</td><td>Nhân viên chỉ sửa món của kiosk mình</td></tr>
<tr><td>W03 Duyệt đơn</td><td>Duyệt với thời gian làm, hoặc từ chối kèm lý do (lấy từ Remote Config)</td><td>Nhân viên kiosk khác không duyệt được</td></tr>
<tr><td>W04 Thống kê</td><td>Truy vấn tổng hợp count, sum, average; hôm nay và 7 ngày</td><td>Nhân viên chỉ đọc đơn của kiosk mình</td></tr>
<tr><td>W05 Thông báo</td><td>Viết, đăng, lưu trữ thông báo</td><td>Chỉ quản trị viên được viết</td></tr>
</table>
<table>
<tr><td style="border:none;text-align:center">{img('w03-queue', 235)}<div class="cap">W03 Duyệt đơn</div></td>
<td style="border:none;text-align:center">{img('w02-menu', 235)}<div class="cap">W02 Thực đơn</div></td></tr>
<tr><td style="border:none;text-align:center">{img('w04-stats', 235)}<div class="cap">W04 Thống kê</div></td>
<td style="border:none;text-align:center">{img('w05-ann', 235)}<div class="cap">W05 Thông báo đã đăng</div></td></tr>
</table>
<p><b>Lỗi tìm ra khi kiểm tra và đã sửa:</b> mất mạng thì W02 báo "Kiosk chưa có món" vì Firestore trả về bộ nhớ đệm rỗng
({pr(110)}); quản trị viên đổi kiosk khi đang mở Duyệt đơn vẫn thấy hàng chờ của kiosk cũ ({pr(111)}); Hosting giữ bản build cũ
một giờ vì header cache ({pr(112)}).</p>

<h2>7. Luồng liên vai trò</h2>
<p><b>Luồng 1, đơn hàng:</b> khách đặt đơn trên điện thoại (Chờ xác nhận) → đơn hiện ngay trong W03 của kiosk → nhân viên duyệt
với thời gian làm hoặc từ chối kèm lý do → màn Theo dõi đơn của khách tự đổi, không cần tải lại, và hộp thư có thông báo mới.
<b>Luồng 2, thông báo:</b> quản trị viên đăng ở W05 → hộp thư của khách hiện thông báo trên cùng; lưu trữ thì thông báo biến mất.
Sơ đồ tuần tự, rules liên quan và cách đo: {link('docs/cross-role-flow.md')}.</p>
<p>Thời gian được đo trên hệ thống đã deploy: điện thoại quay bằng <code>screenrecord --bugreport</code> (giờ của máy in trên từng
khung hình), giờ bấm trên web lấy từ trình duyệt, độ lệch đồng hồ đo riêng.</p>
<table>
<tr><th>Lần</th><th>Trên web</th><th>Điện thoại hiện</th><th>Thời gian</th></tr>
<tr><td>1 · đơn #QLOTIR</td><td>Duyệt, 10 phút</td><td>Đang làm · Dự kiến sẵn sàng</td><td>1,22 s</td></tr>
<tr><td>2 · đơn #25RPEH</td><td>Từ chối: "Quầy sắp đóng cửa"</td><td>Đã huỷ · kèm lý do</td><td>1,09 s</td></tr>
<tr><td>3 · đơn #S7SWIR</td><td>Duyệt, 15 phút</td><td>Đang làm · Dự kiến sẵn sàng</td><td>1,14 s</td></tr>
<tr><td>Luồng 2</td><td>Đăng thông báo</td><td>Trên cùng hộp thư</td><td>1,13 s</td></tr>
<tr><td>Luồng 2</td><td>Lưu trữ thông báo</td><td>Biến mất khỏi hộp thư</td><td>0,81 s</td></tr>
</table>
<p>Minh chứng: {link('evidence/cross-role/measurements.json')}, video và ảnh trước/sau trong
{link('evidence/cross-role/', 'evidence/cross-role/')}. Phía điện thoại của luồng 1 còn được kiểm bằng ARTEMIS TC-42 (duyệt) và
TC-43 (từ chối), mỗi test 3/3. Lần chạy thứ hai phát hiện đơn tiền mặt bị từ chối vẫn được hứa hoàn tiền; đã sửa ({pr(114)}).</p>
<p>{img('x1-approved', 495)}</p>
<p class="cap">Khung hình từ video demo: web vừa duyệt đơn RMR1FE, điện thoại khách đã đổi sang Đang làm.</p>

<h2>8. Tính năng AI</h2>
<p>Ở K14, nhân viên chọn hoặc chụp ảnh món rồi bấm "Điền bằng AI". Ảnh được gửi tới Gemini (<code>gemini-3.5-flash-lite</code>) qua
Firebase AI Logic; kết quả trả về theo một khuôn JSON cố định gồm tên, loại, giá, thời gian làm và mô tả. Thiết kế, câu lệnh và các
quyết định: {link('docs/ai-feature.md')}.</p>
<table>
<tr><th>Yêu cầu mức 2</th><th>Cách làm</th><th>Minh chứng</th></tr>
<tr><td>Remote Config</td><td><code>ai_enabled</code> bật tắt, <code>ai_model</code> chọn mô hình, <code>ai_prompt</code> là câu lệnh</td>
<td>{link('firebase/remote-config-defaults.json')}; video demo</td></tr>
<tr><td>App Check</td><td>Bật bắt buộc cho AI Logic (và Firestore)</td><td>{link('evidence/app-check/enforced-firestore-ai-logic-2026-11-13.png', 'ảnh console App Check')}</td></tr>
<tr><td>Đường lui</td><td>Hết hạn mức, mất mạng, ảnh không phải món ăn, câu trả lời sai dạng: báo lý do, form vẫn nhập tay</td>
<td>{link('mobile/test/ui/seller_menu/menu_item_form_ai_test.dart', 'test K14 AI')}; ARTEMIS TC-41</td></tr>
<tr><td>Không có dữ liệu cá nhân</td><td>Chỉ gửi ảnh món; câu lệnh dặn không nhắc tới người trong ảnh</td><td>{link('docs/ai-feature.md')}</td></tr>
<tr><td>Ghi nhãn, cho sửa</td><td>Mỗi ô có nhãn "Gợi ý từ AI"; nhân viên sửa trước khi lưu; ô đã gõ tay không bị ghi đè (CR-F01)</td><td>{link('evidence/ai/', 'evidence/ai/')}</td></tr>
<tr><td>Sự kiện Analytics</td><td><code>ai_request</code>, <code>ai_result_accepted</code>, <code>ai_error</code></td>
<td>{link('evidence/analytics/debugview-ai-events.png', 'DebugView')}</td></tr>
</table>
<table><tr>
<td style="border:none;text-align:center">{img('k14-filled', 130)}<div class="cap">AI điền đủ ô từ ảnh bánh mì</div></td>
<td style="border:none;text-align:center">{img('k14-not-food', 130)}<div class="cap">Ảnh không phải món ăn</div></td>
</tr></table>
<p>{img('x3-ai-off', 495)}</p>
<p class="cap">Khung hình từ video demo: Remote Config đã đăng <code>ai_enabled = false</code>, màn Thêm món trên điện thoại không còn nút
"Điền bằng AI".</p>
<p>ARTEMIS TC-40 (ảnh món) và TC-41 (ảnh không phải món ăn) đều đạt 3/3.</p>

<h2>9. Kiểm thử</h2>
<table>
<tr><th>Loại</th><th>Kết quả</th><th>Minh chứng</th></tr>
<tr><td>Security Rules (Emulator)</td><td class="ok">{N_RULES}/{N_RULES} đạt</td><td>{link('evidence/rules/rules-run-2026-11-13.log')}</td></tr>
<tr><td>Web admin W01–W05</td><td>Đủ 4 ý cho từng màn, có ảnh</td><td>{link('docs/test-report.md')} mục 2</td></tr>
<tr><td>ARTEMIS (Google), máy Android</td><td>19 kịch bản, mỗi kịch bản 3/3</td><td>{link('docs/test-plan.md')} mục 3; <code>evidence/artemis/run-*.xml</code></td></tr>
<tr><td>Luồng liên vai trò trên hệ thống thật</td><td>3 lần, 1,09–1,22 s; luồng 2: 1,13 s</td><td>{link('docs/cross-role-flow.md')}</td></tr>
<tr><td>Test đơn vị và widget</td><td>{N_MOBILE_TESTS} (mobile) và {N_WEB_TESTS} (web) đạt</td><td><code>flutter test</code> trong <code>mobile/</code>, <code>web/</code></td></tr>
</table>
<h3>ARTEMIS</h3>
<table>
<tr><th>Luồng</th><th>Test</th><th>Lần chạy</th><th>Đạt</th></tr>
<tr><td>F1 đặt nhanh (kèm sự kiện <code>purchase</code> trong Logcat)</td><td>TC-03</td><td>run-12 tới 14</td><td>3/3</td></tr>
<tr><td>F2 mã giảm giá và lỗi mã</td><td>TC-04</td><td>run-31 tới 33</td><td>3/3</td></tr>
<tr><td>F3 lỗi thanh toán rồi trả tiền mặt</td><td>TC-05</td><td>run-22 tới 24</td><td>3/3</td></tr>
<tr><td>F6 yêu thích, đặt lại nhanh</td><td>TC-32, TC-33</td><td>run-61 tới 63; run-50 tới 52</td><td>3/3; 3/3</td></tr>
<tr><td>F8 món sẵn sàng → hộp thư → mã nhận món</td><td>TC-34</td><td>run-50 tới 52</td><td>3/3</td></tr>
<tr><td>F9 món hết → món thay thế</td><td>TC-30</td><td>run-53 tới 55</td><td>3/3</td></tr>
<tr><td>Luồng bán hàng, nhận đến trả món</td><td>TC-12</td><td>run-37 tới 39</td><td>3/3</td></tr>
<tr><td>Đăng nhập, đăng xuất, tìm kiếm, các tab, màn chi tiết, xuất file, Remote Config</td><td>TC-01, 02, 06–10</td><td>run-1 tới 8, 34 tới 36</td><td>3/3 mỗi test</td></tr>
<tr><td>AI: ảnh món, ảnh không phải món ăn</td><td>TC-40, TC-41</td><td>run-43, 44, 46; run-43 tới 45</td><td>3/3; 3/3</td></tr>
<tr><td>Liên vai trò, phía điện thoại: duyệt, từ chối</td><td>TC-42, TC-43</td><td>run-47 tới 49</td><td>3/3; 3/3</td></tr>
</table>
<p>Các test ARTEMIS mới (TC-30, TC-32 tới TC-34, TC-42, TC-43) tự chuẩn bị và dọn dữ liệu, và đối chiếu kết quả với Firestore chứ
không chỉ tin lời agent. Cách này bắt được hai lần agent báo "đã thêm vào giỏ" trong khi giỏ hàng vẫn trống. Những lần chạy hỏng vì
máy ảo quá tải, mô hình của ARTEMIS lỗi 503 hoặc hết hạn mức được chạy lại; nguyên nhân từng lần ghi trong
{link('docs/test-plan.md')} mục 3.3 tới 3.6.</p>

<h2>10. Review code bằng AI</h2>
<p>Dùng Claude Code <code>/code-review</code> (mức medium) cho phần code mới của bài cuối kỳ: web admin, hộp thư và kiểm tra vai trò
trong gói dùng chung, tính năng AI. Kết quả gốc: {link('evidence/code-review/final/review-2026-11-13.md')}. Mỗi phát hiện được
nhóm kiểm lại với code; cả 10 đều đúng.</p>
<table>
<tr><th>Mã</th><th>Loại</th><th>Phát hiện</th><th>Quyết định</th></tr>
<tr><td>CR-F01</td><td>Lỗi</td><td>Kết quả AI ghi đè ô nhân viên vừa gõ; nút Lưu vẫn bấm được khi AI đang chạy</td><td>Sửa ({pr(116)})</td></tr>
<tr><td>CR-F02</td><td>Lỗi</td><td>W05 đăng hoặc lưu trữ lỗi mà không báo; bấm hai lần được</td><td>Sửa ({pr(117)})</td></tr>
<tr><td>CR-F03</td><td>Bảo mật</td><td>Thông báo đẩy chạy nền ghi Firestore mà chưa bật App Check</td><td>Sửa ({pr(118)})</td></tr>
<tr><td>CR-F04</td><td>Lỗi</td><td>Quản trị viên thấy "Chưa có kiosk nào" khi danh sách kiosk đang tải; lỗi truy vấn bị nuốt</td><td>Sửa ({pr(117)})</td></tr>
<tr><td>CR-F05</td><td>Bảo mật</td><td>Bản release được đưa debug token sẽ dùng debug provider của App Check</td><td>Sửa ({pr(118)})</td></tr>
<tr><td>CR-F06</td><td>Lỗi</td><td>Tải ảnh lên trước khi kiểm tra trùng tên, để lại ảnh thừa trên Cloudinary</td><td>Sửa ({pr(116)})</td></tr>
<tr><td>CR-F07</td><td>Hiệu năng</td><td>"Đọc hết" lưu từng thông báo một</td><td>Sửa ({pr(118)})</td></tr>
<tr><td>CR-F08</td><td>Giới hạn</td><td>Lấy 50 thông báo mới nhất rồi mới lọc theo kiosk</td><td>Không sửa: mỗi tuần chỉ vài thông báo; sửa đúng cần hai truy vấn. Ghi là giới hạn đã biết</td></tr>
<tr><td>CR-F09</td><td>Bảo trì</td><td>Giới hạn độ dài ở K14 khai báo hai nơi</td><td>Sửa ({pr(116)})</td></tr>
<tr><td>CR-F10</td><td>Bảo trì</td><td>Nhãn tài khoản viết hai lần ở web và mobile</td><td>Sửa ({pr(117)})</td></tr>
</table>

<h2>11. Bảo mật</h2>
<ul>
<li><b>Phân quyền ở server:</b> mọi quyền nằm trong Security Rules (mục 4); ứng dụng chỉ ẩn những gì vai trò đó không được làm.</li>
<li><b>App Check bật bắt buộc</b> cho Firestore và AI Logic. Android dùng debug provider (chỉ trong bản debug, CR-F05) với token
đăng ký trên console, web dùng reCAPTCHA Enterprise. Trước khi bật: số liệu 7 ngày cho thấy 80% yêu cầu đã xác minh, phần còn lại đến từ
bản app cũ; sau khi bật: điện thoại vẫn tải Trang chủ và ghi giỏ hàng, web đọc Firestore 9/9 lần thành công.
{link('docs/firebase-design.md')} mục 8.</li>
<li><b>Không có secret trong repository:</b> quét toàn bộ lịch sử git (298 commit) không thấy khoá API, khoá tài khoản dịch vụ, token
hay mật khẩu. Những gì cố ý commit (khoá API Firebase, upload preset không ký của Cloudinary, site key reCAPTCHA) đều được giải thích.
{link('evidence/security/secret-scan-2026-11-13.md')}.</li>
<li><b>Khoá và mật khẩu nằm ngoài repository:</b> debug token App Check trong <code>mobile/env/app_check.json</code> (gitignore), khoá
mô hình của ARTEMIS trong <code>.env</code> của máy chủ ARTEMIS, mật khẩu tài khoản demo gửi riêng cho giảng viên.</li>
</ul>

<h2>12. Bài học</h2>
<ul>
<li><b>Có những lỗi chỉ lộ ra khi chạy trên hệ thống thật.</b> Ba lỗi ở mục 6 và 7 (bộ nhớ đệm rỗng khi mất mạng, hàng chờ không
đổi theo kiosk, hứa hoàn tiền sai) đều qua được test với dữ liệu giả.</li>
<li><b>Test tự động phải đối chiếu dữ liệu thật.</b> Agent ARTEMIS đôi khi báo đã làm xong một bước mà thực tế chưa làm. Đọc lại
Firestore sau mỗi test mới biết kết quả là thật.</li>
<li><b>Xem số liệu trước khi bật App Check.</b> 20% yêu cầu chưa xác minh đến từ các bản app cũ. Nhóm kiểm tra token của cả hai
ứng dụng trước khi bật, sau đó kiểm lại: điện thoại vẫn tải và ghi dữ liệu, web đọc Firestore 9/9 lần thành công.</li>
<li><b>Gói miễn phí giới hạn cả thiết kế.</b> Không có Cloud Functions nên thông báo trạng thái đơn do ứng dụng tự ghi khi đang mở,
và việc nhắc khách lấy món sau 10 phút chưa làm được.</li>
<li><b>Tách gói dùng chung sớm.</b> Vì model và repository đã nằm riêng từ Lab 3, việc tách repository cho bài cuối kỳ chỉ là dời
thư mục; web dùng lại repository và rules nên một lần sửa có hiệu lực cho cả hai ứng dụng.</li>
<li><b>Môi trường test ảnh hưởng kết quả.</b> Máy ảo quá tải làm ứng dụng báo "không phản hồi" và một lần khởi động lại từ bản lưu cũ
đưa về bản app cũ. Cần tách lỗi môi trường khỏi lỗi của ứng dụng trước khi kết luận.</li>
</ul>

<h2>13. Giới hạn và việc còn mở</h2>
<table>
<tr><th>Giới hạn</th><th>Ảnh hưởng</th><th>Hướng xử lý</th></tr>
<tr><td>Android chưa đăng ký Play Integrity</td><td>Khi App Check đã bật bắt buộc, chỉ bản debug có debug token đã đăng ký mới đọc được dữ liệu</td>
<td>Đăng ký thêm debug token cho máy chấm; đưa ứng dụng lên Google Play để dùng Play Integrity</td></tr>
<tr><td>Không có server (gói Spark)</td><td>Không nhắc lại khi khách quên lấy món; thông báo trạng thái chỉ ghi khi ứng dụng đang mở</td><td>Cloud Functions nếu chuyển gói Blaze</td></tr>
<tr><td>Giờ mở cửa theo đồng hồ điện thoại (G03)</td><td>Điện thoại sai giờ có thể thấy quán mở hoặc đóng sai</td><td>Kiểm tra bằng giờ server khi đặt đơn</td></tr>
<tr><td>CR-F08</td><td>Một kiosk có quá 50 thông báo thì thông báo cũ của kiosk khác có thể bị lọc mất</td><td>Hai truy vấn gộp ở client</td></tr>
<tr><td>Figma chưa cập nhật (G08)</td><td>Các thay đổi so với thiết kế (D01–D39) mới ghi trong tài liệu</td><td>{link('docs/design-traceability.md')} mục 5</td></tr>
<tr><td>Persona là proto-persona</td><td>Chưa phỏng vấn người dùng thật; mục tiêu 35 giây, 8 lần chạm chưa đo với người dùng</td><td>Phỏng vấn và đo thời gian thật</td></tr>
</table>

<h2>14. Công cụ AI đã dùng</h2>
<table>
<tr><th>Công cụ</th><th>Dùng cho</th></tr>
<tr><td>Claude Code (Claude Opus 5.5, Claude Sonnet 5.5)</td><td>Viết và sửa code, test, tài liệu; chạy và đo luồng liên vai trò; review code
(<code>/code-review</code>); dựng slide, báo cáo và video demo. Nhóm kiểm lại mọi kết quả trước khi đưa vào repository.</td></tr>
<tr><td>Google ARTEMIS với Gemini 3.5 Flash Lite</td><td>Agent kiểm thử giao diện trên máy Android ({link('e2e_test/README.md')})</td></tr>
<tr><td>Gemini 3.5 Flash Lite qua Firebase AI Logic</td><td>Tính năng AI trong ứng dụng (K14)</td></tr>
<tr><td>Microsoft Edge TTS (vi-VN-HoaiMyNeural)</td><td>Giọng đọc của video demo</td></tr>
</table>
"""


def main():
    out = os.path.join(ROOT, "report", f"Final_{STUDENT_ID}.pdf")
    n = write_pdf(report_html(), out, "BreakBite · Báo cáo bài cuối kỳ")
    print(out, n, "pages")
    if not 10 <= n <= 15:
        print("WARNING: the handout asks for 10 to 15 pages")


if __name__ == "__main__":
    main()
