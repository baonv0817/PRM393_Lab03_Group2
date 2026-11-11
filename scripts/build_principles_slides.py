"""Builds slides/Lab03_<StudentID>_principles.pdf: slides that explain how each cloud service in BreakBite works.

Run from the repo root:  python scripts/build_principles_slides.py
Needs PyMuPDF (`pip install pymupdf`). Content comes from docs/tech-explained.md; screenshots from evidence/.
The speaking notes are in slides/principles-script.md.
"""
import gc
import os

import fitz

STUDENT_ID = 'SE193905'
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
FONT_DIR = 'C:/Windows/Fonts'
OUT = os.path.join(ROOT, 'slides', f'Lab03_{STUDENT_ID}_principles.pdf')

CSS = """
@font-face{font-family:AR;src:url(arial.ttf)}
@font-face{font-family:AR;font-weight:bold;src:url(arialbd.ttf)}
@font-face{font-family:CO;src:url(cour.ttf)}
body{font-family:AR;font-size:19pt;line-height:1.3;color:#222}
h1{font-size:36pt;color:#5c3317;margin:0 0 8pt 0}
h2{font-size:30pt;color:#5c3317;margin:0 0 10pt 0}
p{margin:2pt 0 5pt 0}
li{margin:0 0 8pt 0}
code{font-family:CO;font-size:14.5pt}
table{border-collapse:collapse;width:100%}
td,th{vertical-align:top;font-size:16pt}
.q td,.q th{font-size:14pt}
th{background-color:#f3e3cf;text-align:left;border:1px solid #c9a77c;padding:4pt 6pt}
.q td{border:1px solid #c9a77c;padding:3pt 5pt}
.box{background-color:#fdeccf;border:1px solid #e0a040;padding:8pt 8pt;text-align:center;font-size:15.5pt;font-weight:bold;color:#5c3317}
.box2{background-color:#e8f1ea;border:1px solid #6aa07a;padding:8pt 6pt;text-align:center;font-size:14.5pt;font-weight:bold;color:#1a5c3a}
.arr{text-align:center;font-size:20pt;color:#a65c14;width:24pt}
.cap{font-size:12pt;color:#666;text-align:center}
.key{background-color:#fff4d6;border:1px solid #d9b44a;padding:6pt 10pt;font-size:17pt}
.big{font-size:19pt}
"""


def archive():
    arch = fitz.Archive()
    arch.add(fitz.Archive(ROOT))
    if os.path.isdir(FONT_DIR):
        arch.add(fitz.Archive(FONT_DIR))
    return arch


def flow(steps, cls='box'):
    """A row of boxes joined by arrows."""
    cells = f'<td class="arr">→</td>'.join(f'<td class="{cls}">{s}</td>' for s in steps)
    return f'<table><tr>{cells}</tr></table>'


def shot(path, width, caption=''):
    cap = f'<p class="cap">{caption}</p>' if caption else ''
    return f'<img src="{path}" width="{width}"/>{cap}'


def two(left, right, wl=52, wr=48):
    return (f'<table><tr><td style="width:{wl}%;padding-right:12pt">{left}</td>'
            f'<td style="width:{wr}%">{right}</td></tr></table>')


SLIDES = []

SLIDES.append("""
<h1>BreakBite: các dịch vụ đám mây<br/>hoạt động như thế nào</h1>
<p class="big">Firebase Authentication · Cloud Firestore · Cloudinary · FCM · Analytics · Crashlytics · Remote Config</p>
<p style="margin-top:30pt">Mỗi dịch vụ được trả lời cùng một bộ câu hỏi:</p>
<ul><li>là gì và ai chạy ở đâu</li><li>dữ liệu lưu ở đâu</li><li>app (client) làm gì</li><li>code nằm ở đâu, và khi lỗi thì sao</li></ul>
<p style="margin-top:30pt;color:#666">Nguyễn Hoàng An · SE193905 · Nhóm BreakBite · PRM393 Lab 3</p>
""")

SLIDES.append(f"""
<h2>Bức tranh tổng thể: không có server riêng của nhóm</h2>
{flow(['Màn hình<br/>(widgets)', 'ViewModel<br/>(trạng thái)', 'Repository /<br/>Service'])}
<p></p>
<table><tr><td class="arr" style="text-align:left;width:50%">↓ Service nói chuyện trực tiếp với các dịch vụ</td></tr></table>
{flow(['Auth', 'Firestore<br/>+ Rules', 'FCM', 'Analytics', 'Crashlytics', 'Remote<br/>Config', 'Cloudinary'], 'box2')}
<ul style="margin-top:14pt">
<li>Firebase (gói Spark, project <code>breakbite-1315b</code>) giữ danh tính, dữ liệu, thông báo, đo lường, lỗi và cấu hình.</li>
<li>Cloud Storage cần gói trả phí, nên tệp PDF đi qua <b>Cloudinary</b> (thầy đã cho phép).</li>
<li>Quy tắc bảo vệ dữ liệu chạy <b>trên máy chủ Firebase</b>, không nằm trong app.</li>
</ul>
""")

SLIDES.append(f"""
<h2>1. Firebase Authentication: Google xác minh, Firebase cấp phiên</h2>
{flow(['Hộp chọn tài khoản<br/>Google', 'Google ID token', 'signInWithCredential', 'Firebase ID token<br/>(JWT ~1 giờ) + refresh token'])}
<ul style="margin-top:14pt">
<li>App <b>không giữ mật khẩu</b>. SDK giữ token trên máy và tự làm mới khi hết hạn.</li>
<li><b>Vì sao cần SHA-1:</b> Google chỉ trả token cho app có chứng chỉ ký đã đăng ký trong project. Mỗi máy build debug có SHA-1 riêng.</li>
<li><code>authStateChanges()</code> phát ra người dùng hiện tại; router chuyển giữa đăng nhập, Trang chủ và app bếp theo <code>role</code> trong <code>users/{{uid}}</code>.</li>
<li>Phía server: Firestore Rules đọc <code>request.auth.uid</code> lấy từ ID token để biết ai đang gọi.</li>
</ul>
<p class="cap" style="text-align:left">Code: <code>firebase_auth_service.dart</code>, <code>router.dart</code> (authRedirect)</p>
""")

SLIDES.append(f"""
<h2>2. Cloud Firestore và Security Rules</h2>
{flow(['App<br/>snapshots()', 'Máy chủ Firebase<br/><b>Rules</b> kiểm từng yêu cầu', 'Firestore<br/>users · orders · menu · reports'], 'box')}
<ul style="margin-top:12pt">
<li><b>Thời gian thực:</b> màn hình lắng nghe <code>snapshots()</code>; bếp báo hết món thì khách thấy ngay, không cần tải lại. Có bộ nhớ đệm khi mất mạng.</li>
<li><b>Rules:</b> deny mặc định; khách chỉ đọc ghi dữ liệu của mình; nhân viên chỉ làm việc ở kiosk của mình. <b>88 test rules</b> bảo đảm điều này.</li>
<li><b>Transaction:</b> đặt, sửa, huỷ đơn và từng bước của bếp chạy trong một transaction để hai người cùng sửa không ghi đè nhau.</li>
<li><b>Index:</b> truy vấn lọc nhiều trường cần index tổng hợp (16 index trong <code>firestore.indexes.json</code>). Chạy trên Firestore thật mới thấy lỗi thiếu index; Emulator không đòi.</li>
</ul>
<p class="cap" style="text-align:left">Code: <code>firebase/firestore.rules</code>, <code>lib/data/repositories/firestore/</code></p>
""")

SLIDES.append(f"""
<h2>3. Lưu tệp: Cloudinary thay Cloud Storage</h2>
{flow(['App tạo PDF', 'HTTP multipart<br/>+ upload preset không ký', 'Cloudinary', 'Trả URL'])}
<p></p>
<table><tr><td class="arr" style="text-align:left">↓ app lưu URL, tên tệp, dung lượng vào Firestore <code>reports</code> (chỉ chủ sở hữu đọc được)</td></tr></table>
<ul style="margin-top:12pt">
<li><b>Preset không ký</b> nghĩa là app không giữ khoá bí mật nào; nếu giữ khoá trong app thì ai tải app cũng lấy được. Giới hạn nằm ở cấu hình preset trong Cloudinary.</li>
<li>Giao diện <code>StorageService</code> cho phép đổi sang S3 mà không sửa màn hình.</li>
<li>Lỗi được xử lý riêng: chưa cấu hình, lớn hơn 5 MB, mất mạng, quá thời gian; luôn bấm thử lại được.</li>
</ul>
<p class="cap" style="text-align:left">Code: <code>cloudinary_storage_service.dart</code>, <code>lib/data/services/pdf/</code></p>
""")

SLIDES.append(f"""
<h2>4. FCM: token là gì và tin được gửi như thế nào</h2>
{flow(['App xin token<br/>getToken()', 'Ghi vào Firestore<br/>users/uid.fcmTokens', 'Bên gửi (Console hoặc<br/>Admin SDK) đọc token', 'FCM → Play Services<br/>→ thiết bị'])}
<ul style="margin-top:12pt">
<li><b>Token FCM</b> định danh <b>một bản cài app trên một thiết bị</b>. Do FCM cấp qua Google Play Services; có thể đổi (cài lại, xoá dữ liệu) nên app nghe <code>onTokenRefresh</code>.</li>
<li><b>Client có lưu:</b> có, tối đa 5 thiết bị mỗi người (rules cũng giới hạn 5); gỡ token khi đăng xuất.</li>
<li><b>Muốn gửi tin</b> phải có một bên “server” gọi FCM HTTP v1 kèm token và nội dung. Ở đây: <b>Firebase Console → Send test message</b>, hoặc script <code>send-push.mjs</code> dùng Admin SDK.</li>
<li>Hệ thống thật sẽ đặt đoạn gửi này ở máy chủ hoặc Cloud Functions, kích hoạt khi bếp đổi trạng thái đơn.</li>
</ul>
""")

SLIDES.append(f"""
<h2>FCM: ba trạng thái của app khi nhận tin</h2>
<table><tr>
<td style="width:33%;text-align:center">{shot('evidence/fcm/2-foreground.png', 148)}<p><b>Đang mở</b><br/><code>onMessage</code></p></td>
<td style="width:33%;text-align:center">{shot('evidence/fcm/3-background.png', 148)}<p><b>Chạy nền</b><br/>handler nền của app</p></td>
<td style="width:33%;text-align:center">{shot('evidence/fcm/4-terminated-after-fix.png', 148)}<p><b>Đã đóng</b><br/>hệ thống hiện, chạm → <code>getInitialMessage</code></p></td>
</tr></table>
<p class="key">Cả ba đều lưu vào hộp thông báo, và <code>PushRouter</code> mở đúng đơn khi chạm. Android 13+ phải xin quyền; bị từ chối thì app vẫn chạy, chỉ không có thông báo hệ thống.</p>
""")

SLIDES.append(f"""
<h2>5. Firebase Analytics: đo hành vi bằng sự kiện</h2>
{two('''
<ul>
<li>App gọi <code>logEvent(tên, tham số)</code>; kế hoạch <b>11 sự kiện</b>, mỗi sự kiện trả lời một câu hỏi sản phẩm.</li>
<li>SDK gom sự kiện trên máy và gửi <b>theo lô</b>, nên báo cáo thường chậm.</li>
<li><b>DebugView</b> hiện ngay khi bật chế độ debug:<br/><code>adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite</code></li>
<li><code>setUserId(uid)</code> sau khi đăng nhập; không đưa tên hay e-mail vào tham số.</li>
<li>Lỗi khi ghi sự kiện không bao giờ làm hỏng luồng chính.</li>
</ul>''', shot('evidence/analytics/debugview-timeline.png', 380, 'DebugView: các sự kiện của một phiên'), 46, 54)}
<p class="cap" style="text-align:left">Code: <code>firebase_analytics_service.dart</code>, <code>analytics_events.dart</code>; kế hoạch: <code>docs/analytics-plan.md</code></p>
""")

SLIDES.append(f"""
<h2>6. Crashlytics: báo cáo lưu trên máy, gửi ở lần mở sau</h2>
{flow(['App sập', 'SDK ghi báo cáo<br/>vào bộ nhớ máy', 'Lần mở app kế tiếp', 'Gửi lên Console'])}
<ul style="margin-top:14pt">
<li><b>Vì sao Console cập nhật chậm:</b> báo cáo chỉ được gửi ở lần mở app kế tiếp.</li>
<li><b>Hai nhóm bắt:</b> lỗi Flutter chưa bắt (<code>FlutterError.onError</code>, <code>PlatformDispatcher.onError</code>) cùng crash gốc Android; và lỗi đã bắt nhưng đáng ghi (mất mạng, ghi thất bại) được ghi là <b>non-fatal</b> qua <code>recordNonFatal</code>.</li>
<li><b>Ngữ cảnh gửi kèm:</b> khoá <code>role</code>, <code>kiosk_id</code> và <code>uid</code> để biết ai gặp lỗi.</li>
<li><b>Demo:</b> Cá nhân → Khu demo Firebase → “Crashlytics test error” và “test crash” (có hỏi xác nhận trước khi sập).</li>
</ul>
<p class="cap" style="text-align:left">Code: <code>firebase_crash_service.dart</code>, <code>firebase_setup.dart</code></p>
""")

SLIDES.append(f"""
<h2>7. Remote Config: đổi hành vi app mà không build lại</h2>
{flow(['Console: sửa giá trị<br/>và Publish', 'onConfigUpdated<br/>(kênh thời gian thực)', 'App fetch + activate', 'Giao diện đổi ngay'])}
<ul style="margin-top:14pt">
<li>Tham số nằm <b>trên server</b>; app có giá trị mặc định (khớp <code>remote-config-defaults.json</code>).</li>
<li>Khoảng lấy tối thiểu 1 giờ (0 khi debug); <code>onConfigUpdated</code> giúp áp dụng ngay khi bấm Publish.</li>
<li><b>Ba tham số:</b> <code>quick_items_limit</code> (số món nhanh trên Home), <code>promo_banner_enabled</code> (banner Giờ Vàng), <code>pickup_slot_enabled</code> (chọn giờ nhận).</li>
<li>Mất mạng thì dùng giá trị cuối cùng, hoặc mặc định trong app ở lần mở đầu.</li>
</ul>
<p class="cap" style="text-align:left">Code: <code>firebase_remote_config_service.dart</code>, <code>home_view_model.dart</code></p>
""".replace('</ul>\n<p class="cap"', '</ul>\n<p class="cap"', 1))

SLIDES.append(f"""
<h2>8. MVVM và Provider: giao diện không gọi SDK</h2>
{flow(['Widget<br/>chỉ vẽ', 'ViewModel<br/>ViewState: tải · có dữ liệu · rỗng · lỗi', 'Repository / Service<br/>mới biết Firebase'])}
<ul style="margin-top:14pt">
<li><b>Vì sao:</b> thay Firebase bằng dịch vụ giả để kiểm thử (<code>dev/fakes/</code>), đổi Cloud Storage sang Cloudinary mà không sửa màn hình, và hơn 750 test widget chạy không cần thiết bị.</li>
<li><b>Ai bảo đảm quy tắc:</b> <code>test/architecture_test.dart</code> thất bại nếu màn hình import SDK, dùng literal màu hoặc kiểu chữ, hoặc ViewModel thiếu <code>SafeChangeNotifier</code>.</li>
<li><b>Provider:</b> cấp ViewModel và service cho cây widget; <code>context.watch</code> làm màn hình vẽ lại khi trạng thái đổi, <code>context.read</code> chỉ lấy để gọi hành động.</li>
</ul>
""")

SLIDES.append("""
<h2>Câu hỏi thường gặp và đáp ngắn</h2>
<table class="q">
<tr><th width="34%">Câu hỏi</th><th width="66%">Đáp ngắn</th></tr>
<tr><td>Token FCM là gì, ai cấp, client có lưu không?</td><td>Định danh bản cài app trên thiết bị; FCM cấp qua Play Services; app lưu vào <code>users/{uid}.fcmTokens</code></td></tr>
<tr><td>Muốn gửi tin thì làm sao?</td><td>Một “server” gọi FCM v1 kèm token: Console hoặc Admin SDK (<code>send-push.mjs</code>)</td></tr>
<tr><td>Vì sao Crashlytics không hiện ngay?</td><td>Báo cáo lưu trên máy, gửi ở lần mở app sau</td></tr>
<tr><td>Vì sao Remote Config đổi mà không build lại?</td><td>Tham số nằm trên server; app fetch rồi activate, <code>onConfigUpdated</code> báo thay đổi</td></tr>
<tr><td>Rules chạy ở đâu, biết ai gọi bằng gì?</td><td>Trên máy chủ Firebase, dựa vào <code>request.auth.uid</code> lấy từ ID token</td></tr>
<tr><td>Vì sao cần SHA-1?</td><td>Google xác minh chứng chỉ ký của app trước khi trả token đăng nhập</td></tr>
<tr><td>Vì sao dùng Cloudinary?</td><td>Cloud Storage cần gói Blaze; thầy cho phép Cloudinary hoặc S3; preset không ký nên app không giữ khoá bí mật</td></tr>
</table>
""")


def build():
    page = fitz.paper_rect('a4-l')
    where = page + (36, 28, -36, -34)
    raw = OUT + '.raw'
    writer = fitz.DocumentWriter(raw)
    for n, html in enumerate(SLIDES, 1):
        story = fitz.Story(html=html, user_css=CSS, archive=archive())
        dev = writer.begin_page(page)
        more, _ = story.place(where)
        story.draw(dev)
        writer.end_page()
        if more:
            print(f'WARNING: slide {n} overflows, shorten its text')
    writer.close()
    del writer
    gc.collect()
    doc = fitz.open(raw)
    for i, p in enumerate(doc, 1):
        p.insert_text((page.width - 90, page.height - 14), f'BreakBite · {i}/{len(doc)}', fontsize=8, color=(0.45, 0.45, 0.45))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    doc.save(OUT, garbage=3, deflate=True)
    n = len(doc)
    doc.close()
    del doc
    gc.collect()
    os.remove(raw)
    print(f'{OUT}: {n} slides')


if __name__ == '__main__':
    build()
