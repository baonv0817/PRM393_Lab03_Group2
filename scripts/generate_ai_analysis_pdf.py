import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# Register fonts that support full Vietnamese Unicode
pdfmetrics.registerFont(TTFont('SegoeUI', 'C:/Windows/Fonts/segoeui.ttf'))
pdfmetrics.registerFont(TTFont('SegoeUI-Bold', 'C:/Windows/Fonts/segoeuib.ttf'))
pdfmetrics.registerFont(TTFont('SegoeUI-Italic', 'C:/Windows/Fonts/segoeuii.ttf'))

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont('SegoeUI', 9)
        self.setFillColor(colors.HexColor('#78716C'))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 800, 'BreakBite · Phân Tích Chuyên Sâu Tính Năng Tóm Tắt Bằng AI (AI Stats Insight)')
            self.setStrokeColor(colors.HexColor('#E7E5E4'))
            self.setLineWidth(0.5)
            self.line(54, 792, 541, 792)
            
        # Footer
        self.setStrokeColor(colors.HexColor('#E7E5E4'))
        self.setLineWidth(0.5)
        self.line(54, 45, 541, 45)
        self.drawString(54, 32, 'Dự án BreakBite · PRM393 Lab 03 / Final · Nền tảng Firebase AI Logic & Gemini')
        self.drawRightString(541, 32, f'Trang {self._pageNumber} / {page_count}')
        self.restoreState()

def build_pdf(filename):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()
    
    # Custom styles with Vietnamese font
    c_primary = colors.HexColor('#F69D39')
    c_dark = colors.HexColor('#292524')
    c_muted = colors.HexColor('#57534E')
    c_bg_callout = colors.HexColor('#FFF7ED')
    c_border_callout = colors.HexColor('#FDBA74')
    c_code_bg = colors.HexColor('#F5F5F4')

    title_style = ParagraphStyle(
        'DocTitle',
        fontName='SegoeUI-Bold',
        fontSize=20,
        leading=26,
        textColor=c_dark,
        spaceAfter=6
    )
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        fontName='SegoeUI',
        fontSize=11,
        leading=16,
        textColor=c_muted,
        spaceAfter=14
    )
    h1_style = ParagraphStyle(
        'H1',
        fontName='SegoeUI-Bold',
        fontSize=13,
        leading=18,
        textColor=colors.HexColor('#9A3412'),
        spaceBefore=14,
        spaceAfter=6,
        keepWithNext=True
    )
    h2_style = ParagraphStyle(
        'H2',
        fontName='SegoeUI-Bold',
        fontSize=10.5,
        leading=15,
        textColor=c_dark,
        spaceBefore=8,
        spaceAfter=4,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'Body',
        fontName='SegoeUI',
        fontSize=9.5,
        leading=14.5,
        textColor=c_dark,
        spaceAfter=6
    )
    bullet_style = ParagraphStyle(
        'Bullet',
        fontName='SegoeUI',
        fontSize=9.5,
        leading=14,
        textColor=c_dark,
        leftIndent=14,
        firstLineIndent=-10,
        spaceAfter=3
    )
    callout_style = ParagraphStyle(
        'Callout',
        fontName='SegoeUI',
        fontSize=9,
        leading=13.5,
        textColor=colors.HexColor('#7C2D12')
    )
    table_cell = ParagraphStyle(
        'TableCell',
        fontName='SegoeUI',
        fontSize=8.5,
        leading=12,
        textColor=c_dark
    )
    table_header = ParagraphStyle(
        'TableHeader',
        fontName='SegoeUI-Bold',
        fontSize=8.5,
        leading=12,
        textColor=colors.white
    )

    story = []

    # Title & Header
    story.append(Paragraph('BÁO CÁO PHÂN TÍCH CHUYÊN SÂU TÍNH NĂNG "TÓM TẮT BẰNG AI"', title_style))
    story.append(Paragraph('Cơ chế hoạt động, nguồn số liệu, thuật toán trích xuất và quy tắc suy luận quyết định trên BreakBite Web Admin (A08)', subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primary, spaceBefore=0, spaceAfter=12))

    # Executive Summary Callout
    callout_data = [[
        Paragraph(
            '<b>Tóm lược tính năng:</b> Nút <b>"Tạo tóm tắt"</b> (AI Stats Insight) tại trang Thống kê (<code>/system/stats</code>) của Web Admin '
            'kết nối trực tiếp với <b>Google Gemini Developer API</b> thông qua <b>Firebase AI Logic</b>. Hệ thống tổng hợp toàn bộ các giao dịch '
            'trong phạm vi thời gian (7, 14, hoặc 30 ngày) thành văn bản thống kê có cấu trúc chuẩn (Stats Digest), sau đó dùng mô hình sinh ra '
            '<b>3 - 4 kết luận sắc bén và hành động cụ thể</b> cho người quản trị căng tin.',
            callout_style
        )
    ]]
    callout_table = Table(callout_data, colWidths=[487])
    callout_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), c_bg_callout),
        ('BOX', (0,0), (-1,-1), 1, c_border_callout),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(callout_table)
    story.append(Spacer(1, 10))

    # SECTION 1
    story.append(Paragraph('1. AI DỰA TRÊN ĐIỀU GÌ? (Bối cảnh & Nguồn dữ liệu)', h1_style))
    story.append(Paragraph(
        'Tính năng <b>"Tóm tắt bằng AI"</b> không tự ý bịa ra số liệu hay tham chiếu nguồn dữ liệu bên ngoài. '
        'Nó hoạt động dựa trên nguyên tắc <b>Grounding 100%</b> vào dữ liệu vận hành thực tế được trích xuất từ Firestore qua hàm chuẩn hóa '
        '<code>statsDigest()</code> (tại <code>packages/core/lib/domain/stats_digest.dart</code>).',
        body_style
    ))
    story.append(Paragraph('Cụ thể, AI đọc trực tiếp các nhóm số liệu sau:', body_style))
    story.append(Paragraph('• <b>Số lượng & Trạng thái đơn hàng:</b> Tổng số đơn được tạo, số đơn giao thành công, số đơn bị hủy và số đơn đang chế biến.', bullet_style))
    story.append(Paragraph('• <b>Dòng tiền & Doanh thu:</b> Tổng doanh thu (VND), giá trị trung bình trên mỗi đơn hàng (AOV - Average Order Value).', bullet_style))
    story.append(Paragraph('• <b>Hiệu suất chế biến:</b> Thời gian hoàn thành món trung bình (tính bằng phút) từ lúc nhận đơn đến khi giao khách.', bullet_style))
    story.append(Paragraph('• <b>So sánh chu kỳ trước (Period-over-Period):</b> Biến động % tăng/giảm về số lượng đơn, doanh thu và tỷ lệ hủy so với khoảng thời gian tương đương ngay trước đó.', bullet_style))
    story.append(Paragraph('• <b>Phân bổ tải theo giờ (Rush Hours):</b> Top 3 khung giờ có lượng đơn tập trung cao nhất trong ngày.', bullet_style))
    story.append(Paragraph('• <b>Hiệu quả từng Kiosk & Món ăn bán chạy:</b> Doanh thu và tỷ lệ hủy của từng quầy cơ sở, top 5 món có sản lượng tiêu thụ lớn nhất.', bullet_style))

    story.append(Spacer(1, 8))

    # SECTION 2
    story.append(Paragraph('2. VÌ SAO VÀ NGUYÊN NHÂN RA ĐỜI? (Why & Motivation)', h1_style))
    story.append(Paragraph(
        'Trong hệ thống căng tin trường học nhiều quầy, người quản trị thường gặp phải các trở ngại lớn khi theo dõi thống kê thủ công:',
        body_style
    ))
    
    why_table_data = [
        [Paragraph('Vấn đề thực tế của Admin', table_header), Paragraph('Cách AI Stats Insight giải quyết', table_header)],
        [
            Paragraph('<b>Quá tải nhận thức:</b> Trang thống kê có hàng chục biểu đồ cột, biểu đồ đường, bảng dữ liệu khiến admin mất 5-10 phút để nhận diện vấn đề cốt lõi.', table_cell),
            Paragraph('<b>Cô đọng tức thì:</b> Chuyển đổi toàn bộ biểu đồ phức tạp thành đúng 3-4 gạch đầu dòng cô đọng trong chưa đầy 2 giây.', table_cell)
        ],
        [
            Paragraph('<b>Bỏ sót dấu hiệu bất thường:</b> Tỷ lệ hủy đơn ngầm tăng ở một quầy hoặc một khung giờ cao điểm thường bị che lấp bởi doanh thu tổng.', table_cell),
            Paragraph('<b>Chỉ điểm rủi ro:</b> AI được nhắc chuyên biệt để tìm "điều đáng lo" (như tỷ lệ hủy >15% hoặc khung giờ tắc nghẽn).', table_cell)
        ],
        [
            Paragraph('<b>Thiếu đề xuất hành động:</b> Biểu đồ chỉ cho biết "chuyện gì đã xảy ra" chứ không chỉ ra "cần làm gì tiếp theo".', table_cell),
            Paragraph('<b>Hành động cụ thể:</b> Luôn kết luận bằng một hành động thực tế có thể thực thi ngay (ví dụ: tăng ca 11h-12h, kiểm kho món X).', table_cell)
        ]
    ]
    t_why = Table(why_table_data, colWidths=[240, 247])
    t_why.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#9A3412')),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor('#D6D3D1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E7E5E4')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_why)

    story.append(Spacer(1, 10))

    # SECTION 3
    story.append(Paragraph('3. CƠ CHẾ BẢO MẬT & DỮ LIỆU ĐƯỢC GỬI ĐI (Security & Privacy Contract)', h1_style))
    story.append(Paragraph(
        'Hệ thống tuân thủ nghiêm ngặt chính sách bảo vệ dữ liệu cá nhân (handout section 8 & docs/ai-feature.md):',
        body_style
    ))
    story.append(Paragraph('• <b>KHÔNG gửi thông tin định danh:</b> Tuyệt đối không gửi tên khách hàng, email, UID, số điện thoại hay Order ID sang Gemini API.', bullet_style))
    story.append(Paragraph('• <b>Dữ liệu thuần văn bản tổng hợp:</b> AI chỉ nhận các con số gộp (aggregations) và danh từ món ăn/quầy hàng.', bullet_style))
    story.append(Paragraph('• <b>App Check & Quản lý Key an toàn:</b> Gemini API Key được giữ và bảo vệ tại máy chủ Firebase. Ứng dụng client không lưu API key mà xác thực qua App Check token.', bullet_style))

    story.append(Spacer(1, 8))

    # SECTION 4
    story.append(Paragraph('4. PROMPT HỆ THỐNG VÀ QUY TẮC ĐƯA RA KẾT LUẬN', h1_style))
    story.append(Paragraph(
        'Hệ thống điều khiển hành vi của Gemini thông qua tham số Remote Config <code>ai_insight_prompt</code> '
        '(có thể điều chỉnh trực tiếp từ xa mà không cần build lại app):',
        body_style
    ))

    prompt_box = [[
        Paragraph(
            '<i>"Bạn là trợ lý phân tích bán hàng cho quản trị viên hệ thống căng tin trong trường đại học ở Việt Nam. '
            'Bạn nhận số liệu của một khoảng thời gian. Viết bằng tiếng Việt, đúng 3 đến 4 gạch đầu dòng ngắn: '
            'điều đáng chú ý nhất, điều đáng lo (nếu có), và một việc nên làm. '
            'Chỉ dùng số trong dữ liệu, không bịa số, không nhắc tên khách. Nếu số đơn quá ít để kết luận thì nói rõ."</i>',
            callout_style
        )
    ]]
    t_prompt = Table(prompt_box, colWidths=[487])
    t_prompt.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F5F5F4')),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#D6D3D1')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_prompt)
    story.append(Spacer(1, 6))

    story.append(Paragraph('<b>Cấu trúc 4 phần của một kết luận chuẩn:</b>', h2_style))
    story.append(Paragraph('<b>1. Điểm nổi bật nhất (Bright spot):</b> Nêu tốc độ tăng trưởng doanh thu hoặc món chủ lực kéo doanh số (VD: Cơm gà sốt teriyaki dẫn đầu với 35% doanh thu).', bullet_style))
    story.append(Paragraph('<b>2. Điểm cảnh báo rủi ro (Risk alert):</b> Tỷ lệ hủy tăng đột biến hoặc quầy nào đang có thời gian chờ chế biến vượt ngưỡng 15 phút.', bullet_style))
    story.append(Paragraph('<b>3. Khung giờ nóng (Capacity bottleneck):</b> Cảnh báo nguy cơ quá tải trong khung 11h-12h trưa khi học sinh tan lớp.', bullet_style))
    story.append(Paragraph('<b>4. Đề xuất hành động tức thì (Prescriptive action):</b> Khuyên admin điều chuyển nhân sự, chuẩn bị sơ chế trước món hot hoặc kiểm tra lại nguyên liệu của quầy có tỷ lệ hủy cao.', bullet_style))

    story.append(Spacer(1, 8))

    # SECTION 5
    story.append(Paragraph('5. VÍ DỤ MINH HỌA THỰC TẾ TRÊN HỆ THỐNG', h1_style))
    
    eg_data = [
        [Paragraph('Dữ liệu đầu vào (Stats Digest)', table_header), Paragraph('Kết luận AI sinh ra trên giao diện', table_header)],
        [
            Paragraph(
                'Phạm vi: Mọi kiosk, 7 ngày gần nhất.<br/>'
                'Số đơn: 142 (đã giao 128, huỷ 14).<br/>'
                'Doanh thu: 4.820.000 đồng.<br/>'
                'Tỉ lệ huỷ: 10%.<br/>'
                'So với 7 ngày trước: doanh thu tăng 18%, số đơn tăng 12%.<br/>'
                'Giờ đông nhất: 11h (42 đơn), 12h (38 đơn).<br/>'
                'Món bán chạy: Bánh mì pate (68 phần), Trà đào (45 phần).',
                table_cell
            ),
            Paragraph(
                '• <b>Tăng trưởng tích cực:</b> Doanh thu 7 ngày qua đạt 4,82 triệu đồng, tăng 18% so với tuần trước nhờ sản lượng bánh mì pate đạt 68 phần.<br/>'
                '• <b>Tập trung cao điểm trưa:</b> Lượng đơn dồn 56% vào khung 11h-12h (tổng 80 đơn), dễ gây ùn tắc tại quầy nhận món.<br/>'
                '• <b>Tỷ lệ hủy ở mức 10%:</b> 14 đơn bị hủy chủ yếu do hết nguyên liệu giờ cao điểm.<br/>'
                '• <b>Hành động:</b> Chuẩn bị sẵn topping bánh mì trước 10h45 và bổ sung thêm 1 nhân viên hỗ trợ giao đơn từ 11h-12h30.',
                table_cell
            )
        ]
    ]
    t_eg = Table(eg_data, colWidths=[230, 257])
    t_eg.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#292524')),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor('#D6D3D1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E7E5E4')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_eg)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully generated at: {filename}")

if __name__ == '__main__':
    out_path = os.path.abspath('docs/ai-stats-insight-analysis.pdf')
    build_pdf(out_path)
