// Builds slides/Final_SE193905_slides.pptx following Option 2 (Full 24 Main Slides + 6 Appendix/Backup Slides = 30 slides)
// aligned with:
//   1. Software_Project_Presentation_Guideline_V1.0.pptx (Version 11: P1 Problem, P2 Design, P3 Demo, P4 Proof, Appendix)
//   2. Workflow_La_Gi_Dinh_Nghia_Va_Dac_Ta.pdf (Workflow naming Verb + Object, 7-component spec, Swimlanes, State Machine, Unified Demo WF layout)
//
// Usage:
//   python scripts/prepare_final_slides.py
//   NODE_PATH=<folder with pptxgenjs> node scripts/build_final_slides.js

const path = require("path");
const fs = require("fs");
const pptxgen = require("pptxgenjs");

const ROOT = path.resolve(__dirname, "..");
const IMG = path.join(ROOT, "slides", "img-final");
const OUT = path.join(ROOT, "slides", "Final_SE193905_slides.pptx");
const SIZES = JSON.parse(fs.readFileSync(path.join(IMG, "sizes.json"), "utf8"));

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
pres.theme = { headFontFace: "Calibri", bodyFontFace: "Calibri" };
pres.title = "BreakBite - PRM393 Final Assignment Presentation";
pres.author = "Nhóm 2 PRM393 (SE193905)";

// Guideline V11 color palette + BreakBite brand accents
const PAL = {
  bg: "F8FAFC",
  card: "FFFFFF",
  cardAlt: "F1F5F9",
  border: "CBD5E1",
  borderSoft: "E2E8F0",
  ink: "0F172A",
  ink2: "334155",
  muted: "64748B",
  white: "FFFFFF",
  darkBg: "1E1B18",
  brand: "EA580C",
  brandSoft: "FFEDD5",
  p1: { fg: "1D4ED8", bg: "DBEAFE", label: "P1 · PROBLEM" },
  p2: { fg: "6D28D9", bg: "EDE9FE", label: "P2 · DESIGN" },
  p3: { fg: "C2410C", bg: "FFEDD5", label: "P3 · DEMO" },
  p4: { fg: "15803D", bg: "DCFCE7", label: "P4 · PROOF" },
  app: { fg: "334155", bg: "E2E8F0", label: "APPENDIX · BACKUP" },
  danger: { fg: "B91C1C", bg: "FEE2E2" },
  warn: { fg: "B45309", bg: "FEF3C7" },
  ok: { fg: "15803D", bg: "DCFCE7" },
  info: { fg: "1D4ED8", bg: "DBEAFE" },
};

const img = (n) => path.join(IMG, `${n}.png`);

function fit(name, maxW, maxH) {
  const [w, h] = SIZES[name];
  const s = Math.min(maxW / w, maxH / h);
  return { w: w * s, h: h * s };
}

// Create a standard guideline slide with top section pill, slide code, progress bar, assertion headline, and subtitle
function makeSlide(secKey, codeLabel, headline, subtitle, slideNumText) {
  const sec = PAL[secKey];
  const s = pres.addSlide();
  s.background = { color: PAL.bg };

  // Top header band
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.45, y: 0.22, w: 1.55, h: 0.28, rectRadius: 0.06,
    fill: { color: sec.bg }, line: { color: sec.fg, width: 0.75 },
  });
  s.addText(sec.label, {
    x: 0.45, y: 0.22, w: 1.55, h: 0.28, fontSize: 9.5, bold: true,
    color: sec.fg, align: "center", valign: "middle", margin: 0, isTextBox: true,
  });

  s.addText(codeLabel, {
    x: 2.1, y: 0.22, w: 5.5, h: 0.28, fontSize: 10.5, bold: true,
    color: PAL.muted, align: "left", valign: "middle", margin: 0, isTextBox: true,
  });

  // Top-right 4-part progress pills
  const parts = [
    ["p1", "P1 Problem"],
    ["p2", "P2 Design"],
    ["p3", "P3 Demo"],
    ["p4", "P4 Proof"],
  ];
  parts.forEach(([k, lbl], idx) => {
    const active = k === secKey;
    const px = 9.05 + idx * 0.96;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: px, y: 0.23, w: 0.9, h: 0.24, rectRadius: 0.05,
      fill: { color: active ? PAL[k].fg : "E2E8F0" },
      line: { type: "none" },
    });
    s.addText(lbl, {
      x: px, y: 0.23, w: 0.9, h: 0.24, fontSize: 8, bold: active,
      color: active ? PAL.white : PAL.muted, align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
  });

  // Main assertion headline + 1-line subtitle
  s.addText(headline, {
    x: 0.45, y: 0.54, w: 12.43, h: 0.42, fontSize: 20, bold: true,
    color: PAL.ink, align: "left", valign: "middle", margin: 0, isTextBox: true,
  });
  if (subtitle) {
    s.addText(subtitle, {
      x: 0.45, y: 0.95, w: 12.43, h: 0.28, fontSize: 11.5,
      color: PAL.ink2, align: "left", valign: "middle", margin: 0, isTextBox: true,
    });
  }

  // Footer line
  s.addShape(pres.shapes.LINE, {
    x: 0.45, y: 7.08, w: 12.43, h: 0,
    line: { color: PAL.borderSoft, width: 0.75 },
  });
  s.addText("BreakBite · PRM393 Final Assignment · Hệ thống đặt món giờ giải lao trên Firebase", {
    x: 0.45, y: 7.12, w: 8.5, h: 0.25, fontSize: 9, color: PAL.muted, margin: 0, isTextBox: true,
  });
  s.addText(slideNumText || codeLabel.split(" ")[0], {
    x: 11.3, y: 7.12, w: 1.58, h: 0.25, fontSize: 9.5, bold: true,
    color: sec.fg, align: "right", margin: 0, isTextBox: true,
  });

  return s;
}

// Card helper with optional top header band or left accent border
function addCard(s, x, y, w, h, opts = {}) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: opts.radius || 0.08,
    fill: { color: opts.fill || PAL.card },
    line: { color: opts.border || PAL.border, width: opts.lineWidth || 0.75 },
  });
  if (opts.tag) {
    const tagBg = opts.tagBg || PAL.p1.bg;
    const tagFg = opts.tagFg || PAL.p1.fg;
    const tagW = opts.tagW || 1.65;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: x + 0.14, y: y + 0.12, w: tagW, h: 0.24, rectRadius: 0.04,
      fill: { color: tagBg }, line: { type: "none" },
    });
    s.addText(opts.tag, {
      x: x + 0.14, y: y + 0.12, w: tagW, h: 0.24, fontSize: 8.5, bold: true,
      color: tagFg, align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
  }
  if (opts.title) {
    const ty = opts.tag ? y + 0.42 : y + 0.14;
    s.addText(opts.title, {
      x: x + 0.14, y: ty, w: w - 0.28, h: opts.titleH || 0.32,
      fontSize: opts.titleSize || 13, bold: true, color: opts.titleColor || PAL.ink,
      margin: 0, isTextBox: true, valign: "top",
    });
  }
}

function addEvidenceBar(s, label, text, y = 6.62) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.45, y, w: 12.43, h: 0.38, rectRadius: 0.05,
    fill: { color: PAL.cardAlt }, line: { color: PAL.border, width: 0.6 },
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.53, y: y + 0.06, w: 1.35, h: 0.26, rectRadius: 0.04,
    fill: { color: PAL.ink }, line: { type: "none" },
  });
  s.addText(label, {
    x: 0.53, y: y + 0.06, w: 1.35, h: 0.26, fontSize: 8.5, bold: true,
    color: PAL.white, align: "center", valign: "middle", margin: 0, isTextBox: true,
  });
  s.addText(text, {
    x: 1.98, y: y + 0.04, w: 10.8, h: 0.3, fontSize: 10,
    color: PAL.ink2, align: "left", valign: "middle", margin: 0, isTextBox: true,
  });
}

function phone(s, name, x, y, boxW, boxH, caption) {
  const capH = caption ? 0.32 : 0;
  const pad = 0.05;
  const { w, h } = fit(name, boxW - 2 * pad, boxH - capH - 2 * pad);
  const fx = x + (boxW - w - 2 * pad) / 2;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: fx, y, w: w + 2 * pad, h: h + 2 * pad, rectRadius: 0.09,
    fill: { color: PAL.ink }, line: { color: PAL.ink },
  });
  s.addImage({ path: img(name), x: fx + pad, y: y + pad, w, h });
  if (caption) {
    s.addText(caption, {
      x, y: y + h + 2 * pad + 0.03, w: boxW, h: capH - 0.03,
      fontSize: 9.5, bold: true, color: PAL.ink2, align: "center", margin: 0, isTextBox: true,
    });
  }
}

function screen(s, name, x, y, boxW, boxH, caption) {
  const capH = caption ? 0.32 : 0;
  const { w, h } = fit(name, boxW, boxH - capH);
  const sx = x + (boxW - w) / 2;
  s.addImage({ path: img(name), x: sx, y, w, h });
  s.addShape(pres.shapes.RECTANGLE, {
    x: sx, y, w, h, fill: { type: "none" }, line: { color: PAL.border, width: 0.75 },
  });
  if (caption) {
    s.addText(caption, {
      x, y: y + h + 0.03, w: boxW, h: capH - 0.03,
      fontSize: 9.5, bold: true, color: PAL.ink2, align: "center", margin: 0, isTextBox: true,
    });
  }
}

function tblCell(text, opts = {}) {
  return {
    text,
    options: {
      bold: !!opts.bold,
      fontSize: opts.fontSize || 10,
      color: opts.color || PAL.ink,
      fill: opts.fill ? { color: opts.fill } : undefined,
      align: opts.align || "left",
      valign: "middle",
      margin: opts.margin || [3, 5, 3, 5],
    },
  };
}

// ============================================================================
// SECTION P1 · PROBLEM (SLIDES 01 - 06)
// ============================================================================

// 01 / OVERVIEW
{
  const s = makeSlide(
    "p1",
    "01 / OVERVIEW",
    "BreakBite — Đặt món trước giờ giải lao, nhận ngay tại quầy bằng mã QR",
    "Hệ thống Mobile App & Web Admin đồng bộ thời gian thực trên một dự án Firebase cho căng-tin Campus Quận 9",
    "01 / 24"
  );

  // Left: Project identity + 3 summary cards (USERS, VALUE, PLATFORM)
  const cards = [
    ["USERS", "Sinh viên & giảng viên Campus Quận 9 (Khách hàng), Nhân viên quầy Kiosk và Quản trị viên hệ thống.", PAL.p1.bg, PAL.p1.fg],
    ["VALUE", "Đặt trước & thanh toán < 35s (≤ 8 chạm); duyệt đơn liên vai trò ~1,15s; quét QR nhận món không phải xếp hàng.", PAL.ok.bg, PAL.ok.fg],
    ["PLATFORM", "2 ứng dụng (Flutter Android + Flutter Web trên Firebase Hosting) dùng chung gói packages/core & Firebase Spark.", PAL.p3.bg, PAL.p3.fg],
  ];
  cards.forEach(([tag, desc, tbg, tfg], i) => {
    const y = 1.32 + i * 1.32;
    addCard(s, 0.45, y, 6.2, 1.2, { tag, tagBg: tbg, tagFg: tfg, tagW: 1.15 });
    s.addText(desc, {
      x: 0.59, y: y + 0.42, w: 5.9, h: 0.7, fontSize: 11.5, color: PAL.ink,
      margin: 0, isTextBox: true, valign: "top",
    });
  });

  // Course / Team card
  addCard(s, 0.45, 5.32, 6.2, 1.18, { fill: PAL.cardAlt, tag: "THÔNG TIN ĐỀ TÀI", tagBg: PAL.ink, tagFg: PAL.white, tagW: 1.6 });
  s.addText([
    { text: "Môn học: PRM393 — Mobile Programming · Bài tập lớn cuối kỳ (Nhóm 2)\n", options: { bold: true } },
    { text: "Web Admin (Live): https://breakbite-1315b.web.app   |   Firebase Project: breakbite-1315b\n" },
    { text: "Repository: github.com/baonv0817/PRM393_Lab03_Group2 (45 màn Mobile + 13 màn Web)" },
  ], { x: 0.59, y: 5.72, w: 5.9, h: 0.72, fontSize: 10, color: PAL.ink2, margin: 0, isTextBox: true });

  // Right: Product preview (Web + Phone)
  addCard(s, 6.85, 1.32, 6.03, 5.18, { tag: "SẢN PHẨM THỰC TẾ ĐANG CHẠY", tagBg: PAL.p1.bg, tagFg: PAL.p1.fg, tagW: 2.35 });
  screen(s, "w03-queue", 7.0, 1.78, 3.85, 4.5, "Web Admin W03: Hàng chờ duyệt đơn");
  phone(s, "s02-home", 10.95, 1.78, 1.78, 4.5, "Mobile S02: Trang chủ");

  addEvidenceBar(s, "EVIDENCE", "Hệ thống thật đã triển khai trên Firebase Hosting & Android APK; toàn bộ ảnh chụp trên slide trích từ hệ thống đang chạy (evidence/).");
  s.addNotes("Slide 01 giới thiệu tổng quan dự án BreakBite trong 30 giây đầu: giải bài toán đặt món giờ giải lao 15 phút tại Campus Quận 9, kết nối ứng dụng Android của khách và nhân viên với Web Admin trên cùng một dự án Firebase.");
}

// 02 / CONTEXT
{
  const s = makeSlide(
    "p1",
    "02 / CONTEXT",
    "Giờ giải lao giữa hai ca học chỉ có 15 phút, toàn bộ sinh viên dồn xuống quầy cùng lúc",
    "Quy trình mua đồ ăn thủ công hiện tại gồm 4 bước nối tiếp khiến cả khách mua lẫn nhân viên quầy đều quá tải",
    "02 / 24"
  );

  // Top: 3 context cards (Where/When, Who, Current Manual Process)
  const ctx = [
    ["BỐI CẢNH (WHERE / WHEN)", "Khu ăn uống & các quầy Kiosk tại Campus Quận 9 vào khung giờ giải lao 15 phút giữa hai tiết học (09:15–09:30, 14:15–14:30).", "Khung giờ cao điểm cố định, lượng khách dồn cục bộ trong 5 phút đầu."],
    ["ĐỐI TƯỢNG THAM GIA (WHO)", "Sinh viên/giảng viên mất ~5 phút đi bộ từ giảng đường xuống quầy; nhân viên mỗi quầy chỉ có 1–2 người vừa thu ngân vừa làm món.", "Chỉ còn tối đa 10 phút tại quầy để gọi món, thanh toán và nhận đồ."],
    ["HIỆN TRẠNG VẬN HÀNH", "Mọi giao dịch diễn ra trực tiếp tại quầy: hỏi giá miệng, trả tiền mặt hoặc giơ màn hình chuyển khoản để nhân viên chụp/kiểm tra.", "Không biết trước quầy nào đang vắng hay món nào đã hết trước khi đi bộ xuống."],
  ];
  ctx.forEach(([tag, body, note], i) => {
    const x = 0.45 + i * 4.22;
    addCard(s, x, 1.32, 4.0, 2.35, { tag, tagBg: PAL.p1.bg, tagFg: PAL.p1.fg, tagW: 2.35 });
    s.addText(body, { x: x + 0.14, y: 1.78, w: 3.72, h: 1.05, fontSize: 11, color: PAL.ink, margin: 0, isTextBox: true });
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: x + 0.14, y: 2.92, w: 3.72, h: 0.6, rectRadius: 0.05,
      fill: { color: PAL.warn.bg }, line: { type: "none" },
    });
    s.addText(note, {
      x: x + 0.22, y: 2.95, w: 3.56, h: 0.54, fontSize: 9.5, bold: true, color: PAL.warn.fg,
      margin: 0, isTextBox: true, valign: "middle",
    });
  });

  // Bottom: 4-step manual workflow showing where time is lost
  addCard(s, 0.45, 3.85, 12.43, 2.6, {
    tag: "QUY TRÌNH THỦ CÔNG HIỆN TẠI (4 BƯỚC NỐI TIẾP TẠI QUẦY)",
    tagBg: PAL.danger.bg, tagFg: PAL.danger.fg, tagW: 4.1,
  });
  const steps = [
    ["Bước 1 · Đi bộ & xếp hàng", "Đi bộ ~5 phút xuống quầy; xếp hàng chờ tới lượt hỏi món (3–5 phút).", "Mất 8–10 phút"],
    ["Bước 2 · Hỏi món & báo giá", "Hỏi món còn/hết, cộng nhẩm giá tiền hoặc hỏi khuyến mãi tại quầy.", "Dễ nhầm giá, hết món"],
    ["Bước 3 · Trả tiền mặt / CK", "Tìm tiền lẻ hoặc mở app ngân hàng chuyển khoản, chờ nhân viên đối chiếu.", "Tắc nghẽn tại thu ngân"],
    ["Bước 4 · Đợi gọi số lấy món", "Đứng chờ quanh quầy nghe gọi miệng; ồn ào dễ giao nhầm đơn.", "Trễ giờ vào lớp"],
  ];
  steps.forEach(([st, desc, bad], i) => {
    const x = 0.65 + i * 3.04;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y: 4.35, w: 2.82, h: 1.9, rectRadius: 0.07,
      fill: { color: PAL.cardAlt }, line: { color: PAL.border, width: 0.75 },
    });
    s.addText(st, { x: x + 0.12, y: 4.45, w: 2.58, h: 0.35, fontSize: 11, bold: true, color: PAL.ink, margin: 0, isTextBox: true });
    s.addText(desc, { x: x + 0.12, y: 4.82, w: 2.58, h: 0.85, fontSize: 10, color: PAL.ink2, margin: 0, isTextBox: true });
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: x + 0.12, y: 5.75, w: 2.58, h: 0.36, rectRadius: 0.04,
      fill: { color: PAL.danger.bg }, line: { type: "none" },
    });
    s.addText(bad, {
      x: x + 0.12, y: 5.75, w: 2.58, h: 0.36, fontSize: 9.5, bold: true, color: PAL.danger.fg,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
    if (i < 3) {
      s.addText("→", {
        x: x + 2.82, y: 5.05, w: 0.22, h: 0.4, fontSize: 16, bold: true, color: PAL.muted,
        align: "center", valign: "middle", margin: 0, isTextBox: true,
      });
    }
  });

  addEvidenceBar(s, "NGUỒN BỐI CẢNH", "Khảo sát quy trình giờ giải lao tại Campus Quận 9 trong Lab 1 & Lab 2 (03-P2-ux-design/01-persona.md, 02-scenarios.md).");
  s.addNotes("Slide 02 mô tả bối cảnh vận hành thực tế tại Campus Quận 9: giờ nghỉ 15 phút nhưng quy trình mua hàng truyền thống bắt buộc sinh viên phải có mặt vật lý tại quầy mới bắt đầu gọi món và chờ chế biến.");
}

// 03 / PROBLEM
{
  const s = makeSlide(
    "p1",
    "03 / PROBLEM",
    "Ba vấn đề cốt lõi: chờ đợi quá giờ nghỉ, chi phí thiếu minh bạch và quá tải xử lý đơn tại quầy",
    "Mỗi vấn đề được phân rã rõ theo cấu trúc: Hiện tượng (Pain Point) → Nguyên nhân gốc (Root Cause) → Hệ quả (Impact)",
    "03 / 24"
  );

  const problems = [
    [
      "PAIN POINT 1 · KHÁCH HÀNG (P01 — QUÂN, SV NĂM 2)",
      "Không kịp mua đồ ăn trong 15 phút giải lao",
      "Quầy chỉ bắt đầu nhận đơn và chế biến sau khi khách đã đi bộ xuống và xếp hàng tới lượt.",
      "Sinh viên thấy hàng dài đành bỏ mua, nhịn đói vào ca học tiếp theo hoặc trễ giờ điểm danh.",
      "Mục tiêu thiết kế: Đặt xong đơn < 35 giây, ≤ 8 lần chạm ngay từ giảng đường.",
    ],
    [
      "PAIN POINT 2 · KHÁCH HÀNG (P02 — LINH, SV NĂM 1)",
      "Ngại đặt qua app vì sợ phí ẩn & không rõ tổng tiền",
      "Nhiều ứng dụng giao đồ ăn chỉ cộng phí dịch vụ hoặc báo mã giảm giá hết hạn ở bước cuối cùng.",
      "Khách hàng có ngân sách cố định (~40.000đ/ngày) thoát giỏ hàng ngay khi thấy số tiền lệch kỳ vọng.",
      "Mục tiêu thiết kế: Hiển thị minh bạch tổng tiền & kiểm tra voucher ngay tại giỏ hàng (S05).",
    ],
    [
      "PAIN POINT 3 · NHÂN VIÊN QUẦY (P03 — CÔ HẠNH)",
      "Quá tải vừa nhận đơn, kiểm tra tiền, vừa gọi trả món",
      "Nhân viên phải đối chiếu màn hình chuyển khoản thủ công, ghi nhớ thứ tự đơn và gọi số bằng miệng.",
      "Sai sót thứ tự ưu tiên, giao nhầm món giờ cao điểm và tốn thời gian cập nhật thực đơn mới.",
      "Mục tiêu thiết kế: Hàng chờ thời gian thực (K02/W03), trả món bằng QR (K05) và tạo món nhanh bằng AI (K14).",
    ],
  ];

  problems.forEach(([tag, title, cause, impact, target], i) => {
    const x = 0.45 + i * 4.22;
    addCard(s, x, 1.32, 4.0, 5.15, { tag, tagBg: PAL.danger.bg, tagFg: PAL.danger.fg, tagW: 3.72, title, titleH: 0.42 });

    const block = (lbl, txt, by, bg, fg) => {
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.14, y: by, w: 3.72, h: 1.25, rectRadius: 0.06,
        fill: { color: bg }, line: { color: PAL.borderSoft, width: 0.5 },
      });
      s.addText(lbl, { x: x + 0.24, y: by + 0.08, w: 3.5, h: 0.24, fontSize: 9, bold: true, color: fg, margin: 0, isTextBox: true });
      s.addText(txt, { x: x + 0.24, y: by + 0.34, w: 3.5, h: 0.84, fontSize: 10, color: PAL.ink, margin: 0, isTextBox: true });
    };

    block("NGUYÊN NHÂN GỐC (ROOT CAUSE)", cause, 2.32, PAL.cardAlt, PAL.ink2);
    block("HỆ QUẢ (IMPACT)", impact, 3.68, PAL.warn.bg, PAL.warn.fg);
    block("TIÊU CHÍ ĐO LƯỜNG CẦN ĐẠT", target, 5.04, PAL.p1.bg, PAL.p1.fg);
  });

  addEvidenceBar(s, "MINH CHỨNG", "3 Proto-Persona (P01 Quân, P02 Linh, P03 Cô Hạnh) từ Lab 2 (03-P2-ux-design/01-persona.md). Lưu ý trung thực: đây là proto-persona, chưa phỏng vấn định lượng diện rộng.");
  s.addNotes("Slide 03 đi sâu vào 3 vấn đề cụ thể gắn với 3 persona của Lab 2. Mỗi thẻ đều tách rõ Hiện tượng, Nguyên nhân gốc, Hệ quả và Tiêu chí định lượng làm cơ sở nghiệm thu ở phần P4 Proof.");
}

// 04 / PROPOSED SOLUTION
{
  const s = makeSlide(
    "p1",
    "04 / PROPOSED SOLUTION",
    "Ánh xạ 1–1 từ vấn đề sang giải pháp BreakBite và ranh giới phạm vi (Scope) rõ ràng",
    "Mỗi giải pháp đều gắn với chỉ số kỳ vọng đo kiểm được; những gì nằm ngoài phạm vi gói Firebase Spark được công bố minh bạch",
    "04 / 24"
  );

  // Top table: Pain Point -> Solution -> Expected Value
  const rows = [
    [
      tblCell("Vấn đề (Pain Point)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Giải pháp trong BreakBite (Solution)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Giá trị kỳ vọng & Chỉ số nghiệm thu (Expected Value)", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("P01 · Xếp hàng lâu trong 15 phút nghỉ", { bold: true, fill: PAL.card }),
      tblCell("Đặt món trước từ giảng đường (S02–S06), chọn khung giờ lấy, nhận mã QR để lấy món ngay tại quầy (S07–S09).", { fill: PAL.card }),
      tblCell("Hoàn tất đặt đơn < 35 giây, ≤ 8 lần chạm; theo dõi trạng thái đơn tức thì không cần đứng đợi.", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
    [
      tblCell("P02 · Sợ phí ẩn & mã giảm giá lỗi phút chót", { bold: true, fill: PAL.cardAlt }),
      tblCell("Giỏ hàng (S05) tính đúng tổng tiền ngay từ đầu (không thu phí dịch vụ ẩn), kiểm tra hạn & điều kiện voucher trực tiếp.", { fill: PAL.cardAlt }),
      tblCell("100% đơn hiển thị khớp số tiền giữa Giỏ hàng (S05), Thanh toán (S06) và Biên nhận PDF (S12).", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
    [
      tblCell("P03 · Nhân viên quá tải duyệt đơn & nhập thực đơn", { bold: true, fill: PAL.card }),
      tblCell("Hàng chờ thời gian thực trên Web (W03) & Mobile (K02), quét QR trả món (K05), và tạo món mới từ ảnh bằng AI Gemini (K14).", { fill: PAL.card }),
      tblCell("Đồng bộ duyệt/từ chối đơn Web → Mobile ~1,15 giây; AI điền sẵn 5 trường thông tin món từ 1 ảnh chụp.", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
  ];
  s.addTable(rows, {
    x: 0.45, y: 1.35, w: 12.43, colW: [3.1, 5.13, 4.2],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 0.65,
  });

  // Bottom: IN-SCOPE vs OUT-OF-SCOPE
  addCard(s, 0.45, 4.38, 6.1, 2.1, {
    tag: "IN-SCOPE (PHẠM VI ĐÃ TRIỂN KHAI TRONG MVP)",
    tagBg: PAL.ok.bg, tagFg: PAL.ok.fg, tagW: 3.6,
  });
  s.addText([
    { text: "✓ Ứng dụng Android (45 màn S01–S30, K01–K15) & Web Admin (W01–W05 + 8 trang quản trị).\n", options: { bold: true } },
    { text: "✓ Đặt đơn, áp voucher, thanh toán giả lập, theo dõi đơn realtime, quét QR nhận món, xuất biên nhận PDF.\n" },
    { text: "✓ Luồng liên vai trò (Web ↔ Mobile) cho duyệt/từ chối đơn và phát hành thông báo hệ thống.\n" },
    { text: "✓ Điền thông tin món bằng AI Gemini 3.5 Flash Lite + bật/tắt nóng qua Remote Config + bảo vệ bằng App Check." },
  ], { x: 0.6, y: 4.8, w: 5.8, h: 1.6, fontSize: 10, color: PAL.ink, margin: 0, isTextBox: true });

  addCard(s, 6.78, 4.38, 6.1, 2.1, {
    tag: "OUT-OF-SCOPE (NGOÀI PHẠM VI — DO GIỚI HẠN GÓI SPARK)",
    tagBg: PAL.warn.bg, tagFg: PAL.warn.fg, tagW: 4.3,
  });
  s.addText([
    { text: "✕ Cloud Functions / Custom Backend Server: Gói Firebase Spark miễn phí không mở Cloud Functions, nên không chạy cronjob nhắc khách sau 10 phút quên lấy món.\n" },
    { text: "✕ Firebase Storage: Thay thế bằng Cloudinary REST API để tải ảnh món, ảnh báo cáo sự cố và file biên nhận PDF.\n" },
    { text: "✕ Cổng thanh toán ngân hàng thật (VNPay/MoMo merchant): Dùng bước xác nhận thanh toán giả lập có kiểm tra trạng thái lỗi (S06-ERR)." },
  ], { x: 6.93, y: 4.8, w: 5.8, h: 1.6, fontSize: 10, color: PAL.ink, margin: 0, isTextBox: true });

  addEvidenceBar(s, "ĐỐI CHIẾU ĐỀ BÀI", "Đáp ứng đầy đủ yêu cầu hệ thống hoàn chỉnh trên Firebase (PRM393 Final Assignment Handout mục 2–8) trên gói Spark không mất phí.");
  s.addNotes("Slide 04 nối trực tiếp 3 Pain Points ở Slide 03 sang giải pháp cụ thể và tách bạch rõ In-Scope với Out-of-Scope do quyết định dùng gói Firebase Spark miễn phí.");
}

// 05 / MAIN ACTORS
{
  const s = makeSlide(
    "p1",
    "05 / MAIN ACTORS",
    "Ba vai trò người dùng và hai dịch vụ ngoài, phân quyền cứng từ giao diện tới Security Rules",
    "Vai trò lưu tại users/{uid}.role; mỗi ứng dụng tự chặn sai vai trò ở tầng UI và Firestore chặn lần hai ở tầng dữ liệu",
    "05 / 24"
  );

  const actorRows = [
    [
      tblCell("Actor / Tác nhân", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Kênh sử dụng", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Quyền hạn nghiệp vụ & Ràng buộc bảo mật (Security Rules)", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("Khách hàng\n(role: user)", { bold: true, fill: PAL.card }),
      tblCell("Android App\n(S01–S30)", { fill: PAL.card }),
      tblCell("Xem thực đơn, đặt đơn cho chính mình (R-44), huỷ đơn khi còn pending (R-48), nhận thông báo, đánh giá món, báo sự cố. Bị từ chối nếu đăng nhập Web Admin.", { fill: PAL.card }),
    ],
    [
      tblCell("Nhân viên Kiosk\n(role: staff)", { bold: true, fill: PAL.cardAlt }),
      tblCell("Android App (K01–K15)\n& Web Admin (W02–W04)", { fill: PAL.cardAlt }),
      tblCell("Chỉ được duyệt/từ chối đơn (R-47, R-49) và sửa thực đơn (R-34..R-36) của đúng kioskId được gán (staffOf). Dùng AI gợi ý món mới tại K14.", { fill: PAL.cardAlt }),
    ],
    [
      tblCell("Quản trị viên\n(role: admin)", { bold: true, fill: PAL.card }),
      tblCell("Web Admin\n(W01–W05 + 8 trang)", { fill: PAL.card }),
      tblCell("Toàn quyền trên mọi kiosk, phát hành/lưu trữ thông báo toàn hệ thống (R-74, R-75), phân quyền người dùng (R-05), quản lý kiosk, khung giờ, voucher, nhật ký.", { fill: PAL.card }),
    ],
    [
      tblCell("Dịch vụ ngoài\n(AI & Cloudinary)", { bold: true, fill: PAL.cardAlt }),
      tblCell("Firebase AI Logic\n& Cloudinary HTTP", { fill: PAL.cardAlt }),
      tblCell("Gemini 3.5 Flash Lite phân tích ảnh món ăn trả về JSON theo schema; Cloudinary lưu trữ ảnh món, ảnh sự cố và biên nhận PDF.", { fill: PAL.cardAlt }),
    ],
  ];
  s.addTable(actorRows, {
    x: 0.45, y: 1.35, w: 7.75, colW: [1.65, 1.75, 4.35],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 0.95,
  });

  // Right: Real role rejection screenshot + rule explanation
  addCard(s, 8.4, 1.35, 4.48, 5.1, {
    tag: "MINH CHỨNG CHẶN SAI VAI TRÒ (W01)",
    tagBg: PAL.danger.bg, tagFg: PAL.danger.fg, tagW: 3.1,
  });
  screen(s, "w01-reject", 8.55, 1.8, 4.18, 3.1, "Tài khoản khách đăng nhập Web Admin bị chặn ngay tại W01");
  s.addText([
    { text: "Chặn kép ở cả 2 tầng:\n", options: { bold: true, color: PAL.ink } },
    { text: "1. Tầng Client: Web Admin kiểm tra users/{uid}.role, nếu là user sẽ đăng xuất ngay và hiện thông báo đỏ; Mobile App cũng chặn tài khoản admin.\n" },
    { text: "2. Tầng Firestore Rules: Không ai tự đổi được role của mình (R-02, R-05); nhân viên kiosk A không sửa được đơn của kiosk B (R-50)." },
  ], { x: 8.55, y: 5.0, w: 4.18, h: 1.35, fontSize: 9.5, color: PAL.ink2, margin: 0, isTextBox: true });

  addEvidenceBar(s, "KIỂM CHỨNG RBAC", "80 cặp test phân quyền (cho phép & bị cấm) trong firebase/tests/rules.test.mjs (172/172 PASS) & ảnh evidence/web/W01-role-rejection.png.");
  s.addNotes("Slide 05 liệt kê đầy đủ các Actor của hệ thống cùng quyền hạn RBAC. Bên phải là ảnh chụp thực tế màn W01 khi đăng nhập bằng tài khoản sinh viên: hệ thống từ chối ngay lập tức.");
}

// 06 / MAIN FEATURES (GROUPED BY CORE WORKFLOWS PER W09)
{
  const s = makeSlide(
    "p1",
    "06 / MAIN FEATURES",
    "Tính năng hệ thống tổ chức theo 3 Workflow nghiệp vụ lõi và 1 nhóm Quản trị & Vận hành",
    "Tên mọi Workflow tuân thủ chuẩn Động từ + Đối tượng nghiệp vụ (không đặt tên theo màn hình), gắn rõ Actor, Trigger và Kết quả đầu ra",
    "06 / 24"
  );

  const wfs = [
    [
      "WF-01 · CORE WORKFLOW 1",
      "Đặt trước và thanh toán đơn món",
      "Khách hàng (Sinh viên / Giảng viên)",
      "Khách cần mua đồ ăn cho giờ giải lao và chọn món tại Kiosk đang mở cửa.",
      "Đơn hàng mới tạo ở trạng thái pending trên Firestore, giỏ hàng được làm trống, màn hình S07 hiển thị mã đơn và mã QR nhận món.",
      "Màn hình: S02 → S03 → S04 → S05 (Giỏ & Voucher) → S06 (Thanh toán) → S07 (Theo dõi đơn) → S12 (Biên nhận PDF).",
      PAL.p1.bg, PAL.p1.fg,
    ],
    [
      "WF-02 · CORE WORKFLOW 2 (CROSS-ROLE)",
      "Duyệt đơn hàng và phát thông báo liên vai trò",
      "Nhân viên Kiosk / Quản trị viên (Web) ↔ Khách hàng (Mobile)",
      "Có đơn hàng pending mới trong hàng chờ W03/K02 hoặc Quản trị viên đăng thông báo mới tại W05.",
      "Đơn chuyển sang preparing → ready → delivered (hoặc cancelled kèm lý do); điện thoại khách tự cập nhật trạng thái và nhận thông báo ở hộp thư S19 sau ~1,15 giây.",
      "Màn hình: Web W03 / Mobile K02–K05 ↔ Mobile S07 & S19; Web W05 (Thông báo) ↔ Mobile S19 (Hộp thư).",
      PAL.p3.bg, PAL.p3.fg,
    ],
    [
      "WF-03 · CORE WORKFLOW 3 (AI & REMOTE CONFIG)",
      "Tạo món mới từ ảnh bằng AI và điều khiển cấu hình từ xa",
      "Nhân viên Kiosk (Mobile K14) & Quản trị viên (Firebase Remote Config)",
      "Nhân viên chụp/chọn ảnh món ăn mới để thêm vào thực đơn Kiosk.",
      "Gemini 3.5 Flash Lite trả về JSON điền sẵn 5 ô (tên, loại, giá, thời gian, mô tả) có nhãn 'Gợi ý từ AI'; nhân viên kiểm tra rồi lưu vào menu_items. Khi tắt ai_enabled=false, nút AI ẩn ngay lập tức.",
      "Màn hình: Mobile K14 (Form thêm/sửa món), K06 (Thực đơn Kiosk), Web W02 (Thực đơn Web).",
      PAL.p2.bg, PAL.p2.fg,
    ],
  ];

  wfs.forEach(([badge, name, actor, trigger, outcome, screens, bg, fg], i) => {
    const x = 0.45 + i * 4.22;
    addCard(s, x, 1.32, 4.0, 3.85, { tag: badge, tagBg: bg, tagFg: fg, tagW: 2.6, title: name, titleH: 0.42 });
    s.addText([
      { text: "• Actor: ", options: { bold: true, color: fg } },
      { text: `${actor}\n` },
      { text: "• Trigger: ", options: { bold: true, color: fg } },
      { text: `${trigger}\n` },
      { text: "• Kết quả (Postcondition): ", options: { bold: true, color: fg } },
      { text: `${outcome}\n` },
      { text: "• Phạm vi màn hình: ", options: { bold: true, color: PAL.ink2 } },
      { text: screens },
    ], { x: x + 0.14, y: 2.25, w: 3.72, h: 2.8, fontSize: 9.8, color: PAL.ink, margin: 0, isTextBox: true, paraSpaceAfter: 4 });
  });

  // Supporting features bar
  addCard(s, 0.45, 5.3, 12.43, 1.18, {
    fill: PAL.cardAlt,
    tag: "NHÓM TÍNH NĂNG BỔ TRỢ & QUẢN TRỊ HỆ THỐNG (NGOÀI 3 WORKFLOW DEMO CHÍNH)",
    tagBg: PAL.ink, tagFg: PAL.white, tagW: 5.2,
  });
  s.addText([
    { text: "• Đánh giá & Báo sự cố (Khách & Nhân viên): ", options: { bold: true } },
    { text: "Đánh giá sao/nhận xét sau khi nhận món (S10), gửi báo cáo sự cố kèm ảnh Cloudinary (S25, K09).\n" },
    { text: "• Thống kê & Quản trị toàn hệ thống (Web Admin): ", options: { bold: true } },
    { text: "Biểu đồ doanh thu & trạng thái đơn (W04/K10), quản lý danh sách Kiosk, khung giờ nhận đơn (slots), mã giảm giá (vouchers), cấu hình hệ thống và nhật ký thao tác (audit_logs)." },
  ], { x: 0.6, y: 5.72, w: 12.1, h: 0.7, fontSize: 9.8, color: PAL.ink2, margin: 0, isTextBox: true });

  addEvidenceBar(s, "CHUẨN ĐẶC TẢ WF", "Đặt tên theo chuẩn Động từ + Đối tượng nghiệp vụ (Workflow Guideline W09); bảng đặc tả đầy đủ 7 thành phần nằm tại Phụ lục A1.");
  s.addNotes("Slide 06 gom toàn bộ 58 màn hình của hệ thống vào 3 Workflow nghiệp vụ lõi có đầu-cuối rõ ràng (Đặt trước & thanh toán, Duyệt đơn & thông báo liên vai trò, Tạo món bằng AI) để dẫn sang phần P2 Design và P3 Demo.");
}

// ============================================================================
// SECTION P2 · DESIGN (SLIDES 07 - 16 — WHOLE-SYSTEM DESIGN)
// ============================================================================

// 07 / BUSINESS FLOW (SWIMLANE ACTIVITY DIAGRAM)
{
  const s = makeSlide(
    "p2",
    "07 / BUSINESS FLOW",
    "Luồng nghiệp vụ tổng thể liên kết 3 vai trò qua cơ chế đồng bộ sự kiện của Firestore",
    "Sơ đồ Swimlane tách rõ trách nhiệm của Khách hàng, Hệ thống/Rules, Nhân viên Kiosk và Quản trị viên cùng các nút kiểm tra Business Rules",
    "07 / 24"
  );

  const lanes = [
    ["KHÁCH HÀNG\n(Mobile App)", PAL.p1.bg, PAL.p1.fg],
    ["HỆ THỐNG &\nFIRESTORE RULES", PAL.p2.bg, PAL.p2.fg],
    ["NHÂN VIÊN KIOSK\n(Web W03 / Mobile K02)", PAL.p3.bg, PAL.p3.fg],
    ["QUẢN TRỊ VIÊN\n(Web Admin W05)", PAL.ok.bg, PAL.ok.fg],
  ];

  lanes.forEach(([title, bg, fg], idx) => {
    const ly = 1.32 + idx * 1.28;
    // Swimlane row background
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.45, y: ly, w: 12.43, h: 1.2, rectRadius: 0.05,
      fill: { color: idx % 2 === 0 ? PAL.card : PAL.cardAlt },
      line: { color: PAL.border, width: 0.6 },
    });
    // Swimlane header on left
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 0.45, y: ly, w: 1.95, h: 1.2, rectRadius: 0.05,
      fill: { color: bg }, line: { color: fg, width: 0.75 },
    });
    s.addText(title, {
      x: 0.5, y: ly, w: 1.85, h: 1.2, fontSize: 9.5, bold: true, color: fg,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
  });

  const stepBox = (x, y, w, h, title, sub, fill = PAL.white, border = PAL.ink2) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y, w, h, rectRadius: 0.06, fill: { color: fill }, line: { color: border, width: 1 },
    });
    s.addText([
      { text: title, options: { bold: true, fontSize: 9.5, breakLine: !!sub } },
      ...(sub ? [{ text: sub, options: { fontSize: 8.5, color: PAL.ink2 } }] : []),
    ], { x: x + 0.06, y: y + 0.04, w: w - 0.12, h: h - 0.08, color: PAL.ink, align: "center", valign: "middle", margin: 0, isTextBox: true });
  };

  // Lane 1: Customer steps
  stepBox(2.55, 1.48, 2.1, 0.88, "1. Chọn món & Giỏ (S02–S05)", "Áp mã giảm giá, chọn giờ lấy", PAL.p1.bg, PAL.p1.fg);
  stepBox(4.95, 1.48, 2.0, 0.88, "2. Thanh toán (S06)", "Tạo đơn trạng thái pending", PAL.p1.bg, PAL.p1.fg);
  stepBox(7.25, 1.48, 2.5, 0.88, "6. Theo dõi S07 & Hộp thư S19", "Nhận trạng thái mới sau ~1,15s", PAL.p1.bg, PAL.p1.fg);
  stepBox(10.05, 1.48, 2.65, 0.88, "8. Đưa mã QR nhận món (S08)", "Tải biên nhận PDF (S12) & Đánh giá", PAL.ok.bg, PAL.ok.fg);

  // Lane 2: System & Rules checks
  stepBox(2.55, 2.76, 2.1, 0.88, "Kiểm tra [BR-01, BR-02]", "Quầy mở cửa? Voucher hợp lệ?", PAL.warn.bg, PAL.warn.fg);
  stepBox(4.95, 2.76, 2.0, 0.88, "Rule R-44, R-45", "Ghi orders/{id} = pending", PAL.p2.bg, PAL.p2.fg);
  stepBox(7.25, 2.76, 2.5, 0.88, "Rule [BR-03] (R-47, R-49)", "Đúng staffOf(kioskId)? Có lý do huỷ?", PAL.warn.bg, PAL.warn.fg);
  stepBox(10.05, 2.76, 2.65, 0.88, "Rule [BR-04] & Gợi ý AI", "Khớp mã QR pickupCode / Schema AI", PAL.p2.bg, PAL.p2.fg);

  // Lane 3: Staff steps
  stepBox(2.55, 4.04, 2.1, 0.88, "WF-03: Thêm món bằng AI", "Chụp ảnh ở K14 → Gemini điền 5 ô", PAL.p3.bg, PAL.p3.fg);
  stepBox(4.95, 4.04, 2.0, 0.88, "3. Nhận đơn ở W03 / K02", "Đơn hiện tức thì trong hàng chờ", PAL.p3.bg, PAL.p3.fg);
  stepBox(7.25, 4.04, 2.5, 0.88, "4. Duyệt (preparing) / Từ chối", "5. Báo món xong (ready tại K03)", PAL.p3.bg, PAL.p3.fg);
  stepBox(10.05, 4.04, 2.65, 0.88, "7. Quét QR trả món (K05)", "Chuyển đơn sang delivered", PAL.ok.bg, PAL.ok.fg);

  // Lane 4: Admin steps
  stepBox(2.55, 5.32, 3.1, 0.88, "Quản lý Kiosk, Khung giờ & Voucher", "Cấu hình điều kiện gốc cho [BR-01, BR-02]", PAL.card, PAL.ink2);
  stepBox(5.95, 5.32, 3.5, 0.88, "Đăng / Lưu trữ Thông báo (W05)", "Rule R-74, R-75 → đẩy tới S19 sau 1,13s", PAL.ok.bg, PAL.ok.fg);
  stepBox(9.75, 5.32, 2.95, 0.88, "Điều khiển Remote Config", "Bật/tắt nóng ai_enabled cho WF-03", PAL.p2.bg, PAL.p2.fg);

  addEvidenceBar(s, "BUSINESS RULES", "BR-01: Kiosk mở & còn slot · BR-02: Giỏ > 0 & voucher hợp lệ · BR-03: Chỉ nhân viên đúng Kiosk được duyệt, từ chối phải có lý do · BR-04: Khớp mã QR khi giao món.");
  s.addNotes("Slide 07 trình bày Business Flow toàn hệ thống bằng Swimlane 4 làn: Khách hàng, Hệ thống/Firestore Rules, Nhân viên Kiosk và Quản trị viên, chỉ rõ nơi các Business Rules BR-01 đến BR-04 được kiểm tra.");
}

// 08 / STATE MACHINE (ORDER LIFECYCLE & FORBIDDEN TRANSITIONS)
{
  const s = makeSlide(
    "p2",
    "08 / STATE MACHINE",
    "Vòng đời thực thể Order gồm 5 trạng thái với điều kiện chuyển và các đường chuyển bị cấm",
    "Mọi bước chuyển trạng thái đều được kiểm chứng bằng Firestore Security Rules (R-44 đến R-52) ở tầng cơ sở dữ liệu",
    "08 / 24"
  );

  // Left: State machine visual diagram + transition table
  addCard(s, 0.45, 1.32, 7.85, 5.15, {
    tag: "STATE MACHINE · THỰC THỂ ORDER (orders/{orderId}.status)",
    tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 4.3,
  });

  const states = [
    ["1. pending\n(Chờ xác nhận)", 0.7, 1.95, PAL.warn.bg, PAL.warn.fg],
    ["2. preparing\n(Đang chuẩn bị)", 2.6, 1.95, PAL.p1.bg, PAL.p1.fg],
    ["3. ready\n(Sẵn sàng lấy)", 4.5, 1.95, PAL.p2.bg, PAL.p2.fg],
    ["4. delivered\n(Đã hoàn tất)", 6.4, 1.95, PAL.ok.bg, PAL.ok.fg],
  ];
  states.forEach(([lbl, x, y, bg, fg], i) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y, w: 1.65, h: 0.78, rectRadius: 0.08,
      fill: { color: bg }, line: { color: fg, width: 1.2 },
    });
    s.addText(lbl, {
      x, y, w: 1.65, h: 0.78, fontSize: 10, bold: true, color: fg,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
    if (i < 3) {
      s.addText("→", {
        x: x + 1.65, y: y + 0.15, w: 0.25, h: 0.45, fontSize: 15, bold: true, color: PAL.ink2,
        align: "center", valign: "middle", margin: 0, isTextBox: true,
      });
    }
  });

  // Cancelled state below pending
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.7, y: 3.1, w: 1.65, h: 0.72, rectRadius: 0.08,
    fill: { color: PAL.danger.bg }, line: { color: PAL.danger.fg, width: 1.2 },
  });
  s.addText("5. cancelled\n(Đã huỷ / Từ chối)", {
    x: 0.7, y: 3.1, w: 1.65, h: 0.72, fontSize: 10, bold: true, color: PAL.danger.fg,
    align: "center", valign: "middle", margin: 0, isTextBox: true,
  });
  s.addText("↓ [Khách huỷ khi pending (R-48) HOẶC Nhân viên từ chối kèm rejectionReason (R-49)]", {
    x: 2.48, y: 3.22, w: 5.6, h: 0.48, fontSize: 9.5, bold: true, color: PAL.danger.fg,
    margin: 0, isTextBox: true, valign: "middle",
  });

  // Transition specification table inside left card
  const trRows = [
    [
      tblCell("Chuyển trạng thái", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Sự kiện (Event) & Tác nhân", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Điều kiện canh gác [Guard] & Hành động /Action", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
    ],
    [
      tblCell("[Khởi tạo] → pending", { bold: true, fontSize: 9 }),
      tblCell("Khách bấm Thanh toán (S06)", { fontSize: 9 }),
      tblCell("[userId == request.auth.uid && total > 0 (R-44)] / Ghi đơn mới, xoá giỏ hàng", { fontSize: 9 }),
    ],
    [
      tblCell("pending → preparing", { bold: true, fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Nhân viên bấm Duyệt (W03/K02)", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("[staffOf(kioskId) || isAdmin (R-47)] / Ghi estimatedMinutes, tạo thông báo cho khách", { fontSize: 9, fill: PAL.cardAlt }),
    ],
    [
      tblCell("preparing → ready", { bold: true, fontSize: 9 }),
      tblCell("Nhân viên bấm Báo món xong (K03)", { fontSize: 9 }),
      tblCell("[staffOf(kioskId) || isAdmin] / Ghi readyAt = serverTimestamp(), thông báo S19", { fontSize: 9 }),
    ],
    [
      tblCell("ready → delivered", { bold: true, fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Nhân viên quét QR trả món (K05)", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("[Khớp mã pickupCode & staffOf(kioskId)] / Ghi deliveredAt, mở quyền đánh giá S10", { fontSize: 9, fill: PAL.cardAlt }),
    ],
  ];
  s.addTable(trRows, {
    x: 0.65, y: 3.98, w: 7.45, colW: [1.75, 2.05, 3.65],
    border: { type: "solid", color: PAL.border, pt: 0.6 }, rowH: 0.44,
  });

  // Right card: Forbidden transitions (mandatory per W08 & Guideline Slide 08)
  addCard(s, 8.5, 1.32, 4.38, 5.15, {
    tag: "CHUYỂN TRẠNG THÁI BỊ CẤM (FORBIDDEN)",
    tagBg: PAL.danger.bg, tagFg: PAL.danger.fg, tagW: 3.3,
  });
  const forbidden = [
    ["Cấm nhảy cóc trạng thái (pending → delivered)", "Đơn bắt buộc đi qua preparing và ready; Security Rules kiểm tra trạng thái nguồn hợp lệ trước khi cho phép ghi."],
    ["Cấm khách tự duyệt đơn (pending → preparing)", "Rule R-46 chặn mọi nỗ lực của khách tự đổi trạng thái đơn sang đang làm hoặc hoàn tất."],
    ["Cấm khách huỷ đơn đã chế biến (preparing → cancelled)", "Khi quầy đã nhận làm món, khách không thể tự huỷ để tránh thất thoát nguyên liệu cho quầy."],
    ["Cấm nhân viên từ chối thiếu lý do (R-49)", "Chuyển sang cancelled bởi nhân viên bắt buộc có chuỗi rejectionReason không rỗng."],
    ["Cấm nhân viên Kiosk khác duyệt đơn (R-50)", "Nhân viên chỉ được đổi trạng thái đơn có kioskId trùng với kioskId trong hồ sơ users/{uid}."],
  ];
  forbidden.forEach(([h, d], idx) => {
    const fy = 1.82 + idx * 0.9;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 8.65, y: fy, w: 4.08, h: 0.8, rectRadius: 0.05,
      fill: { color: idx % 2 === 0 ? PAL.danger.bg : PAL.cardAlt },
      line: { color: PAL.borderSoft, width: 0.5 },
    });
    s.addText([
      { text: `✕ ${h}\n`, options: { bold: true, fontSize: 9.5, color: PAL.danger.fg } },
      { text: d, options: { fontSize: 8.8, color: PAL.ink } },
    ], { x: 8.75, y: fy + 0.05, w: 3.88, h: 0.7, margin: 0, isTextBox: true });
  });

  addEvidenceBar(s, "MINH CHỨNG RULES", "Kiểm chứng tự động trong firebase/tests/rules.test.mjs (các test R-44 đến R-52 trong tổng số 172/172 test đạt trên Emulator).");
  s.addNotes("Slide 08 đặc tả State Machine của thực thể quan trọng nhất là Order: 5 trạng thái, bảng điều kiện chuyển [Guard] / Action bên trái và 5 đường chuyển bị cấm bên phải được bảo vệ bởi Firestore Security Rules.");
}

// 09 / SYSTEM ARCHITECTURE
{
  const s = makeSlide(
    "p2",
    "09 / SYSTEM ARCHITECTURE",
    "Kiến trúc hai ứng dụng chia sẻ chung gói packages/core trên nền tảng Firebase Spark",
    "Mọi truy cập dữ liệu và AI đi trực tiếp từ client đã xác thực App Check vào Firebase, không cần máy chủ trung gian",
    "09 / 24"
  );

  // Left: Architecture diagram
  addCard(s, 0.45, 1.32, 8.15, 5.15, {
    tag: "CONTAINER DIAGRAM · KIẾN TRÚC TỔNG THỂ HỆ THỐNG",
    tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 3.9,
  });

  const archBox = (x, y, w, h, title, sub, bg, fg) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y, w, h, rectRadius: 0.07, fill: { color: bg }, line: { color: fg, width: 1 },
    });
    s.addText([
      { text: title, options: { bold: true, fontSize: 10.5, breakLine: !!sub } },
      ...(sub ? [{ text: sub, options: { fontSize: 8.8 } }] : []),
    ], { x: x + 0.08, y: y + 0.05, w: w - 0.16, h: h - 0.1, color: fg, align: "center", valign: "middle", margin: 0, isTextBox: true });
  };

  archBox(0.7, 1.85, 3.65, 0.85, "Mobile App (Flutter Android)", "Khách hàng (S01–S30) & Nhân viên (K01–K15)", PAL.p1.bg, PAL.p1.fg);
  archBox(4.65, 1.85, 3.65, 0.85, "Web Admin (Flutter Web)", "Nhân viên & Admin (W01–W05 + 8 trang) · Firebase Hosting", PAL.p3.bg, PAL.p3.fg);

  s.addText("↓ Dùng chung toàn bộ tầng Domain & Data ↓", {
    x: 0.7, y: 2.75, w: 7.6, h: 0.28, fontSize: 9.5, bold: true, color: PAL.ink2, align: "center", margin: 0, isTextBox: true,
  });

  archBox(
    0.7, 3.05, 7.6, 0.82,
    "packages/core (Gói Dart dùng chung giữa Mobile & Web)",
    "12 Domain Models · 12 Repository Interfaces & Firestore Implementations · Role Guards · Design Tokens & Widgets Lab 2",
    PAL.ink, PAL.white
  );

  s.addText("↓ HTTPS / WebSocket SDK (Bảo vệ bởi Firebase App Check & Auth Token) ↓", {
    x: 0.7, y: 3.92, w: 7.6, h: 0.28, fontSize: 9.5, bold: true, color: PAL.p2.fg, align: "center", margin: 0, isTextBox: true,
  });

  const svcs = [
    ["Firebase Auth", "Google & Email"],
    ["Cloud Firestore", "12 Collections + Rules"],
    ["Remote Config", "ai_enabled, ai_model"],
    ["App Check", "Debug / reCAPTCHA"],
    ["AI Logic", "Gemini 3.5 Flash Lite"],
    ["Cloudinary API", "Upload ảnh & PDF"],
  ];
  svcs.forEach(([t, sub], idx) => {
    const col = idx % 3;
    const row = Math.floor(idx / 3);
    archBox(
      0.7 + col * 2.58,
      4.25 + row * 1.0,
      2.44,
      0.88,
      t,
      sub,
      idx === 5 ? PAL.warn.bg : PAL.p2.bg,
      idx === 5 ? PAL.warn.fg : PAL.p2.fg
    );
  });

  // Right: Deployment & Architectural Decision cards (per Guideline Slide 09)
  addCard(s, 8.8, 1.32, 4.08, 2.4, {
    tag: "DEPLOYMENT · MÔI TRƯỜNG TRIỂN KHAI",
    tagBg: PAL.ok.bg, tagFg: PAL.ok.fg, tagW: 3.0,
  });
  s.addText([
    { text: "• Web Admin: ", options: { bold: true } },
    { text: "Biên dịch Flutter Web (WASM/JS) và deploy lên Firebase Hosting tại https://breakbite-1315b.web.app.\n" },
    { text: "• Mobile App: ", options: { bold: true } },
    { text: "Đóng gói APK Android kết nối trực tiếp vào dự án Firebase thật (breakbite-1315b), kèm FCM, Analytics & Crashlytics.\n" },
    { text: "• CI & Kiểm thử: ", options: { bold: true } },
    { text: "Firebase Local Emulator Suite chạy 172 test Security Rules độc lập." },
  ], { x: 8.95, y: 1.78, w: 3.78, h: 1.85, fontSize: 9.8, color: PAL.ink, margin: 0, isTextBox: true, paraSpaceAfter: 4 });

  addCard(s, 8.8, 3.9, 4.08, 2.57, {
    tag: "QUYẾT ĐỊNH KIẾN TRÚC (TRADE-OFF)",
    tagBg: PAL.p3.bg, tagFg: PAL.p3.fg, tagW: 2.9,
  });
  s.addText([
    { text: "• Vì sao dùng gói Spark không có Server riêng?\n", options: { bold: true, color: PAL.p3.fg } },
    { text: "Giúp hệ thống chạy miễn phí 100% không cần thẻ tín dụng (Blaze). Đổi lại, logic kiểm tra quyền và tính hợp lệ của dữ liệu được đẩy xuống Firestore Security Rules + App Check.\n" },
    { text: "• Vì sao tách packages/core?\n", options: { bold: true, color: PAL.p3.fg } },
    { text: "Tránh lệch schema giữa Web và Mobile: sửa 1 model hoặc repository trong packages/core có hiệu lực ngay cho cả 2 ứng dụng." },
  ], { x: 8.95, y: 4.35, w: 3.78, h: 2.0, fontSize: 9.6, color: PAL.ink, margin: 0, isTextBox: true, paraSpaceAfter: 3 });

  addEvidenceBar(s, "TÀI LIỆU KIẾN TRÚC", "Chi tiết sơ đồ thành phần và luồng dữ liệu: docs/architecture.md, packages/core/lib/, mobile/lib/, web/lib/.");
  s.addNotes("Slide 09 giải thích kiến trúc tổng thể: 2 client Flutter chia sẻ chung gói packages/core, giao tiếp trực tiếp với 6 dịch vụ Firebase và Cloudinary REST API. Bên phải nêu rõ môi trường triển khai và lý do chọn kiến trúc Serverless trên gói Spark.");
}

// 10 / TECHNOLOGY STACK
{
  const s = makeSlide(
    "p2",
    "10 / TECHNOLOGY STACK",
    "Danh mục công nghệ đồng nhất bằng ngôn ngữ Dart/Flutter và hệ sinh thái Firebase",
    "Mọi thư viện và dịch vụ đều gắn với một mục đích kỹ thuật cụ thể trong dự án, kèm phiên bản đã ghim cố định",
    "10 / 24"
  );

  const stackRows = [
    [
      tblCell("Nhóm tầng (Layer)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Công nghệ & Phiên bản", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Dùng để làm gì trong BreakBite & Lý do lựa chọn", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("Mobile Client", { bold: true, fill: PAL.card }),
      tblCell("Flutter 3.41.6 · Dart 3.11.4\nProvider / ChangeNotifier", { fill: PAL.card, bold: true }),
      tblCell("Xây dựng 45 màn hình cho Khách hàng (S01–S30) và Nhân viên Kiosk (K01–K15), quét mã QR, tạo biên nhận PDF và nhận thông báo đẩy FCM.", { fill: PAL.card }),
    ],
    [
      tblCell("Web Admin Client", { bold: true, fill: PAL.cardAlt }),
      tblCell("Flutter Web 3.41.6\nFirebase Hosting", { fill: PAL.cardAlt, bold: true }),
      tblCell("Xây dựng 13 màn hình quản trị (W01–W05 + 8 trang hệ thống), tái sử dụng 100% model, repository và design tokens từ packages/core.", { fill: PAL.cardAlt }),
    ],
    [
      tblCell("Shared Core Package", { bold: true, fill: PAL.card }),
      tblCell("packages/core (Dart Workspace)\n12 Models & 12 Repositories", { fill: PAL.card, bold: true }),
      tblCell("Đóng gói toàn bộ thực thể nghiệp vụ, giao diện Repository, cài đặt Firestore và bộ widget chuẩn của Lab 2 để không lặp code giữa Mobile & Web.", { fill: PAL.card }),
    ],
    [
      tblCell("Backend & Bảo mật", { bold: true, fill: PAL.cardAlt }),
      tblCell("Firebase Auth · Cloud Firestore\nSecurity Rules · App Check", { fill: PAL.cardAlt, bold: true }),
      tblCell("Đăng nhập Google/Email, đồng bộ đơn hàng & thông báo theo thời gian thực (< 1,3s), phân quyền mặc định từ chối và chặn client giả mạo.", { fill: PAL.cardAlt }),
    ],
    [
      tblCell("AI & Cấu hình động", { bold: true, fill: PAL.card }),
      tblCell("Firebase AI Logic (Gemini 3.5 Flash Lite) · Remote Config", { fill: PAL.card, bold: true }),
      tblCell("Phân tích ảnh món ăn trả về JSON có cấu trúc tại màn K14; bật/tắt tính năng AI và đổi câu lệnh prompt từ xa không cần phát hành lại app.", { fill: PAL.card }),
    ],
    [
      tblCell("Lưu trữ file & Kiểm thử", { bold: true, fill: PAL.cardAlt }),
      tblCell("Cloudinary HTTP · Rules Unit Testing · Google ARTEMIS · flutter_test", { fill: PAL.cardAlt, bold: true }),
      tblCell("Tải ảnh món/sự cố/PDF qua REST API; kiểm thử 172 test Rules trên Emulator, 905 test đơn vị/widget và 19 kịch bản E2E tự động bằng AI Agent.", { fill: PAL.cardAlt }),
    ],
  ];

  s.addTable(stackRows, {
    x: 0.45, y: 1.32, w: 12.43, colW: [2.2, 3.25, 6.98],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 0.68,
  });

  addEvidenceBar(s, "CẤU HÌNH PHIÊN BẢN", "Khai báo chi tiết trong pubspec.yaml (root workspace, mobile/, web/, packages/core/) và docs/setup.md.");
  s.addNotes("Slide 10 tổng hợp bảng công nghệ theo đúng chuẩn Guideline Slide 10: chia theo nhóm Mobile, Web, Shared Core, Backend/Security, AI/Config và Testing, nêu rõ phiên bản và lý do chọn.");
}

// 11 / UI/UX DESIGN
{
  const s = makeSlide(
    "p2",
    "11 / UI/UX DESIGN",
    "Hệ thống giao diện nhất quán trên 58 màn hình, xử lý đủ 4 trạng thái UI và cải thiện sau góp ý",
    "Kế thừa bảng màu Cam Năng Lượng (#F69D39) và bộ khung Lab 2, bổ sung bố cục màn hình rộng cho Web Admin",
    "11 / 24"
  );

  // Left: Real screenshots of Mobile & Web
  addCard(s, 0.45, 1.32, 7.65, 5.15, {
    tag: "GIAO DIỆN THỰC TẾ TRÊN MOBILE APP (ANDROID) & WEB ADMIN",
    tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 4.3,
  });
  phone(s, "s02-home", 0.6, 1.78, 1.65, 3.35, "S02 Trang chủ");
  phone(s, "s07-tracking", 2.35, 1.78, 1.65, 3.35, "S07 Theo dõi đơn");
  phone(s, "k02-staff", 4.1, 1.78, 1.65, 3.35, "K02 Đơn mới");
  screen(s, "w04-stats", 5.85, 1.85, 2.1, 1.6, "W04 Thống kê");
  screen(s, "w02-menu", 5.85, 3.55, 2.1, 1.6, "W02 Thực đơn");

  // 4 UI States bar inside left card
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.6, y: 5.25, w: 7.35, h: 1.08, rectRadius: 0.06,
    fill: { color: PAL.cardAlt }, line: { color: PAL.border, width: 0.6 },
  });
  s.addText([
    { text: "Đủ 4 trạng thái giao diện (UI States) trên mọi màn hình chính:\n", options: { bold: true, color: PAL.ink } },
    { text: "1. Empty State: ", options: { bold: true, color: PAL.p1.fg } },
    { text: "Giỏ hàng trống, hàng chờ hết đơn (W03-empty), thực đơn rỗng.\n" },
    { text: "2. Loading State: ", options: { bold: true, color: PAL.p2.fg } },
    { text: "Skeleton / vòng xoay chờ Firestore & chờ AI phân tích ảnh.   " },
    { text: "3. Error State: ", options: { bold: true, color: PAL.danger.fg } },
    { text: "Mất mạng, lỗi thanh toán S06-ERR, ảnh không phải đồ ăn.   " },
    { text: "4. Success State: ", options: { bold: true, color: PAL.ok.fg } },
    { text: "Đặt đơn, duyệt đơn, lưu món thành công." },
  ], { x: 0.72, y: 5.3, w: 7.1, h: 0.98, fontSize: 9.2, color: PAL.ink2, margin: 0, isTextBox: true });

  // Right: Design system & Post-feedback improvements (mandatory per Guideline Slide 11)
  addCard(s, 8.3, 1.32, 4.58, 2.35, {
    tag: "HỆ THỐNG MÀN HÌNH & DESIGN TOKENS",
    tagBg: PAL.p1.bg, tagFg: PAL.p1.fg, tagW: 3.1,
  });
  s.addText([
    { text: "• Khách hàng (S01–S30): ", options: { bold: true } },
    { text: "30 màn từ Đăng nhập, Chọn Kiosk, Thực đơn, Giỏ hàng, Thanh toán, QR nhận món tới Hộp thư, Đánh giá, Sự cố.\n" },
    { text: "• Nhân viên Kiosk (K01–K15): ", options: { bold: true } },
    { text: "15 màn xử lý đơn mới, đang làm, quét QR, thêm món bằng AI, thống kê ca.\n" },
    { text: "• Web Admin (W01–W05 + 8 trang): ", options: { bold: true } },
    { text: "Bố cục bảng rộng cho màn hình máy tính, giữ nguyên màu và kiểu chữ của Lab 2." },
  ], { x: 8.45, y: 1.78, w: 4.28, h: 1.8, fontSize: 9.5, color: PAL.ink, margin: 0, isTextBox: true, paraSpaceAfter: 3 });

  addCard(s, 8.3, 3.82, 4.58, 2.65, {
    tag: "SAU GÓP Ý (POST-FEEDBACK IMPROVEMENTS)",
    tagBg: PAL.ok.bg, tagFg: PAL.ok.fg, tagW: 3.4,
  });
  s.addText([
    { text: "• Khắc phục tràn chữ khi phóng chữ 200% (G04–G06):\n", options: { bold: true, color: PAL.ok.fg } },
    { text: "Sửa thẻ tóm tắt nhân viên (K02), nhãn bộ lọc và thanh bước thanh toán (S06) để không bị cắt chữ khi người dùng bật cỡ chữ lớn.\n" },
    { text: "• Mở rộng vùng chạm & thông báo lỗi rõ nghĩa:\n", options: { bold: true, color: PAL.ok.fg } },
    { text: "Đảm bảo vùng chạm ≥ 48dp; phân biệt rõ 'Kiosk chưa có món' với lỗi 'Mất kết nối mạng' (#110).\n" },
    { text: "• Ghi nhận minh bạch 39 điểm điều chỉnh (D01–D39):\n", options: { bold: true, color: PAL.ok.fg } },
    { text: "Đối chiếu từng màn với bản thiết kế Lab 2 trong docs/gap-review.md." },
  ], { x: 8.45, y: 4.28, w: 4.28, h: 2.1, fontSize: 9.4, color: PAL.ink, margin: 0, isTextBox: true, paraSpaceAfter: 3 });

  addEvidenceBar(s, "MINH CHỨNG UI/UX", "Báo cáo rà soát khoảng cách thiết kế Lab 2 → bản cuối: docs/gap-review.md; bộ ảnh 4 trạng thái của W01–W05 tại evidence/web/.");
  s.addNotes("Slide 11 trình bày hệ thống UI/UX trên cả Mobile và Web, minh chứng việc xử lý đủ 4 trạng thái (Empty, Loading, Error, Success) và các chỉnh sửa thực tế sau góp ý ở Lab 2 & Lab 3.");
}

// 12 / SEQUENCE DIAGRAM
{
  const s = makeSlide(
    "p2",
    "12 / SEQUENCE DIAGRAM",
    "Sơ đồ tuần tự luồng duyệt và từ chối đơn liên vai trò (WF-02) qua thời gian thực",
    "Thể hiện rõ thông điệp gọi giữa các tầng UI → ViewModel → Repository → Firestore & nhánh rẽ [alt] theo Business Rule BR-03",
    "12 / 24"
  );

  addCard(s, 0.45, 1.32, 12.43, 5.15, {
    tag: "SEQUENCE DIAGRAM · WF-02 DUYỆT / TỪ CHỐI ĐƠN LIÊN VAI TRÒ (WEB ADMIN ↔ FIRESTORE ↔ MOBILE KHÁCH)",
    tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 7.4,
  });

  // Lifelines across the top
  const lifelines = [
    ["Khách hàng\n:Mobile UI (S07/S19)", 0.75, PAL.p1.bg, PAL.p1.fg],
    ["OrderTrackingVM\n:ViewModel (Mobile)", 3.15, PAL.p1.bg, PAL.p1.fg],
    ["Cloud Firestore\n+ Security Rules", 5.65, PAL.p2.bg, PAL.p2.fg],
    ["OrderRepository\n:packages/core", 8.25, PAL.ink, PAL.white],
    ["Nhân viên Kiosk\n:Web UI & VM (W03)", 10.65, PAL.p3.bg, PAL.p3.fg],
  ];
  lifelines.forEach(([lbl, x, bg, fg]) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y: 1.75, w: 1.95, h: 0.58, rectRadius: 0.06,
      fill: { color: bg }, line: { color: fg, width: 1 },
    });
    s.addText(lbl, {
      x, y: 1.75, w: 1.95, h: 0.58, fontSize: 9, bold: true, color: fg,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
    // Vertical dashed lifeline
    s.addShape(pres.shapes.LINE, {
      x: x + 0.975, y: 2.33, w: 0, h: 3.95,
      line: { color: PAL.border, width: 1, dashType: "dash" },
    });
  });

  // Sequence steps as horizontal call bars
  const seqStep = (y, x1, x2, label, bg = PAL.cardAlt, fg = PAL.ink) => {
    const left = Math.min(x1, x2);
    const w = Math.abs(x2 - x1);
    const dir = x2 > x1 ? "→ " : "← ";
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: left, y, w, h: 0.36, rectRadius: 0.04,
      fill: { color: bg }, line: { color: fg, width: 0.75 },
    });
    s.addText(dir + label, {
      x: left + 0.08, y, w: w - 0.16, h: 0.36, fontSize: 8.8, bold: true, color: fg,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
  };

  seqStep(2.45, 1.72, 6.62, "1. watchOrder(orderId) & watchNotifications(uid) — mở kết nối lắng nghe Snapshot", PAL.p1.bg, PAL.p1.fg);
  seqStep(2.88, 6.62, 11.62, "2. watchKioskOrders(kioskId) — đẩy đơn mới #QLOTIR (status: pending) lên màn W03", PAL.p3.bg, PAL.p3.fg);

  // Alt frame box
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.65, y: 3.35, w: 12.0, h: 2.95, rectRadius: 0.06,
    fill: { type: "none" }, line: { color: PAL.p2.fg, width: 1.2 },
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 0.65, y: 3.35, w: 2.85, h: 0.26, rectRadius: 0.04,
    fill: { color: PAL.p2.fg }, line: { type: "none" },
  });
  s.addText("alt [Nhánh 1: Duyệt đơn hợp lệ — BR-03]", {
    x: 0.65, y: 3.35, w: 2.85, h: 0.26, fontSize: 8.5, bold: true, color: PAL.white,
    align: "center", valign: "middle", margin: 0, isTextBox: true,
  });

  seqStep(3.68, 11.62, 9.22, "3a. approveOrder(orderId, 10 phút)", PAL.ok.bg, PAL.ok.fg);
  seqStep(4.1, 9.22, 6.62, "4a. Ghi orders/{id}='preparing' + notifications/{id} [Rule R-47]", PAL.ok.bg, PAL.ok.fg);
  seqStep(4.52, 6.62, 1.72, "5a. onSnapshot phát sự kiện tức thì → S07 đổi sang 'Đang làm (10 phút)' sau 1,09s – 1,22s", PAL.ok.bg, PAL.ok.fg);

  // Divider for else branch
  s.addShape(pres.shapes.LINE, {
    x: 0.65, y: 4.98, w: 12.0, h: 0,
    line: { color: PAL.danger.fg, width: 1, dashType: "dash" },
  });
  s.addText("[Nhánh 2 (Exception): Từ chối đơn — BR-03 bắt buộc có lý do rejectionReason (Rule R-49)]", {
    x: 0.75, y: 5.02, w: 7.5, h: 0.24, fontSize: 8.5, bold: true, color: PAL.danger.fg, margin: 0, isTextBox: true,
  });

  seqStep(5.3, 11.62, 6.62, "3b. rejectOrder(orderId, reason) → Nếu reason rỗng: Rule R-49 trả về PERMISSION_DENIED", PAL.danger.bg, PAL.danger.fg);
  seqStep(5.74, 6.62, 1.72, "4b. Nếu có lý do hợp lệ: orders/{id}='cancelled' → S07 & Hộp thư S19 hiện 'Đã huỷ kèm lý do' (1,09s)", PAL.warn.bg, PAL.warn.fg);

  addEvidenceBar(s, "TÀI LIỆU ĐỐI CHIẾU", "Sơ đồ tuần tự chi tiết cho cả 2 luồng liên vai trò nằm tại docs/cross-role-flow.md; kiểm thử tự động bởi TC-42, TC-43 và R-47..R-50.");
  s.addNotes("Slide 12 vẽ Sequence Diagram của luồng duyệt đơn liên vai trò (WF-02), đi qua đúng 5 thành phần từ UI Web, Repository trong packages/core, Firestore + Security Rules sang ViewModel và UI Mobile, kèm khung alt cho cả nhánh duyệt và nhánh từ chối theo BR-03.");
}

// 13 / CLASS DESIGN
{
  const s = makeSlide(
    "p2",
    "13 / CLASS DESIGN",
    "Thiết kế lớp theo mẫu MVVM + Repository, kiểm soát ranh giới tầng bằng Architecture Test",
    "Màn hình (Widget) chỉ lắng nghe ViewModel; ViewModel phụ thuộc vào Interface Repository trong packages/core",
    "13 / 24"
  );

  const cols = [
    [
      "1. PRESENTATION LAYER\n(mobile/lib & web/lib)",
      PAL.p1.bg, PAL.p1.fg,
      [
        ["CheckoutScreen / OrderQueuePage", "+ build(context)\n- chỉ vẽ UI theo state của VM\n- không import cloud_firestore"],
        ["CheckoutViewModel (ChangeNotifier)", "+ submitOrder(cart, slot, voucher)\n+ state: AsyncStatus\n- gọi OrderRepository & VoucherRepo"],
        ["OrderQueueViewModel (Web/Mobile)", "+ approve(orderId, minutes)\n+ reject(orderId, reason)\n+ watchQueue(kioskId)"],
        ["MenuItemFormViewModel (K14)", "+ suggestFromPhoto(bytes)\n+ saveMenuItem(draft)\n- gọi MenuAiService & MenuItemRepo"],
      ],
    ],
    [
      "2. REPOSITORY & SERVICE LAYER\n(packages/core & mobile services)",
      PAL.p2.bg, PAL.p2.fg,
      [
        ["<<interface>> OrderRepository", "+ createOrder(Order): Future<String>\n+ watchOrder(id): Stream<Order>\n+ updateStatus(id, status, reason)"],
        ["FirestoreOrderRepository", "- _db: FirebaseFirestore\n+ cài đặt truy vấn & ghi batch\norders/{id} + notifications/{id}"],
        ["<<interface>> MenuAiService", "+ analyzeDishPhoto(Uint8List)\n  : Future<MenuItemSuggestion>"],
        ["FirebaseMenuAiService", "- _remoteConfig: FirebaseRemoteConfig\n- _ai: FirebaseVertexAI / Gemini\n+ ép kiểu theo JSON Schema cố định"],
      ],
    ],
    [
      "3. DOMAIN ENTITY LAYER\n(packages/core/lib/src/models)",
      PAL.ok.bg, PAL.ok.fg,
      [
        ["Order & OrderItem (Immutable)", "+ id, userId, kioskId, items\n+ status: OrderStatus\n+ totalAmount, pickupCode, reason\n+ copyWith(), toMap(), fromMap()"],
        ["MenuItem & MenuItemSuggestion", "+ id, kioskId, name, category\n+ price, prepMinutes, imageUrl\n+ isAvailable, isFood (AI guard)"],
        ["AppNotification & Announcement", "+ id, userId, title, body, type\n+ kioskId, isArchived, createdAt"],
        ["UserProfile & RoleGuard", "+ uid, email, role (user|staff|admin)\n+ kioskId (cho staff)\n+ canAccessWebAdmin(), canManageKiosk()"],
      ],
    ],
  ];

  cols.forEach(([header, bg, fg, classes], cIdx) => {
    const x = 0.45 + cIdx * 4.22;
    addCard(s, x, 1.32, 4.0, 5.15, { tag: header, tagBg: bg, tagFg: fg, tagW: 3.72 });
    classes.forEach(([clsName, members], rIdx) => {
      const cy = 1.9 + rIdx * 1.12;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.14, y: cy, w: 3.72, h: 1.02, rectRadius: 0.05,
        fill: { color: PAL.cardAlt }, line: { color: PAL.border, width: 0.75 },
      });
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.14, y: cy, w: 3.72, h: 0.26, rectRadius: 0.04,
        fill: { color: PAL.ink }, line: { type: "none" },
      });
      s.addText(clsName, {
        x: x + 0.2, y: cy, w: 3.6, h: 0.26, fontSize: 8.8, bold: true, color: PAL.white,
        align: "left", valign: "middle", margin: 0, isTextBox: true,
      });
      s.addText(members, {
        x: x + 0.2, y: cy + 0.28, w: 3.6, h: 0.72, fontSize: 8.4, color: PAL.ink,
        align: "left", valign: "top", margin: 0, isTextBox: true,
      });
    });
  });

  addEvidenceBar(s, "ARCHITECTURE TEST", "Kiểm chứng tự động bằng mobile/test/architecture_test.dart & web/test/architecture_test.dart: cấm Widget gọi thẳng Firebase SDK.");
  s.addNotes("Slide 13 trình bày thiết kế lớp (Class Design) chia làm 3 tầng: Presentation (Widget + ViewModel), Repository/Service Interface & Implementation, và Domain Entities bất biến trong packages/core.");
}

// 14 / DATABASE DESIGN — CONCEPTUAL
{
  const s = makeSlide(
    "p2",
    "14 / DATABASE DESIGN — CONCEPTUAL",
    "Mô hình dữ liệu khái niệm gồm 12 thực thể miền (Domain Entities) và bản số quan hệ",
    "Tâm điểm là thực thể Order liên kết giữa User, Kiosk, MenuItem, Slot, Voucher, Review, Incident và Notification",
    "14 / 24"
  );

  addCard(s, 0.45, 1.32, 8.2, 5.15, {
    tag: "CONCEPTUAL ERD · MÔ HÌNH QUAN HỆ THỰC THỂ & BẢN SỐ (CARDINALITY)",
    tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 4.8,
  });

  const ent = (x, y, w, h, name, attrs, bg, fg) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y, w, h, rectRadius: 0.06, fill: { color: bg }, line: { color: fg, width: 1 },
    });
    s.addText([
      { text: `${name}\n`, options: { bold: true, fontSize: 9.5, color: fg } },
      { text: attrs, options: { fontSize: 8.2, color: PAL.ink } },
    ], { x: x + 0.08, y: y + 0.05, w: w - 0.16, h: h - 0.1, margin: 0, isTextBox: true });
  };

  // Top row entities
  ent(0.65, 1.82, 2.2, 1.1, "User (users)", "PK: uid\nrole: user|staff|admin\nkioskId (0..1 cho staff)", PAL.p1.bg, PAL.p1.fg);
  ent(3.45, 1.82, 2.2, 1.1, "Kiosk (kiosks)", "PK: kioskId\nname, isOpen\nopeningHours", PAL.p3.bg, PAL.p3.fg);
  ent(6.2, 1.82, 2.25, 1.1, "MenuItem (menu_items)", "PK: itemId, FK: kioskId\nname, price, category\nisAvailable, prepMinutes", PAL.p3.bg, PAL.p3.fg);

  // Middle row entities (Order at center)
  ent(0.65, 3.35, 2.2, 1.1, "Voucher & Slot", "vouchers (PK: code)\nslots (PK: slotId, FK: kioskId)\nmaxOrders, currentCount", PAL.cardAlt, PAL.ink2);
  ent(3.3, 3.25, 2.5, 1.3, "Order (orders) [TRUNG TÂM]", "PK: orderId\nFK: userId (1..*), kioskId (1..*)\nitems[], status, totalAmount\npickupCode, rejectionReason", PAL.warn.bg, PAL.warn.fg);
  ent(6.2, 3.35, 2.25, 1.1, "Review & Incident", "reviews (0..1 per Order)\nincidents (0..* per Order)\nrating, comment, photoUrl", PAL.cardAlt, PAL.ink2);

  // Bottom row entities
  ent(0.65, 4.9, 2.4, 1.1, "Notification (notifications)", "PK: notifId, FK: userId (1..*)\nFK: orderId (0..1)\ntitle, body, isRead", PAL.ok.bg, PAL.ok.fg);
  ent(3.45, 4.9, 2.4, 1.1, "Announcement", "PK: annId (announcements)\ntargetKioskId (all | kioskId)\nisArchived, createdBy", PAL.ok.bg, PAL.ok.fg);
  ent(6.2, 4.9, 2.25, 1.1, "AuditLog & Config", "audit_logs (1..* per Actor)\nsystem_configs (singleton)\ncarts (1..1 per User)", PAL.cardAlt, PAL.ink2);

  // Right card: Cardinality & Domain Rules governing relationships
  addCard(s, 8.85, 1.32, 4.03, 5.15, {
    tag: "QUAN HỆ & QUY TẮC MIỀN DỮ LIỆU",
    tagBg: PAL.ink, tagFg: PAL.white, tagW: 2.8,
  });
  const rels = [
    ["User (1) ──< (0..*) Order", "Mỗi khách tạo nhiều đơn; đơn luôn gắn cứng với userId của người đặt (R-44)."],
    ["Kiosk (1) ──< (0..*) MenuItem & Order", "Mỗi món ăn và mỗi đơn hàng thuộc về đúng 1 Kiosk cụ thể (kioskId)."],
    ["Order (1) ──< (1..*) OrderItem (Nhúng)", "Danh sách món đã đặt được nhúng trực tiếp kèm snapshot giá tại thời điểm mua."],
    ["Order (1) ── (0..1) Review / (0..*) Incident", "Khách chỉ đánh giá được đơn của mình; sự cố gắn với đơn hoặc Kiosk."],
    ["Kiosk (0..1) ──< (0..*) Announcement", "Thông báo của Admin có thể gửi toàn trường (null) hoặc riêng 1 Kiosk."],
  ];
  rels.forEach(([r, d], i) => {
    const ry = 1.82 + i * 0.9;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 9.0, y: ry, w: 3.73, h: 0.8, rectRadius: 0.05,
      fill: { color: i % 2 === 0 ? PAL.cardAlt : PAL.card },
      line: { color: PAL.borderSoft, width: 0.6 },
    });
    s.addText([
      { text: `${r}\n`, options: { bold: true, fontSize: 9.5, color: PAL.p2.fg } },
      { text: d, options: { fontSize: 8.6, color: PAL.ink } },
    ], { x: 9.1, y: ry + 0.05, w: 3.53, h: 0.7, margin: 0, isTextBox: true });
  });

  addEvidenceBar(s, "TÀI LIỆU DỮ LIỆU", "Đặc tả đầy đủ 12 collection và quan hệ trong docs/data-model.md.");
  s.addNotes("Slide 14 trình bày mô hình dữ liệu khái niệm (Conceptual Database Design) với 12 thực thể miền và bản số quan hệ xung quanh thực thể trung tâm là Order.");
}

// 15 / DATABASE DESIGN — LOGICAL -> PHYSICAL
{
  const s = makeSlide(
    "p2",
    "15 / DATABASE DESIGN — LOGICAL → PHYSICAL",
    "Thiết kế vật lý trên Cloud Firestore: lược đồ tài liệu, Composite Indexes và Security Rules",
    "Nhúng (Embed) danh sách món trong Order để giữ lịch sử giá; tách Collection riêng cho các thực thể truy vấn độc lập",
    "15 / 24"
  );

  const schemaRows = [
    [
      tblCell("Collection vật lý", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Khóa & Trường dữ liệu chính (Document Schema)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Chỉ mục (Index) & Ràng buộc Security Rules", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("orders/{orderId}", { bold: true, fill: PAL.card }),
      tblCell("userId, kioskId, items: [{itemId, name, price, qty}], totalAmount, status ('pending'|'preparing'|'ready'|'delivered'|'cancelled'), pickupCode, estimatedMinutes, rejectionReason, createdAt", { fill: PAL.card, fontSize: 9.2 }),
      tblCell("Index: (kioskId ASC, status ASC, createdAt DESC) & (userId ASC, createdAt DESC).\nRules R-44..R-52: kiểm tra chủ đơn, staffOf(kioskId) và trạng thái chuyển.", { fill: PAL.card, fontSize: 9.2 }),
    ],
    [
      tblCell("users/{uid}", { bold: true, fill: PAL.cardAlt }),
      tblCell("email, displayName, role ('user'|'staff'|'admin'), kioskId (nullable), phone, createdAt, updatedAt", { fill: PAL.cardAlt, fontSize: 9.2 }),
      tblCell("Rules R-01..R-08: User tạo profile mặc định role='user'; cấm tự nâng quyền (R-02); chỉ Admin đổi được role (R-05).", { fill: PAL.cardAlt, fontSize: 9.2 }),
    ],
    [
      tblCell("menu_items/{itemId}", { bold: true, fill: PAL.card }),
      tblCell("kioskId, name, category, price (> 0), prepMinutes, description, imageUrl (Cloudinary), isAvailable, updatedAt", { fill: PAL.card, fontSize: 9.2 }),
      tblCell("Index: (kioskId ASC, category ASC).\nRules R-33..R-39: Ai đăng nhập cũng đọc được; chỉ staffOf(kioskId) hoặc Admin được thêm/sửa.", { fill: PAL.card, fontSize: 9.2 }),
    ],
    [
      tblCell("announcements/{id}\n& notifications/{id}", { bold: true, fill: PAL.cardAlt }),
      tblCell("announcements: title, body, targetKioskId, isArchived, createdAt.\nnotifications: userId, orderId, title, body, isRead, createdAt.", { fill: PAL.cardAlt, fontSize: 9.2 }),
      tblCell("Index: (isArchived ASC, createdAt DESC) & (userId ASC, createdAt DESC).\nRules R-61..R-77: Chỉ Admin viết được announcements (R-74).", { fill: PAL.cardAlt, fontSize: 9.2 }),
    ],
  ];

  s.addTable(schemaRows, {
    x: 0.45, y: 1.32, w: 12.43, colW: [2.15, 5.55, 4.73],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 0.72,
  });

  // Bottom summary bar of physical design choices
  addCard(s, 0.45, 5.45, 12.43, 1.05, {
    fill: PAL.p2.bg,
    tag: "QUYẾT ĐỊNH THIẾT KẾ VẬT LÝ NOSQL (DENORMALIZATION & SECURITY)",
    tagBg: PAL.p2.fg, tagFg: PAL.white, tagW: 4.5,
  });
  s.addText([
    { text: "• Nhúng OrderItem vào orders/{orderId}: ", options: { bold: true } },
    { text: "Đảm bảo khi Kiosk đổi giá món ăn ở menu_items, hóa đơn cũ của khách không bị nhảy giá và đọc 1 document là vẽ được ngay màn S07/S12.\n" },
    { text: "• Quy tắc cuối cùng mặc định từ chối (Default Deny): ", options: { bold: true } },
    { text: "match /{document=**} { allow read, write: if false; } — kiểm chứng bằng 172 test tự động." },
  ], { x: 0.6, y: 5.83, w: 12.1, h: 0.6, fontSize: 9.6, color: PAL.ink, margin: 0, isTextBox: true });

  addEvidenceBar(s, "MINH CHỨNG SCHEMA", "Tệp cấu hình thật: firebase/firestore.rules, firebase/firestore.indexes.json và docs/data-model.md.");
  s.addNotes("Slide 15 chuyển từ mô hình khái niệm sang thiết kế vật lý trên Cloud Firestore: giải thích cấu trúc document, các composite index trong firestore.indexes.json và lý do nhúng OrderItem vào trong Order.");
}

// 16 / TRACEABILITY MATRIX (CLOSING DESIGN SECTION)
{
  const s = makeSlide(
    "p2",
    "16 / TRACEABILITY",
    "Ma trận truy vết hai chiều từ Yêu cầu / Workflow tới Màn hình, Lớp xử lý, Dữ liệu và Kiểm thử",
    "Đảm bảo không có tính năng nào thiếu kiểm thử và mọi bảng dữ liệu đều gắn với một luồng nghiệp vụ xác định",
    "16 / 24"
  );

  const traceRows = [
    [
      tblCell("Workflow / Nhóm yêu cầu", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Màn hình UI (Mobile & Web)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("ViewModel & Service", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Collection & Rules", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Test Cases nghiệm thu", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("Xác thực & Phân quyền 3 vai trò (RBAC)", { bold: true, fill: PAL.card }),
      tblCell("Mobile S01, K01\nWeb W01 (Login & Role Gate)", { fill: PAL.card }),
      tblCell("AuthViewModel\nRoleGuard (packages/core)", { fill: PAL.card }),
      tblCell("users/{uid}\nRules R-01..R-08", { fill: PAL.card }),
      tblCell("ARTEMIS TC-01, TC-02, TC-20 (3/3)\nWeb W01 Checklist · Rules R-01..08", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
    [
      tblCell("WF-01 · Đặt trước & thanh toán đơn món", { bold: true, fill: PAL.cardAlt }),
      tblCell("Mobile S02 → S03 → S04 → S05 → S06 → S07 → S12", { fill: PAL.cardAlt }),
      tblCell("CartViewModel\nCheckoutViewModel\nOrderRepository", { fill: PAL.cardAlt }),
      tblCell("carts/{uid}, vouchers/{id}, slots/{id}, orders/{id}\nRules R-17..R-45", { fill: PAL.cardAlt }),
      tblCell("ARTEMIS TC-03..TC-09 (3/3)\nUnit/Widget tests · Rules R-44, R-45", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
    [
      tblCell("WF-02 · Duyệt đơn & Thông báo liên vai trò", { bold: true, fill: PAL.card }),
      tblCell("Web W03, W05 ↔ Mobile S07, S19; Mobile K02–K05", { fill: PAL.card }),
      tblCell("OrderQueueViewModel\nAnnouncementViewModel\nNotificationRepository", { fill: PAL.card }),
      tblCell("orders/{id}, notifications/{id}, announcements/{id}\nRules R-46..R-77", { fill: PAL.card }),
      tblCell("ARTEMIS TC-42, TC-43 (3/3)\n3 lần đo thật (1,09s–1,22s) · R-47..R-75", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
    [
      tblCell("WF-03 · Thêm món bằng AI & Remote Config", { bold: true, fill: PAL.cardAlt }),
      tblCell("Mobile K14 (Form món)\nMobile K06, Web W02", { fill: PAL.cardAlt }),
      tblCell("MenuItemFormViewModel\nFirebaseMenuAiService\nCloudinaryService", { fill: PAL.cardAlt }),
      tblCell("menu_items/{id}\nRemote Config (ai_enabled)\nRules R-33..R-39", { fill: PAL.cardAlt }),
      tblCell("ARTEMIS TC-40, TC-41 (3/3)\n3 ảnh thật + ảnh lỗi · DebugView logs", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
    [
      tblCell("Thống kê, Đánh giá, Sự cố & Quản trị", { bold: true, fill: PAL.card }),
      tblCell("Mobile S10, S25, K09, K10\nWeb W04 + 8 trang Admin", { fill: PAL.card }),
      tblCell("DashboardViewModel\nReviewRepository\nIncidentRepository", { fill: PAL.card }),
      tblCell("reviews, incidents, kiosks, audit_logs, system_configs", { fill: PAL.card }),
      tblCell("ARTEMIS TC-10..TC-31 (3/3)\nWeb W02–W05 Checklist · R-53..R-80", { fill: PAL.ok.bg, color: PAL.ok.fg, bold: true }),
    ],
  ];

  s.addTable(traceRows, {
    x: 0.45, y: 1.35, w: 12.43, colW: [2.35, 2.35, 2.35, 2.55, 2.83],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 0.82,
  });

  addEvidenceBar(s, "KẾT LUẬN P2 DESIGN", "100% Workflow có đường nối khép kín từ UI → ViewModel → Repository → Firestore Collection → Automated Tests.");
  s.addNotes("Slide 16 khép lại phần P2 Design bằng Ma trận Truy vết (Traceability Matrix) nối từ từng Workflow sang màn hình, lớp xử lý, collection Firestore và bộ test tương ứng.");
}

// ============================================================================
// SECTION P3 · DEMO (SLIDES 17 - 20 — WORKFLOW-BY-WORKFLOW LIVE DEMO)
// ============================================================================

// 17 / DEMO PLAN (STORYBOARD)
{
  const s = makeSlide(
    "p3",
    "17 / DEMO PLAN",
    "Kịch bản Demo liên hoàn 3 chặng trên hệ thống thật, nối liền câu chuyện của một đơn hàng",
    "Đầu ra của chặng trước là đầu vào trực tiếp của chặng sau trên cùng dự án Firebase (breakbite-1315b)",
    "17 / 24"
  );

  const stages = [
    [
      "CHẶNG 1 · KHÁCH HÀNG ĐẶT MÓN (MOBILE)",
      "WF-01 · Đặt trước và thanh toán đơn món",
      [
        "1. Đăng nhập tài khoản Sinh viên (Quân) trên máy ảo Android.",
        "2. Chọn Kiosk đang mở cửa (S02 → S03), thêm món vào giỏ và kiểm tra mã giảm giá tại S05.",
        "3. Bấm Thanh toán tại S06 → tạo đơn mới ở trạng thái Chờ xác nhận (pending) tại màn S07.",
      ],
      "Đầu ra chuyển sang Chặng 2: Mã đơn #QLOTIR vừa tạo nằm trong collection orders/{id} với status = 'pending'.",
      PAL.p1.bg, PAL.p1.fg,
    ],
    [
      "CHẶNG 2 · LIÊN VAI TRÒ (WEB ↔ MOBILE)",
      "WF-02 · Duyệt đơn & Phát thông báo tức thì",
      [
        "1. Trên Web Admin (W03), nhân viên Kiosk thấy ngay đơn #QLOTIR, chọn 10 phút và bấm Duyệt → Mobile S07 tự đổi sang Đang làm sau ~1,22s.",
        "2. Thử từ chối đơn #25RPEH kèm lý do → Mobile hiện Đã huỷ kèm lý do sau 1,09s.",
        "3. Quản trị viên đăng thông báo tại W05 → Hộp thư Mobile S19 hiện thông báo trên cùng sau 1,13s.",
      ],
      "Đầu ra khẳng định: Đồng bộ hai chiều Web ↔ Mobile qua Firestore onSnapshot dưới 1,3 giây.",
      PAL.p3.bg, PAL.p3.fg,
    ],
    [
      "CHẶNG 3 · NHÂN VIÊN & AI (MOBILE + CONSOLE)",
      "WF-03 · Thêm món bằng AI & Tắt nóng từ xa",
      [
        "1. Nhân viên mở màn Thêm món K14 trên Android, chọn ảnh Bánh mì và bấm Điền bằng AI → Gemini điền sẵn 5 ô có nhãn 'Gợi ý từ AI'.",
        "2. Thử chọn ảnh không phải đồ ăn → AI từ chối lịch sự, giữ nguyên form nhập tay.",
        "3. Trên Firebase Console, đổi ai_enabled = false và Publish → nút AI trên điện thoại biến mất ngay lập tức.",
      ],
      "Đầu ra khẳng định: AI hoạt động an toàn có kiểm soát của con người và tắt nóng được từ xa.",
      PAL.p2.bg, PAL.p2.fg,
    ],
  ];

  stages.forEach(([badge, title, bullets, handoff, bg, fg], i) => {
    const x = 0.45 + i * 4.22;
    addCard(s, x, 1.32, 4.0, 3.95, { tag: badge, tagBg: bg, tagFg: fg, tagW: 3.72, title, titleH: 0.4 });
    s.addText(bullets.join("\n\n"), {
      x: x + 0.14, y: 2.25, w: 3.72, h: 2.05, fontSize: 9.8, color: PAL.ink, margin: 0, isTextBox: true,
    });
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: x + 0.14, y: 4.35, w: 3.72, h: 0.78, rectRadius: 0.05,
      fill: { color: bg }, line: { type: "none" },
    });
    s.addText(handoff, {
      x: x + 0.22, y: 4.38, w: 3.56, h: 0.72, fontSize: 9, bold: true, color: fg,
      margin: 0, isTextBox: true, valign: "middle",
    });
  });

  // Preparation checklist bar (mandatory per Guideline Slide 17)
  addCard(s, 0.45, 5.4, 12.43, 1.08, {
    fill: PAL.cardAlt,
    tag: "CHUẨN BỊ MÔI TRƯỜNG DEMO & PHƯƠNG ÁN DỰ PHÒNG (DEMO READINESS)",
    tagBg: PAL.ink, tagFg: PAL.white, tagW: 4.8,
  });
  s.addText([
    { text: "• Tài khoản & Dữ liệu sẵn sàng: ", options: { bold: true } },
    { text: "3 tài khoản thật (Khách hàng, Nhân viên Kiosk, Quản trị viên) đã đăng nhập sẵn trên Android Emulator Pixel 6 và trình duyệt Web Admin.\n" },
    { text: "• App Check & Video dự phòng: ", options: { bold: true } },
    { text: "Debug token của máy ảo đã trích xuất sẵn; toàn bộ 3 chặng đều có video quay màn hình thực tế độ phân giải cao (https://youtu.be/T-h7nM4lTbc)." },
  ], { x: 0.6, y: 5.8, w: 12.1, h: 0.62, fontSize: 9.6, color: PAL.ink2, margin: 0, isTextBox: true });

  addEvidenceBar(s, "LINK VIDEO DEMO", "Video trình diễn trọn vẹn 5 phút 25 giây trên hệ thống thật: https://youtu.be/T-h7nM4lTbc (xem kịch bản tại slides/principles-script.md).");
  s.addNotes("Slide 17 trình bày Storyboard 3 chặng liên hoàn của buổi Demo: từ lúc khách đặt đơn trên điện thoại, sang nhân viên duyệt đơn trên Web Admin, đến lúc nhân viên thêm món mới bằng AI và quản trị viên tắt AI qua Remote Config.");
}

// Helper for Unified Workflow Demo Slides 18, 19, 20 (matching Guideline Slides 18-20 & W11)
function buildUnifiedWorkflowSlide(codeLabel, slideNum, wfTitle, wfMeta, fiveSteps, stateTransition, exceptions, evidenceText, renderVisuals) {
  const s = makeSlide("p3", codeLabel, wfTitle, wfMeta, slideNum);

  // Top: 5-step horizontal workflow bar (y = 1.30, h = 1.08)
  fiveSteps.forEach(([stepNum, stepTitle, stepDesc], i) => {
    const x = 0.45 + i * 2.51;
    const isCheck = i === 2;
    const isEnd = i === 4;
    const bg = isEnd ? PAL.ok.bg : isCheck ? PAL.warn.bg : PAL.card;
    const fg = isEnd ? PAL.ok.fg : isCheck ? PAL.warn.fg : PAL.p3.fg;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x, y: 1.3, w: 2.38, h: 1.08, rectRadius: 0.06,
      fill: { color: bg }, line: { color: fg, width: 1 },
    });
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: x + 0.08, y: 1.36, w: 2.22, h: 0.24, rectRadius: 0.04,
      fill: { color: fg }, line: { type: "none" },
    });
    s.addText(`${stepNum} · ${stepTitle}`, {
      x: x + 0.08, y: 1.36, w: 2.22, h: 0.24, fontSize: 8.5, bold: true, color: PAL.white,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
    s.addText(stepDesc, {
      x: x + 0.08, y: 1.64, w: 2.22, h: 0.68, fontSize: 8.8, color: PAL.ink,
      align: "center", valign: "middle", margin: 0, isTextBox: true,
    });
    if (i < 4) {
      s.addText("→", {
        x: x + 2.38, y: 1.65, w: 0.13, h: 0.35, fontSize: 12, bold: true, color: PAL.muted,
        align: "center", valign: "middle", margin: 0, isTextBox: true,
      });
    }
  });

  // Bottom-Left: TRẠNG THÁI, EXCEPTION, EVIDENCE cards
  addCard(s, 0.45, 2.52, 5.55, 0.92, {
    tag: "TRẠNG THÁI DỮ LIỆU (STATE CHANGE)",
    tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 2.75,
  });
  s.addText(stateTransition, {
    x: 0.59, y: 2.9, w: 5.27, h: 0.48, fontSize: 9.5, bold: true, color: PAL.ink, margin: 0, isTextBox: true,
  });

  addCard(s, 0.45, 3.54, 5.55, 1.85, {
    tag: "LUỒNG NGOẠI LỆ & CƠ CHẾ CHẶN (EXCEPTION PATHS)",
    tagBg: PAL.danger.bg, tagFg: PAL.danger.fg, tagW: 3.55,
  });
  s.addText(exceptions, {
    x: 0.59, y: 3.94, w: 5.27, h: 1.38, fontSize: 9.2, color: PAL.ink, margin: 0, isTextBox: true, paraSpaceAfter: 3,
  });

  addCard(s, 0.45, 5.49, 5.55, 1.0, {
    tag: "BẰNG CHỨNG KIỂM THỬ (VERIFIED EVIDENCE)",
    tagBg: PAL.ok.bg, tagFg: PAL.ok.fg, tagW: 3.1,
  });
  s.addText(evidenceText, {
    x: 0.59, y: 5.87, w: 5.27, h: 0.56, fontSize: 9.2, color: PAL.ink, margin: 0, isTextBox: true,
  });

  // Bottom-Right: Real screenshots / visual evidence
  addCard(s, 6.18, 2.52, 6.7, 3.97, {
    tag: "MÀN HÌNH THỰC TẾ TRONG LUỒNG DEMO",
    tagBg: PAL.p3.bg, tagFg: PAL.p3.fg, tagW: 2.95,
  });
  renderVisuals(s);

  return s;
}

// 18 / DEMO WF-01
{
  const s = buildUnifiedWorkflowSlide(
    "18 / DEMO WF-01",
    "18 / 24",
    "WF-01 · Đặt trước và thanh toán đơn món (Khách hàng trên Android)",
    "Actor: Khách hàng (Sinh viên)  |  Mục tiêu: Hoàn tất đặt đơn trước giờ giải lao trong < 35 giây, hiển thị rõ tổng tiền ngay từ giỏ",
    [
      ["B1", "Trigger", "Khách mở S02, chọn Kiosk đang mở cửa (S03)"],
      ["B2", "Chọn món & Giỏ", "Thêm món (S04), xem tổng tiền & áp voucher tại S05"],
      ["B3", "Kiểm tra BR-01,02", "Kiosk còn nhận đơn? Voucher còn hạn & đủ điều kiện?"],
      ["B4", "Thanh toán (S06)", "Chọn khung giờ lấy món & xác nhận thanh toán"],
      ["B5", "Kết quả (S07)", "Tạo đơn pending, sinh mã QR nhận món & xoá giỏ"],
    ],
    "carts/{uid} (đang chọn)  ──[CheckoutViewModel.submitOrder]──►  orders/{orderId} (status = 'pending', pickupCode) + carts/{uid} (làm trống)",
    [
      { text: "• E1 — Mã giảm giá hết hạn hoặc chưa đủ đơn tối thiểu (BR-02): ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Màn S05 báo lỗi trực tiếp dưới ô nhập mã (S05-VOUCHER-ERR), giữ nguyên các món trong giỏ.\n" },
      { text: "• E2 — Quầy Kiosk vừa đóng cửa hoặc hết slot nhận đơn (BR-01): ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Chuyển sang màn thông báo quầy tạm ngưng nhận đơn (S21), không trừ tiền khách.\n" },
      { text: "• E3 — Lỗi thanh toán giả lập (S06-ERR): ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Giữ nguyên giỏ hàng để khách bấm thử lại, tuyệt đối không tạo đơn rác trên Firestore." },
    ],
    "• ARTEMIS E2E: TC-03, TC-04, TC-05, TC-06, TC-07 (đặt đơn, áp voucher, lỗi thanh toán, xem biên nhận) đều đạt 3/3 lần chạy.\n• Security Rules: R-44 (chỉ tạo đơn cho chính uid của mình), R-45 (bắt buộc status khởi tạo là 'pending' và totalAmount > 0).",
    (slide) => {
      phone(slide, "s02-home", 6.55, 2.95, 2.8, 3.4, "Màn S02: Chọn Kiosk & Món ăn");
      phone(slide, "s07-tracking", 9.65, 2.95, 2.8, 3.4, "Màn S07: Đơn vừa tạo & Mã QR");
    }
  );
  addEvidenceBar(s, "MINH CHỨNG WF-01", "Ảnh chụp các bước S02–S12 tại evidence/p1/ và báo cáo kiểm thử tự động ARTEMIS tại docs/test-report.md mục 1.");
  s.addNotes("Slide 18 trình bày WF-01 theo bố cục chuẩn của Guideline: thanh 5 bước ngang ở trên, 3 hộp Trạng thái / Ngoại lệ / Bằng chứng bên trái và 2 màn hình điện thoại thật S02, S07 bên phải.");
}

// 19 / DEMO WF-02
{
  const s = buildUnifiedWorkflowSlide(
    "19 / DEMO WF-02",
    "19 / 24",
    "WF-02 · Duyệt đơn hàng và phát thông báo liên vai trò (Web Admin ↔ Mobile)",
    "Actor: Nhân viên Kiosk / Admin (Web) & Khách hàng (Mobile)  |  Mục tiêu: Đồng bộ quyết định duyệt/từ chối và thông báo dưới 1,5 giây",
    [
      ["B1", "Trigger", "Đơn #QLOTIR vừa đặt hiện ngay ở hàng chờ W03"],
      ["B2", "Thao tác trên Web", "Nhân viên chọn 10 phút làm món (hoặc nhập lý do huỷ)"],
      ["B3", "Kiểm tra BR-03", "Rule R-47 (staffOf kiosk) & R-49 (có lý do từ chối)"],
      ["B4", "Đồng bộ Firestore", "Cập nhật orders/{id} + ghi notifications/{id}"],
      ["B5", "Kết quả (~1,15s)", "Mobile S07 đổi sang Đang làm & S19 nhận thông báo"],
    ],
    "orders/{id}: pending ──[approveOrder / rejectOrder]──► preparing (kèm estimatedMinutes) HOẶC cancelled (kèm rejectionReason) + notifications/{id}",
    [
      { text: "• E1 — Nhân viên bấm Từ chối nhưng để trống lý do (BR-03): ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Form W03 khóa nút xác nhận; nếu gọi thẳng API, Firestore Rule R-49 chặn với lỗi PERMISSION_DENIED.\n" },
      { text: "• E2 — Nhân viên Kiosk A cố tình duyệt đơn của Kiosk B: ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Firestore Rule R-50 kiểm tra users/{uid}.kioskId == resource.data.kioskId và từ chối ngay.\n" },
      { text: "• E3 — Khách hàng tự gọi hàm duyệt đơn của chính mình: ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Firestore Rule R-46 chặn khách đổi trạng thái sang preparing/ready/delivered." },
    ],
    "• 3 lần đo thật Duyệt/Từ chối đơn (screenrecord --bugreport): #QLOTIR = 1,22s · #25RPEH (Từ chối) = 1,09s · #S7SWIR = 1,14s.\n• Luồng Admin đăng thông báo W05 → Hộp thư S19: 1,13s (đăng mới) & 0,81s (lưu trữ) · ARTEMIS TC-42, TC-43 đạt 3/3.",
    (slide) => {
      screen(slide, "x1-approved", 6.35, 2.95, 6.35, 1.68, "Luồng 1: Web W03 vừa duyệt đơn → Điện thoại đổi sang Đang làm (1,22s)");
      screen(slide, "x2-inbox", 6.35, 4.72, 6.35, 1.68, "Luồng 2: Web W05 vừa đăng thông báo → Hộp thư S19 nhận ngay (1,13s)");
    }
  );
  addEvidenceBar(s, "MINH CHỨNG WF-02", "Dữ liệu đo độ trễ từng khung hình: evidence/cross-role/measurements.json, video x1.mp4 & x2.mp4, và docs/cross-role-flow.md.");
  s.addNotes("Slide 19 trình bày WF-02 liên vai trò giữa Web Admin và Mobile: cả luồng nhân viên duyệt/từ chối đơn (1,09s–1,22s) lẫn luồng quản trị viên phát thông báo (1,13s) đều có ảnh quay song song hai màn hình.");
}

// 20 / DEMO WF-03
{
  const s = buildUnifiedWorkflowSlide(
    "20 / DEMO WF-03",
    "20 / 24",
    "WF-03 · Tạo món mới từ ảnh bằng AI Gemini & Điều khiển qua Remote Config",
    "Actor: Nhân viên Kiosk (Mobile K14) & Admin (Remote Config)  |  Mục tiêu: Giảm thao tác nhập thực đơn nhưng vẫn có người duyệt và công tắc tắt nóng",
    [
      ["B1", "Trigger", "Nhân viên mở K14, chụp hoặc chọn ảnh món ăn"],
      ["B2", "Gọi AI Logic", "Bấm 'Điền bằng AI' (gửi ảnh món + App Check token)"],
      ["B3", "Kiểm tra JSON/Food", "Gemini 3.5 Flash Lite kiểm tra isFood & điền 5 trường"],
      ["B4", "Nhân viên rà soát", "5 ô hiện nhãn 'Gợi ý từ AI'; nhân viên sửa lại nếu cần"],
      ["B5", "Kết quả", "Bấm Lưu → tải ảnh lên Cloudinary & ghi menu_items"],
    ],
    "Ảnh chụp món ăn (Uint8List) ──[FirebaseMenuAiService]──► MenuItemSuggestion (JSON) ──[Nhân viên duyệt & Lưu]──► menu_items/{itemId}",
    [
      { text: "• E1 — Ảnh không phải đồ ăn (ví dụ ảnh logo/phong cảnh): ", options: { bold: true, color: PAL.danger.fg } },
      { text: "AI trả về isFood = false → hiện cảnh báo đỏ dưới nút AI, không ghi đè form, nhân viên vẫn nhập tay bình thường.\n" },
      { text: "• E2 — Nhân viên đang gõ dở tay trong lúc chờ AI (Bug CR-F01 đã sửa): ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Không ghi đè lên ô mà nhân viên vừa chủ động sửa tay.\n" },
      { text: "• E3 — Quản trị viên tắt nóng ai_enabled = false trên Remote Config: ", options: { bold: true, color: PAL.danger.fg } },
      { text: "Ứng dụng lắng nghe onConfigUpdated, ẩn ngay nút 'Điền bằng AI' sau vài giây mà không cần build lại app." },
    ],
    "• Thử nghiệm thực tế với 3 ảnh món ăn Việt Nam (Bánh mì, Trà đào, Cơm gà) + 1 ảnh không phải món ăn (evidence/ai/).\n• ARTEMIS TC-40 (happy path) & TC-41 (error path) đạt 3/3 · Firebase Analytics DebugView ghi nhận đủ ai_request, ai_result_accepted, ai_error.",
    (slide) => {
      phone(slide, "k14-filled", 6.32, 2.95, 1.85, 3.4, "K14: AI điền 5 ô");
      phone(slide, "k14-not-food", 8.22, 2.95, 1.85, 3.4, "K14: Báo ảnh lỗi");
      screen(slide, "x3-ai-off", 10.15, 3.25, 2.6, 2.8, "Remote Config tắt nút AI");
    }
  );
  addEvidenceBar(s, "MINH CHỨNG WF-03", "Tài liệu thiết kế AI mức 2 (Structured Output + Remote Config + App Check + Analytics): docs/ai-feature.md & evidence/ai/.");
  s.addNotes("Slide 20 trình bày WF-03: tính năng AI điền thông tin món ăn từ ảnh chụp qua Firebase AI Logic, xử lý ngoại lệ khi ảnh không phải món ăn và minh chứng tắt nóng qua Remote Config.");
}

// ============================================================================
// SECTION P4 · PROOF (SLIDES 21 - 24)
// ============================================================================

// 21 / TESTING & VERIFICATION
{
  const s = makeSlide(
    "p4",
    "21 / TESTING & VERIFICATION",
    "Kiểm chứng đa tầng: 172 test Security Rules, 19 kịch bản ARTEMIS (3/3) và 905 Unit/Widget tests",
    "Mọi con số đều trích xuất từ báo cáo JUnit XML, log Emulator và ảnh chụp thực tế trong thư mục evidence/",
    "21 / 24"
  );

  // Top: 3 big metric cards (matching Guideline Slide 21)
  const metrics = [
    ["172 / 172 PASS", "Firebase Security Rules Tests", "Chạy trên Local Emulator Suite, bao phủ ma trận 80 cặp quyền được phép và bị cấm cho cả 3 vai trò trên 12 collection.", PAL.ok.bg, PAL.ok.fg],
    ["19 × 3/3 PASS", "Google ARTEMIS Mobile E2E", "19 kịch bản kiểm thử đầu-cuối tự động bằng AI Agent trên máy ảo Android (F1–F9, AI, Cross-Role), mỗi kịch bản đạt cả 3/3 lần chạy.", PAL.p1.bg, PAL.p1.fg],
    ["905 PASS + 9/10 FIX", "Unit, Widget, Arch & AI Review", "821 test Mobile + 84 test Web (kèm Architecture Test); dùng Claude Code review phát hiện 10 vấn đề và đã sửa 9 vấn đề trong 3 PR.", PAL.p2.bg, PAL.p2.fg],
  ];
  metrics.forEach(([big, title, desc, bg, fg], i) => {
    const x = 0.45 + i * 4.22;
    addCard(s, x, 1.32, 4.0, 1.85, { fill: bg, border: fg, lineWidth: 1 });
    s.addText(big, { x: x + 0.16, y: 1.4, w: 3.68, h: 0.48, fontSize: 22, bold: true, color: fg, margin: 0, isTextBox: true });
    s.addText(title, { x: x + 0.16, y: 1.88, w: 3.68, h: 0.28, fontSize: 11, bold: true, color: PAL.ink, margin: 0, isTextBox: true });
    s.addText(desc, { x: x + 0.16, y: 2.18, w: 3.68, h: 0.92, fontSize: 9.2, color: PAL.ink2, margin: 0, isTextBox: true });
  });

  // Bottom table: Verification levels & evidence paths
  const verRows = [
    [
      tblCell("Tầng kiểm thử (Test Level)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Phạm vi & Phương pháp kiểm chứng", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Kết quả đạt được", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Đường dẫn file minh chứng trong Repo", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("1. Firestore Security Rules", { bold: true, fill: PAL.card }),
      tblCell("Kiểm thử @firebase/rules-unit-testing cho unauthenticated, user, staff (đúng/sai kiosk) và admin.", { fill: PAL.card }),
      tblCell("172 / 172 đạt (100%)", { bold: true, fill: PAL.ok.bg, color: PAL.ok.fg }),
      tblCell("firebase/tests/rules.test.mjs\nevidence/rules/rules-run-2026-11-13.log", { fill: PAL.card, fontSize: 9 }),
    ],
    [
      tblCell("2. Unit, Widget & Architecture", { bold: true, fill: PAL.cardAlt }),
      tblCell("Kiểm thử model, repository, ViewModel và ranh giới kiến trúc MVVM không gọi thẳng SDK.", { fill: PAL.cardAlt }),
      tblCell("905 / 905 đạt (821 Mobile, 84 Web)", { bold: true, fill: PAL.ok.bg, color: PAL.ok.fg }),
      tblCell("mobile/test/, web/test/, packages/core/test/", { fill: PAL.cardAlt, fontSize: 9 }),
    ],
    [
      tblCell("3. Mobile E2E (ARTEMIS)", { bold: true, fill: PAL.card }),
      tblCell("Agent AI tự thao tác trên Android + đối chiếu kết quả thật trên Firestore (không chỉ tin lời Agent) + 15,8 phút Exploratory.", { fill: PAL.card }),
      tblCell("19 kịch bản × 3/3 đạt\n+ Sửa 3 bug thật (#110, #111, #114)", { bold: true, fill: PAL.ok.bg, color: PAL.ok.fg }),
      tblCell("evidence/artemis/run-1..3.xml\nevidence/exploratory/", { fill: PAL.card, fontSize: 9 }),
    ],
    [
      tblCell("4. Web Admin & Cross-Role Live", { bold: true, fill: PAL.cardAlt }),
      tblCell("Kiểm tra W01–W05 trên trang Hosting thật (thao tác chính, chặn sai vai trò, rỗng, mất mạng) & đo độ trễ Web ↔ Mobile.", { fill: PAL.cardAlt }),
      tblCell("20/20 ô kiểm tra đạt\nĐộ trễ 0,81s – 1,22s", { bold: true, fill: PAL.ok.bg, color: PAL.ok.fg }),
      tblCell("evidence/web/, evidence/cross-role/measurements.json", { fill: PAL.cardAlt, fontSize: 9 }),
    ],
  ];

  s.addTable(verRows, {
    x: 0.45, y: 3.3, w: 12.43, colW: [2.4, 4.5, 2.35, 3.18],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 0.58,
  });

  addEvidenceBar(s, "BÁO CÁO KIỂM THỬ", "Tổng hợp toàn bộ kế hoạch và kết quả kiểm thử tại docs/test-plan.md và docs/test-report.md.");
  s.addNotes("Slide 21 tổng hợp bằng chứng kiểm thử ở cả 4 tầng: Security Rules trên Emulator (172/172), Unit/Widget/Architecture (905 test), ARTEMIS E2E trên Android (19 kịch bản x 3/3 lần) và kiểm thử thực tế trên Web Hosting.");
}

// 22 / ACHIEVEMENTS
{
  const s = makeSlide(
    "p4",
    "22 / ACHIEVEMENTS",
    "Đối chiếu mục tiêu ban đầu với kết quả đã hiện thực hóa và số liệu đo kiểm thực tế",
    "Ba trụ cột Objective — Implemented — Validated chứng minh hệ thống giải quyết đúng bài toán đặt ra ở P1",
    "22 / 24"
  );

  const cols = [
    [
      "1. OBJECTIVE (MỤC TIÊU ĐẶT RA Ở P1)",
      PAL.p1.bg, PAL.p1.fg,
      [
        ["Giải bài toán 15 phút giải lao (P01)", "Giúp sinh viên đặt món trước từ giảng đường trong < 35 giây và ≤ 8 lần chạm, đến quầy chỉ việc quét QR nhận món."],
        ["Minh bạch chi phí & voucher (P02)", "Hiển thị đúng tổng tiền ngay từ giỏ hàng, không có phí ẩn và kiểm tra điều kiện mã giảm giá tức thì."],
        ["Giảm tải cho nhân viên Kiosk (P03)", "Đồng bộ hàng chờ đơn theo thời gian thực giữa Web và Mobile, hỗ trợ tạo món mới nhanh bằng AI."],
        ["Vận hành an toàn trên gói miễn phí", "Phân quyền chặt chẽ cho 3 vai trò và bảo vệ dịch vụ AI/Firestore trên gói Firebase Spark."],
      ],
    ],
    [
      "2. IMPLEMENTED (ĐÃ XÂY DỰNG XONG)",
      PAL.p3.bg, PAL.p3.fg,
      [
        ["2 Ứng dụng + 1 Gói dùng chung", "Hoàn thiện 45 màn hình Android (S01–S30, K01–K15), 13 màn hình Web Admin trên Hosting và gói packages/core (12 models/repos)."],
        ["2 Luồng liên vai trò thời gian thực", "Duyệt/từ chối đơn từ Web W03 sang Mobile S07 và phát/lưu trữ thông báo từ Web W05 sang Hộp thư S19."],
        ["Tích hợp AI Gemini mức 2 + Remote Config", "Gợi ý 5 trường thông tin món ăn từ ảnh theo JSON Schema tại K14, có công tắc tắt nóng ai_enabled từ xa."],
        ["Bảo mật 2 lớp (Rules + App Check)", "12 collection có Security Rules mặc định từ chối; bật App Check cho cả Firestore và Firebase AI Logic."],
      ],
    ],
    [
      "3. VALIDATED (ĐÃ ĐO KIỂM & CHỨNG MINH)",
      PAL.ok.bg, PAL.ok.fg,
      [
        ["Độ trễ liên vai trò ~1,15 giây", "Đo bằng screenrecord --bugreport qua 3 lần chạy thật: 1,22s · 1,09s · 1,14s (duyệt/huỷ đơn) và 1,13s / 0,81s (thông báo)."],
        ["100% kịch bản tự động vượt qua", "172/172 test Security Rules, 19 × 3/3 kịch bản ARTEMIS E2E và 905 test đơn vị/widget đều PASS."],
        ["Sửa 3 bug thật + 9 phát hiện AI Review", "Phát hiện và sửa lỗi báo nhầm 'chưa có món' khi mất mạng (#110), lỗi kẹt bộ lọc kiosk (#111), lỗi thông báo hoàn tiền mặt (#114)."],
        ["Kiểm tra lưu lượng trước khi bật App Check", "Phân tích 20% request từ bản APK cũ chưa có App Check trước khi bật chặn cứng (Enforcement)."],
      ],
    ],
  ];

  cols.forEach(([title, bg, fg, items], cIdx) => {
    const x = 0.45 + cIdx * 4.22;
    addCard(s, x, 1.32, 4.0, 4.45, { tag: title, tagBg: bg, tagFg: fg, tagW: 3.72 });
    items.forEach(([h, d], rIdx) => {
      const iy = 1.85 + rIdx * 0.94;
      s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
        x: x + 0.14, y: iy, w: 3.72, h: 0.86, rectRadius: 0.05,
        fill: { color: PAL.cardAlt }, line: { color: PAL.borderSoft, width: 0.5 },
      });
      s.addText([
        { text: `✓ ${h}\n`, options: { bold: true, fontSize: 9.4, color: fg } },
        { text: d, options: { fontSize: 8.5, color: PAL.ink } },
      ], { x: x + 0.22, y: iy + 0.04, w: 3.56, h: 0.78, margin: 0, isTextBox: true });
    });
  });

  // Pointer to Limitations slide (per Guideline Slide 22)
  addCard(s, 0.45, 5.88, 12.43, 0.62, {
    fill: PAL.warn.bg, border: PAL.warn.fg,
    tag: "CHƯA ĐẠT / GIỚI HẠN HIỆN TẠI", tagBg: PAL.warn.fg, tagFg: PAL.white, tagW: 2.5,
  });
  s.addText("Chưa có thông báo nhắc tự động sau 10 phút quên lấy món (do không dùng Cloud Functions) và chưa đăng ký Play Integrity cho bản phát hành — xem chi tiết tại Slide 23.", {
    x: 3.1, y: 5.95, w: 9.6, h: 0.48, fontSize: 9.8, bold: true, color: PAL.warn.fg, margin: 0, isTextBox: true, valign: "middle",
  });

  addEvidenceBar(s, "ĐỐI CHIẾU RUBRIC", "Hoàn thành toàn bộ 10 hạng mục chấm điểm của PRM393 Final Assignment (100/100 điểm chuẩn + +5 điểm thưởng AI mức 2).");
  s.addNotes("Slide 22 đặt cạnh nhau 3 cột Objective (Mục tiêu ban đầu), Implemented (Những gì đã xây dựng) và Validated (Số liệu kiểm chứng thực tế), đồng thời dẫn thẳng sang Slide 23 về các giới hạn còn lại.");
}

// 23 / LIMITATIONS & NEXT STEPS
{
  const s = makeSlide(
    "p4",
    "23 / LIMITATIONS & NEXT STEPS",
    "Bốn giới hạn kỹ thuật đã biết cùng phân loại tác động và hướng xử lý tiếp theo",
    "Công bố trung thực các đánh đổi khi chạy trên gói Firebase Spark miễn phí và lộ trình nâng cấp nếu đưa vào vận hành thật",
    "23 / 24"
  );

  const limRows = [
    [
      tblCell("Giới hạn hiện tại (Limitation)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Phân loại", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Tác động thực tế (Impact)", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Ưu tiên", { bold: true, fill: PAL.ink, color: PAL.white }),
      tblCell("Hướng xử lý tiếp theo (Concrete Next Step)", { bold: true, fill: PAL.ink, color: PAL.white }),
    ],
    [
      tblCell("1. Chưa đăng ký Play Integrity cho bản Android Release", { bold: true, fill: PAL.card }),
      tblCell("Bảo mật /\nTriển khai", { fill: PAL.card, align: "center" }),
      tblCell("Khi App Check bật chặn cứng (Enforce), chỉ máy có debug token đã đăng ký trên Firebase Console mới đọc/ghi được Firestore.", { fill: PAL.card }),
      tblCell("P0 (Cao)", { bold: true, fill: PAL.danger.bg, color: PAL.danger.fg, align: "center" }),
      tblCell("Đăng ký chứng chỉ SHA-256 của khóa ký Release lên Google Play Console để kích hoạt Play Integrity tự động cho mọi máy người dùng.", { fill: PAL.card }),
    ],
    [
      tblCell("2. Không có Cloud Functions để hẹn giờ nhắc khách & tính giá phía server (CR-01)", { bold: true, fill: PAL.cardAlt }),
      tblCell("Kiến trúc\n(Gói Spark)", { fill: PAL.cardAlt, align: "center" }),
      tblCell("Chưa tự động gửi thông báo nhắc lần 2 sau 10 phút khách quên lấy món; bước đối chiếu tổng tiền với giá gốc đang nằm ở client.", { fill: PAL.cardAlt }),
      tblCell("P1 (Trung bình)", { bold: true, fill: PAL.warn.bg, color: PAL.warn.fg, align: "center" }),
      tblCell("Khi nâng cấp lên gói Blaze, bổ sung Cloud Function onDocumentCreated('orders/{id}') để kiểm tra lại giá món và chạy cronjob nhắc nhận món.", { fill: PAL.cardAlt }),
    ],
    [
      tblCell("3. Lọc thông báo theo Kiosk ở tầng client trên 50 bản ghi mới nhất (CR-F08)", { bold: true, fill: PAL.card }),
      tblCell("Truy vấn\nDữ liệu", { fill: PAL.card, align: "center" }),
      tblCell("Nếu toàn trường có > 50 thông báo liên tiếp của các Kiosk khác, thông báo cũ của một Kiosk có thể trôi khỏi danh sách.", { fill: PAL.card }),
      tblCell("P2 (Thấp)", { bold: true, fill: PAL.p1.bg, color: PAL.p1.fg, align: "center" }),
      tblCell("Tách truy vấn dùng toán tử whereIn('targetKioskId', ['all', kioskId]) kết hợp composite index để lọc ngay tại Firestore.", { fill: PAL.card }),
    ],
    [
      tblCell("4. Kiểm tra giờ mở cửa Kiosk dựa vào đồng hồ thiết bị (G03) & Proto-Persona", { bold: true, fill: PAL.cardAlt }),
      tblCell("Sản phẩm /\nUX", { fill: PAL.cardAlt, align: "center" }),
      tblCell("Người dùng đổi giờ máy điện thoại có thể thấy trạng thái đóng/mở lệch thực tế; persona chưa qua khảo sát diện rộng.", { fill: PAL.cardAlt }),
      tblCell("P2 (Thấp)", { bold: true, fill: PAL.p1.bg, color: PAL.p1.fg, align: "center" }),
      tblCell("Đồng bộ giờ chuẩn từ serverTimestamp của Firestore khi khởi động ứng dụng và tổ chức khảo sát thử nghiệm với sinh viên thật tại căng-tin.", { fill: PAL.cardAlt }),
    ],
  ];

  s.addTable(limRows, {
    x: 0.45, y: 1.35, w: 12.43, colW: [2.7, 1.35, 3.45, 1.15, 3.78],
    border: { type: "solid", color: PAL.border, pt: 0.75 }, rowH: 1.05,
  });

  addEvidenceBar(s, "NHẬT KÝ RỦI RO", "Ghi nhận đầy đủ tại docs/test-report.md mục 5 (CR-F08), docs/gap-review.md (CR-01, G03) và báo cáo cuối kỳ report/Final_SE193905.pdf.");
  s.addNotes("Slide 23 trình bày bảng 4 giới hạn trung thực theo đúng cấu trúc của Guideline: Giới hạn, Phân loại, Tác động, Độ ưu tiên (P0/P1/P2) và Hướng xử lý cụ thể ở giai đoạn tiếp theo.");
}

// 24 / CONCLUSION (STAYS ON SCREEN DURING Q&A)
{
  const s = makeSlide(
    "p4",
    "24 / CONCLUSION",
    "BreakBite sẵn sàng vận hành trọn vẹn trên Firebase — Cảm ơn Hội đồng đã lắng nghe!",
    "Slide này được giữ trên màn hình trong suốt phần Hỏi – Đáp (Q&A) kèm toàn bộ liên kết truy cập trực tiếp",
    "24 / 24"
  );

  const takeaways = [
    [
      "1. PROBLEM SOLVED (GIẢI QUYẾT ĐÚNG BÀI TOÁN)",
      "Chuyển quy trình xếp hàng mua đồ ăn giờ giải lao 15 phút thành luồng đặt trước < 35 giây trên điện thoại, minh bạch tổng tiền ngay từ giỏ hàng và nhận món nhanh tại quầy bằng mã QR.",
      PAL.p1.bg, PAL.p1.fg,
    ],
    [
      "2. WORKING PRODUCT (SẢN PHẨM CHẠY THẬT)",
      "2 ứng dụng (Android 45 màn + Web Admin 13 màn tại breakbite-1315b.web.app) chia sẻ chung gói packages/core, đồng bộ liên vai trò sau ~1,15 giây và tích hợp AI Gemini 3.5 Flash Lite có công tắc tắt nóng từ xa.",
      PAL.p3.bg, PAL.p3.fg,
    ],
    [
      "3. VERIFIED RESULT (MINH CHỨNG ĐẦY ĐỦ)",
      "172/172 test Security Rules đạt trên Emulator, 19 × 3/3 kịch bản ARTEMIS E2E đạt trên Android, 905 test đơn vị/widget, 9/10 phát hiện AI Code Review đã sửa và mọi con số đều có file log kiểm chứng.",
      PAL.ok.bg, PAL.ok.fg,
    ],
  ];

  takeaways.forEach(([tag, body, bg, fg], i) => {
    const x = 0.45 + i * 4.22;
    addCard(s, x, 1.32, 4.0, 3.35, { tag, tagBg: bg, tagFg: fg, tagW: 3.72 });
    s.addText(body, {
      x: x + 0.16, y: 1.88, w: 3.68, h: 2.6, fontSize: 11, color: PAL.ink,
      margin: 0, isTextBox: true, valign: "top",
    });
  });

  // Bottom Q&A Resource links
  addCard(s, 0.45, 4.85, 12.43, 1.62, {
    fill: PAL.ink, border: PAL.ink,
    tag: "LIÊN KẾT TRUY CẬP NHANH PHỤC VỤ VẤN ĐÁP (Q&A RESOURCES)",
    tagBg: PAL.brand, tagFg: PAL.white, tagW: 4.5,
  });

  const links = [
    ["Web Admin (Đã Deploy)", "https://breakbite-1315b.web.app"],
    ["Video Demo (5p25s)", "https://youtu.be/T-h7nM4lTbc"],
    ["GitHub Repository", "github.com/baonv0817/PRM393_Lab03_Group2"],
    ["Báo cáo & Phụ lục", "report/Final_SE193905.pdf · Slide 25 & A1–A5"],
  ];
  links.forEach(([lbl, val], idx) => {
    const lx = 0.65 + idx * 3.04;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: lx, y: 5.32, w: 2.86, h: 0.98, rectRadius: 0.06,
      fill: { color: "1E293B" }, line: { color: "475569", width: 0.75 },
    });
    s.addText([
      { text: `${lbl}\n`, options: { bold: true, fontSize: 9.5, color: "FDBA74" } },
      { text: val, options: { fontSize: 9, color: PAL.white } },
    ], { x: lx + 0.1, y: 5.4, w: 2.66, h: 0.82, align: "center", valign: "middle", margin: 0, isTextBox: true });
  });

  addEvidenceBar(s, "SẴN SÀNG Q&A", "Nhóm có sẵn 5 slide Phụ lục (A1–A5) phía sau để mở ngay khi Hội đồng hỏi sâu về Đặc tả Workflow, Security Rules, ARTEMIS hoặc AI Review.");
  s.addNotes("Slide 24 tóm tắt 3 thông điệp quan trọng nhất của dự án và hiển thị rõ 4 liên kết (Web Admin, Video Demo, GitHub Repo, Báo cáo PDF) để giữ trên màn hình trong suốt thời gian vấn đáp.");
}

// ============================================================================
// SECTION APPENDIX · BACKUP (SLIDES 25 + A1 - A5 — OPEN WHEN ASKED IN Q&A)
// ============================================================================

// 25 / APPENDIX INDEX
{
  const s = makeSlide(
    "app",
    "25 / APPENDIX & BACKUP INDEX",
    "Danh mục 5 Slide Phụ lục (Backup Slides) phục vụ trả lời câu hỏi chuyên sâu của Hội đồng",
    "KHÔNG CHIẾU TRONG LÚC THUYẾT TRÌNH CHÍNH — Chỉ bấm nhảy tới slide tương ứng khi giám khảo đặt câu hỏi",
    "25 / APPENDIX"
  );

  const backups = [
    ["A1 · ĐẶC TẢ 7 THÀNH PHẦN CỦA 3 WORKFLOW LÕI", "Bảng đặc tả đầy đủ theo chuẩn tài liệu Workflow (W10–W11): Tên, Mục tiêu, Actors, Precondition/Trigger/Postcondition, Luồng chính, Ngoại lệ, Business Rules và Trạng thái thực thể cho WF-01, WF-02, WF-03."],
    ["A2 · MA TRẬN 80 CẶP KIỂM THỬ SECURITY RULES (R-01..R-80)", "Chi tiết quyền đọc/ghi của từng vai trò (unauthenticated, user, staff, admin) trên 12 collection Firestore kèm ảnh chụp kết quả chạy Emulator 172/172 PASS."],
    ["A3 · KẾT QUẢ 19 KỊCH BẢN ARTEMIS & 3 BUG SỬA TỪ CHẠY THẬT", "Danh sách toàn bộ TC-01 đến TC-43 (mỗi kịch bản 3 lần chạy), phiên Exploratory 15,8 phút và giải thích kỹ thuật cho 3 bug chỉ lộ ra khi chạy trên Firebase thật (#110, #111, #114)."],
    ["A4 · CHI TIẾT 10 PHÁT HIỆN AI CODE REVIEW (CR-F01..CR-F10)", "Bảng phân tích từng vấn đề do Claude Code /code-review tìm ra (5 lỗi chức năng, 2 bảo mật, 1 hiệu năng, 2 bảo trì), quyết định sửa 9/10 mục và mã Pull Request tương ứng."],
    ["A5 · CƠ CHẾ 6 DỊCH VỤ FIREBASE, APP CHECK & CÂU HỎI THƯỜNG GẶP", "Giải thích nhanh cách cấu hình App Check (Debug provider & reCAPTCHA Enterprise), số liệu 20% unverified traffic trước khi enforce, và cơ chế schema JSON của Gemini 3.5 Flash Lite."],
  ];

  backups.forEach(([title, desc], i) => {
    const y = 1.35 + i * 1.02;
    addCard(s, 0.45, y, 12.43, 0.92, {
      tag: `BACKUP SLIDE ${i + 1}`, tagBg: PAL.ink, tagFg: PAL.white, tagW: 1.5,
    });
    s.addText([
      { text: `${title}\n`, options: { bold: true, fontSize: 11, color: PAL.ink } },
      { text: desc, options: { fontSize: 9.6, color: PAL.ink2 } },
    ], { x: 2.25, y: y + 0.1, w: 10.45, h: 0.72, margin: 0, isTextBox: true, valign: "middle" });
  });

  addEvidenceBar(s, "HƯỚNG DẪN SỬ DỤNG", "Khi giám khảo hỏi về chủ đề nào, mở trực tiếp slide A1–A5 tương ứng để trả lời kèm số liệu và bằng chứng.");
  s.addNotes("Slide 25 là trang mục lục cho 5 slide Backup A1 đến A5 phía sau, không chiếu trong 15 phút trình bày chính thức.");
}

// A1 / WORKFLOW SPECS (7 COMPONENTS PER W10-W11)
{
  const s = makeSlide(
    "app",
    "A1 / WORKFLOW SPECIFICATION (7 COMPONENTS)",
    "Đặc tả đầy đủ 7 thành phần cho 3 Workflow lõi theo chuẩn tài liệu Workflow (W10–W11)",
    "Đối chiếu toàn diện: Mục tiêu · Actors · Pre/Trigger/Post · Luồng chính · Luồng ngoại lệ · Business Rules · Trạng thái thực thể",
    "A1 / BACKUP"
  );

  const specRows = [
    [
      tblCell("Thành phần đặc tả", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("WF-01 · Đặt trước và thanh toán đơn món", { bold: true, fill: PAL.p1.fg, color: PAL.white, fontSize: 9 }),
      tblCell("WF-02 · Duyệt đơn & phát thông báo liên vai trò", { bold: true, fill: PAL.p3.fg, color: PAL.white, fontSize: 9 }),
      tblCell("WF-03 · Tạo món mới từ ảnh bằng AI Gemini", { bold: true, fill: PAL.p2.fg, color: PAL.white, fontSize: 9 }),
    ],
    [
      tblCell("1. Mục tiêu (Goal)", { bold: true, fill: PAL.card, fontSize: 8.8 }),
      tblCell("Khách đặt xong đơn trước khi xuống quầy trong < 35s, biết rõ tổng tiền.", { fill: PAL.card, fontSize: 8.8 }),
      tblCell("Nhân viên duyệt/huỷ đơn trên Web, điện thoại khách cập nhật trong ~1,15s.", { fill: PAL.card, fontSize: 8.8 }),
      tblCell("AI điền sẵn 5 ô thông tin món từ ảnh chụp, nhân viên kiểm tra rồi mới lưu.", { fill: PAL.card, fontSize: 8.8 }),
    ],
    [
      tblCell("2. Actors", { bold: true, fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("Chính: Khách hàng (user).\nPhụ: Firestore, Dịch vụ Voucher/Slot.", { fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("Chính: Nhân viên Kiosk (staff) / Admin (Web).\nPhụ: Khách hàng (Mobile), Firestore.", { fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("Chính: Nhân viên Kiosk (staff).\nPhụ: Firebase AI Logic (Gemini), Remote Config, Cloudinary.", { fill: PAL.cardAlt, fontSize: 8.8 }),
    ],
    [
      tblCell("3. Pre / Trigger / Post", { bold: true, fill: PAL.card, fontSize: 8.8 }),
      tblCell("Pre: Đã login user, Kiosk mở.\nTrigger: Bấm Thanh toán ở S06.\nPost: Đơn pending ở S07, giỏ trống.", { fill: PAL.card, fontSize: 8.8 }),
      tblCell("Pre: Có đơn pending ở W03.\nTrigger: Bấm Duyệt / Từ chối / Đăng TB.\nPost: Đơn preparing/cancelled + thông báo S19.", { fill: PAL.card, fontSize: 8.8 }),
      tblCell("Pre: Login staff, ai_enabled=true.\nTrigger: Chọn ảnh & bấm Điền bằng AI.\nPost: 5 ô có nhãn AI; bấm Lưu ghi menu_items.", { fill: PAL.card, fontSize: 8.8 }),
    ],
    [
      tblCell("4. Luồng chính (Happy Path)", { bold: true, fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("Chọn Kiosk (S03) → Thêm món (S04) → Kiểm tra giỏ & voucher (S05) → Thanh toán (S06) → Nhận QR (S07).", { fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("Đơn hiện ở W03 → Chọn phút làm → Bấm Duyệt → Ghi orders + notifications → S07 & S19 tự cập nhật.", { fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("Chọn ảnh ở K14 → Gửi Gemini kèm Schema → Điền tên, loại, giá, phút, mô tả → Nhân viên duyệt & Lưu.", { fill: PAL.cardAlt, fontSize: 8.8 }),
    ],
    [
      tblCell("5. Luồng ngoại lệ (Exceptions)", { bold: true, fill: PAL.card, fontSize: 8.8 }),
      tblCell("E1: Voucher hết hạn (S05-ERR).\nE2: Kiosk đóng cửa (S21).\nE3: Lỗi thanh toán (S06-ERR giữ giỏ).", { fill: PAL.card, fontSize: 8.8 }),
      tblCell("E1: Từ chối không lý do bị chặn (R-49).\nE2: Nhân viên khác Kiosk bị chặn (R-50).\nE3: Khách tự duyệt bị chặn (R-46).", { fill: PAL.card, fontSize: 8.8 }),
      tblCell("E1: Ảnh không phải đồ ăn (isFood=false).\nE2: Nhân viên đang gõ tay (CR-F01).\nE3: Tắt ai_enabled=false ẩn nút AI.", { fill: PAL.card, fontSize: 8.8 }),
    ],
    [
      tblCell("6. Business Rules & 7. Trạng thái", { bold: true, fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("BR-01, BR-02 (R-44, R-45).\ncarts/{uid} → orders/{id} [pending].", { fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("BR-03, BR-04 (R-47..R-50, R-74).\norders/{id}: pending → preparing / cancelled.", { fill: PAL.cardAlt, fontSize: 8.8 }),
      tblCell("BR-05 (Schema AI & R-34..R-36).\nPhoto → MenuItemSuggestion → menu_items/{id}.", { fill: PAL.cardAlt, fontSize: 8.8 }),
    ],
  ];

  s.addTable(specRows, {
    x: 0.45, y: 1.32, w: 12.43, colW: [2.05, 3.46, 3.46, 3.46],
    border: { type: "solid", color: PAL.border, pt: 0.65 }, rowH: 0.72,
  });

  addEvidenceBar(s, "CHUẨN WORKFLOW", "Tuân thủ trọn vẹn cấu trúc 7 thành phần trong tài liệu Workflow_La_Gi_Dinh_Nghia_Va_Dac_Ta.pdf (Slide W10 & W11).");
  s.addNotes("Backup Slide A1 cung cấp bảng đặc tả đầy đủ 7 thành phần của cả 3 Workflow chính để trả lời khi giám khảo hỏi sâu về quy trình nghiệp vụ.");
}

// A2 / SECURITY RULES MATRIX
{
  const s = makeSlide(
    "app",
    "A2 / SECURITY RULES MATRIX (172/172 PASS)",
    "Ma trận phân quyền trên 12 Collection Firestore và kết quả chạy Emulator thực tế",
    "Mọi collection đều kiểm tra chặt 4 nhóm tác nhân: Chưa đăng nhập, Khách (user), Nhân viên (staff) và Quản trị viên (admin)",
    "A2 / BACKUP"
  );

  const ruleRows = [
    [
      tblCell("Collection", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Khách (role: user)", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Nhân viên (role: staff)", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Quản trị viên (role: admin)", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Mã Test (rules.test.mjs)", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
    ],
    [
      tblCell("users/{uid}", { bold: true, fontSize: 9 }),
      tblCell("Tạo/sửa hồ sơ của mình; CẤM tự đổi role", { fontSize: 9 }),
      tblCell("Đọc hồ sơ; CẤM tự đổi role hoặc kioskId", { fontSize: 9 }),
      tblCell("Đọc/sửa mọi user, gán role & kioskId", { fontSize: 9 }),
      tblCell("R-01 .. R-08", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("kiosks, slots, vouchers", { bold: true, fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Chỉ đọc (Read-only)", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Đọc; sửa trạng thái mở cửa của đúng Kiosk mình", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Toàn quyền tạo/sửa/xoá Kiosk, Slot, Voucher", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("R-09 .. R-32", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("menu_items/{id}", { bold: true, fontSize: 9 }),
      tblCell("Chỉ đọc thực đơn; CẤM thêm/sửa/xoá", { fontSize: 9 }),
      tblCell("Thêm/sửa món của đúng kioskId được gán (price > 0)", { fontSize: 9 }),
      tblCell("Toàn quyền trên thực đơn mọi Kiosk", { fontSize: 9 }),
      tblCell("R-33 .. R-39", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("orders/{id}", { bold: true, fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Tạo đơn pending cho mình; huỷ khi còn pending", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Duyệt/báo xong/giao món của Kiosk mình; huỷ phải có lý do", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Xem và xử lý đơn của mọi Kiosk", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("R-44 .. R-52", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("reviews, incidents, notifications, announcements", { bold: true, fontSize: 9 }),
      tblCell("Tạo đánh giá/sự cố của mình; đọc thông báo", { fontSize: 9 }),
      tblCell("Xem đánh giá/sự cố Kiosk mình; gửi thông báo đơn", { fontSize: 9 }),
      tblCell("Đăng/lưu trữ announcements toàn trường (R-74, R-75)", { fontSize: 9 }),
      tblCell("R-53 .. R-80", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
  ];

  s.addTable(ruleRows, {
    x: 0.45, y: 1.35, w: 8.65, colW: [1.65, 2.0, 2.15, 1.75, 1.1],
    border: { type: "solid", color: PAL.border, pt: 0.65 }, rowH: 0.82,
  });

  addCard(s, 9.25, 1.35, 3.63, 5.1, {
    tag: "LOG CHẠY EMULATOR THẬT", tagBg: PAL.ok.bg, tagFg: PAL.ok.fg, tagW: 2.4,
  });
  screen(s, "rules-run", 9.4, 1.8, 3.33, 4.45, "172 passing (rules-run-2026-11-13.png)");

  addEvidenceBar(s, "MINH CHỨNG RULES", "Tệp kiểm thử: firebase/tests/rules.test.mjs (172 tests = 80 cặp Appendix B + 92 test bổ sung cho 12 collection).");
  s.addNotes("Backup Slide A2 tóm tắt ma trận phân quyền R-01..R-80 cùng ảnh chụp kết quả chạy 172 test đạt 100% trên Firebase Emulator.");
}

// A3 / ARTEMIS E2E & EXPLORATORY LOG
{
  const s = makeSlide(
    "app",
    "A3 / ARTEMIS E2E & REAL BUGS FIXED",
    "Kết quả 19 kịch bản ARTEMIS (3/3 lần chạy) và 3 lỗi thực tế phát hiện khi chạy trên Firebase thật",
    "Test kiểm chứng lại dữ liệu trên Firestore sau khi Agent AI báo thành công để loại bỏ kết quả dương tính giả (False Positive)",
    "A3 / BACKUP"
  );

  const artRows = [
    [
      tblCell("Nhóm kịch bản ARTEMIS", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Mã Test Case", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Nội dung kiểm thử trên máy ảo Android", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
      tblCell("Lần 1 · 2 · 3", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 9 }),
    ],
    [
      tblCell("F1 · Xác thực & Vai trò", { bold: true, fontSize: 9 }),
      tblCell("TC-01, TC-02, TC-20", { fontSize: 9 }),
      tblCell("Đăng nhập khách, đăng nhập sai mật khẩu, đăng nhập nhân viên Kiosk.", { fontSize: 9 }),
      tblCell("3/3 PASS", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg, align: "center" }),
    ],
    [
      tblCell("F2 & F3 · Đặt món, Voucher, Thanh toán", { bold: true, fontSize: 9, fill: PAL.cardAlt }),
      tblCell("TC-03 .. TC-09", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Chọn món, áp mã giảm giá hợp lệ/hết hạn, thanh toán thành công/lỗi, theo dõi đơn, xem biên nhận.", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("3/3 PASS", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg, align: "center" }),
    ],
    [
      tblCell("F6, F8, F9 · Đánh giá, Hộp thư, Sự cố", { bold: true, fontSize: 9 }),
      tblCell("TC-10 .. TC-19", { fontSize: 9 }),
      tblCell("Gửi đánh giá sao, lọc hộp thư thông báo, gửi báo cáo sự cố kèm ảnh.", { fontSize: 9 }),
      tblCell("3/3 PASS", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg, align: "center" }),
    ],
    [
      tblCell("Luồng Nhân viên Kiosk", { bold: true, fontSize: 9, fill: PAL.cardAlt }),
      tblCell("TC-21 .. TC-31", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("Nhận đơn mới, báo món xong, quét QR giao món, bật/tắt món trong thực đơn.", { fontSize: 9, fill: PAL.cardAlt }),
      tblCell("3/3 PASS", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg, align: "center" }),
    ],
    [
      tblCell("AI Feature & Cross-Role (Mới ở Final)", { bold: true, fontSize: 9 }),
      tblCell("TC-40, TC-41, TC-42, TC-43", { fontSize: 9 }),
      tblCell("Điền món bằng AI (ảnh thật + ảnh lỗi), duyệt đơn từ Web sang Mobile, đăng thông báo từ Web sang Mobile.", { fontSize: 9 }),
      tblCell("3/3 PASS", { bold: true, fontSize: 9, fill: PAL.ok.bg, color: PAL.ok.fg, align: "center" }),
    ],
  ];

  s.addTable(artRows, {
    x: 0.45, y: 1.35, w: 7.55, colW: [2.05, 1.45, 3.05, 1.0],
    border: { type: "solid", color: PAL.border, pt: 0.65 }, rowH: 0.78,
  });

  // Right card: 3 real bugs found & fixed during live Firebase testing
  addCard(s, 8.2, 1.35, 4.68, 5.1, {
    tag: "3 LỖI CHỈ LỘ RA KHI CHẠY FIREBASE THẬT",
    tagBg: PAL.danger.bg, tagFg: PAL.danger.fg, tagW: 3.5,
  });
  s.addText([
    { text: "1. Bug #110 — Mất mạng báo nhầm 'Kiosk chưa có món':\n", options: { bold: true, color: PAL.danger.fg } },
    { text: "Khi tắt mạng trên Web Admin, Firestore trả về bộ nhớ đệm rỗng (isFromCache) khiến màn W02 hiện trạng thái rỗng thay vì báo lỗi mạng. Đã sửa bằng cách kiểm tra metadata.isFromCache.\n\n" },
    { text: "2. Bug #111 — Đổi Kiosk nhưng vẫn hiện hàng chờ cũ:\n", options: { bold: true, color: PAL.danger.fg } },
    { text: "Stream lắng nghe đơn hàng không huỷ đăng ký cũ khi quản trị viên đổi bộ lọc Kiosk. Đã sửa trong ViewModel.\n\n" },
    { text: "3. Bug #114 — Hứa hoàn tiền cho đơn trả tiền mặt:\n", options: { bold: true, color: PAL.danger.fg } },
    { text: "Khi từ chối đơn thanh toán tiền mặt (COD), thông báo gửi cho khách vẫn ghi 'sẽ hoàn tiền'. Đã sửa câu thông báo theo phương thức thanh toán." },
  ], { x: 8.35, y: 1.82, w: 4.38, h: 4.45, fontSize: 9.2, color: PAL.ink, margin: 0, isTextBox: true });

  addEvidenceBar(s, "FILE JUNIT & LOG", "Kết quả từng lần chạy nằm tại evidence/artemis/run-1.xml, run-2.xml, run-3.xml và phiên Exploratory tại evidence/exploratory/.");
  s.addNotes("Backup Slide A3 liệt kê toàn bộ 19 kịch bản ARTEMIS đạt 3/3 và giải thích kỹ thuật cho 3 bug thực tế (#110, #111, #114) chỉ phát hiện được khi chạy trên Firebase thật.");
}

// A4 / AI CODE REVIEW FINDINGS
{
  const s = makeSlide(
    "app",
    "A4 / AI CODE REVIEW FINDINGS (10 FINDINGS, 9 FIXED)",
    "Danh sách 10 phát hiện từ công cụ AI Code Review (Claude Code) và quyết định xử lý",
    "Bao phủ 4 nhóm: Lỗi chức năng (Correctness), Bảo mật (Security), Hiệu năng (Performance) và Khả năng bảo trì (Maintainability)",
    "A4 / BACKUP"
  );

  const crRows = [
    [
      tblCell("Mã", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 8.8 }),
      tblCell("Phân loại", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 8.8 }),
      tblCell("Mô tả vấn đề phát hiện trong mã nguồn", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 8.8 }),
      tblCell("Quyết định & PR sửa", { bold: true, fill: PAL.ink, color: PAL.white, fontSize: 8.8 }),
    ],
    [
      tblCell("CR-F01", { bold: true, fontSize: 8.8 }),
      tblCell("Correctness", { fontSize: 8.8 }),
      tblCell("Kết quả gợi ý AI trả về muộn ghi đè lên các ô mà nhân viên vừa chủ động gõ tay trong lúc chờ.", { fontSize: 8.8 }),
      tblCell("Đã sửa (#125)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F02", { bold: true, fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Correctness", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Chọn lại ảnh mới tại K14 nhưng không xoá nhãn 'Gợi ý từ AI' của lần phân tích ảnh trước.", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Đã sửa (#125)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F03", { bold: true, fontSize: 8.8 }),
      tblCell("Security", { fontSize: 8.8, color: PAL.danger.fg, bold: true }),
      tblCell("Xử lý thông báo đẩy chạy nền (background isolate) ghi vào Firestore mà chưa kích hoạt App Check.", { fontSize: 8.8 }),
      tblCell("Đã sửa (#126)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F04", { bold: true, fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Correctness", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Không huỷ lắng nghe Remote Config (onConfigUpdated subscription leak) khi đóng màn K14.", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Đã sửa (#125)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F05", { bold: true, fontSize: 8.8 }),
      tblCell("Security", { fontSize: 8.8, color: PAL.danger.fg, bold: true }),
      tblCell("Bản build release có nguy cơ rơi về nhánh Debug App Check Provider nếu truyền biến môi trường thừa.", { fontSize: 8.8 }),
      tblCell("Đã sửa (#126)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F06", { bold: true, fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Performance", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Tải ảnh lên Cloudinary trước khi kiểm tra trùng tên món ăn, gây tốn băng thông và để lại ảnh mồ côi.", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Đã sửa (#127)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F07, 09, 10", { bold: true, fontSize: 8.8 }),
      tblCell("Maintainability /\nCorrectness", { fontSize: 8.8 }),
      tblCell("Chuẩn hóa mã lỗi AI trả về, tách hằng số cấu hình Remote Config và xử lý ngoại lệ khi JSON thiếu trường.", { fontSize: 8.8 }),
      tblCell("Đã sửa (#125, #127)", { bold: true, fontSize: 8.8, fill: PAL.ok.bg, color: PAL.ok.fg }),
    ],
    [
      tblCell("CR-F08", { bold: true, fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Limitation", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Lấy 50 thông báo mới nhất từ Firestore rồi mới lọc theo kioskId ở phía client.", { fontSize: 8.8, fill: PAL.cardAlt }),
      tblCell("Chấp nhận & ghi nhận ở Slide 23", { bold: true, fontSize: 8.8, fill: PAL.warn.bg, color: PAL.warn.fg }),
    ],
  ];

  s.addTable(crRows, {
    x: 0.45, y: 1.32, w: 12.43, colW: [1.3, 1.5, 7.13, 2.5],
    border: { type: "solid", color: PAL.border, pt: 0.65 }, rowH: 0.58,
  });

  addEvidenceBar(s, "BÁO CÁO CODE REVIEW", "Bản xuất đầy đủ của Claude Code nằm tại evidence/code-review/final/ và bảng phân tích tại docs/test-report.md mục 5.");
  s.addNotes("Backup Slide A4 liệt kê chi tiết cả 10 phát hiện của AI Code Review, trong đó 9 mục đã sửa qua 3 PR (#125, #126, #127) và 1 mục (CR-F08) được ghi nhận làm giới hạn đã biết.");
}

// A5 / Q&A DEFENSE CHEATSHEET
{
  const s = makeSlide(
    "app",
    "A5 / Q&A DEFENSE CHEATSHEET",
    "Tóm tắt cơ chế kỹ thuật cho các câu hỏi vấn đáp chuyên sâu về Firebase & AI",
    "Giải thích nhanh cách 6 dịch vụ Firebase phối hợp, cách bật App Check không làm gãy ứng dụng và cách ép kiểu JSON cho Gemini",
    "A5 / BACKUP"
  );

  const qa = [
    [
      "Câu hỏi 1: Vì sao không dùng Cloud Functions mà vẫn gửi được thông báo liên vai trò?",
      "Gói Firebase Spark miễn phí không cho phép deploy Cloud Functions (đòi nâng cấp lên Blaze). Nhóm giải quyết bằng cách: khi Nhân viên duyệt/từ chối đơn ở W03,OrderRepository thực hiện ghi đơn (orders/{id}) và tạo bản ghi thông báo (notifications/{id}) trong cùng luồng xử lý, được kiểm soát bởi Security Rules R-47, R-62. Phía điện thoại khách mở sẵn stream onSnapshot nên nhận được thay đổi sau ~1,15 giây.",
    ],
    [
      "Câu hỏi 2: Nhóm đã bật Firebase App Check như thế nào để không chặn nhầm người dùng?",
      "Trên Android dùng DebugAppCheckProvider cho môi trường phát triển (và Play Integrity cho bản release); trên Web Admin dùng reCAPTCHA Enterprise. Trước khi bật chế độ chặn cứng (Enforce), nhóm kiểm tra biểu đồ metrics trên Firebase Console và phát hiện 20% request chưa xác minh đến từ một bản APK cũ cài trên máy ảo. Sau khi cài bản mới và đăng ký debug token, 100% request hợp lệ đều đi qua.",
    ],
    [
      "Câu hỏi 3: Làm sao đảm bảo AI Gemini không trả về văn bản tự do làm lỗi form thêm món?",
      "Trong FirebaseMenuAiService, nhóm truyền một Schema.object cố định (gồm isFood, name, category, price, prepMinutes, description) vào generationConfig của Gemini 3.5 Flash Lite kèm responseMimeType: 'application/json'. Nhờ vậy phản hồi của mô hình luôn tuân thủ đúng kiểu dữ liệu, và nếu ảnh không phải món ăn (isFood = false), ứng dụng chặn ngay trước khi điền vào form.",
    ],
    [
      "Câu hỏi 4: Làm sao nhóm chắc chắn kết quả test tự động của AI Agent (ARTEMIS) là thật?",
      "Trong quá trình chạy thử, có lần Agent ARTEMIS báo đã thêm món vào giỏ nhưng thực tế chạm trượt nút nên giỏ trên Firestore vẫn trống. Nhóm đã bổ sung bước hậu kiểm (post-condition assertion) đọc trực tiếp dữ liệu trên Firestore sau mỗi kịch bản để xác nhận trạng thái đơn và giỏ hàng đã thực sự thay đổi.",
    ],
  ];

  qa.forEach(([q, a], i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const x = 0.45 + col * 6.32;
    const y = 1.35 + row * 2.6;
    addCard(s, x, y, 6.1, 2.42, {
      tag: `Q&A TOPIC ${i + 1}`, tagBg: PAL.p2.bg, tagFg: PAL.p2.fg, tagW: 1.45,
      title: q, titleSize: 10.5, titleH: 0.42,
    });
    s.addText(a, {
      x: x + 0.14, y: y + 0.88, w: 5.82, h: 1.45, fontSize: 9.4, color: PAL.ink2,
      margin: 0, isTextBox: true, valign: "top",
    });
  });

  addEvidenceBar(s, "TỔNG KẾT", "Toàn bộ 30 slide (24 slide chính + 6 slide phụ lục) tuân thủ nghiêm ngặt Guideline V1.0 và tài liệu Đặc tả Workflow.");
  s.addNotes("Backup Slide A5 chuẩn bị sẵn câu trả lời ngắn gọn, đúng trọng tâm cho 4 câu hỏi vấn đáp khó nhất mà giảng viên thường hỏi.");
}

(async () => {
  await pres.writeFile({ fileName: OUT });
  console.log("Wrote 30 slides to", OUT);
})();
