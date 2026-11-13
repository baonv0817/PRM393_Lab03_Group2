// Builds slides/Final_SE193905_slides.pptx, the final-assignment deck (handout section 10: 12-15 slides on the persona,
// the system diagram, each client, the cross-role flow, the AI feature, the test results and the lessons learned).
//
//   python scripts/prepare_final_slides.py        (images and sizes.json in slides/img-final/)
//   NODE_PATH=<folder with pptxgenjs> node scripts/build_final_slides.js
//
// Every slide title is a claim and the body is its evidence (screenshots and frames of the real system, measured
// numbers), as the lecturer's guideline asks. Figures come from docs/test-report.md and docs/cross-role-flow.md.
const path = require("path");
const fs = require("fs");
const pptxgen = require("pptxgenjs");

const ROOT = path.resolve(__dirname, "..");
const IMG = path.join(ROOT, "slides", "img-final");
const OUT = path.join(ROOT, "slides", "Final_SE193905_slides.pptx");
const SIZES = JSON.parse(fs.readFileSync(path.join(IMG, "sizes.json"), "utf8"));
const SKILL = process.env.PPTX_SKILL_DIR;

const THEME = {
  name: "BreakBite",
  headFontFace: "Calibri",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "2B1B12", lt1: "FFFFFF", dk2: "622B14", lt2: "FAF8F5",
    accent1: "F69D39", accent2: "B45309", accent3: "15803D", accent4: "B91C1C", accent5: "6B5F55", accent6: "0F766E",
    hlink: "B45309", folHlink: "6B5F55",
  },
};
const HEX = THEME.colors;

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "BreakBite - Bài cuối kỳ PRM393";
pres.author = "Nhóm 2 PRM393";
const C = pres.SchemeColor;

// ------------------------------------------------------------------------------------------------ layouts
pres.defineSlideMaster({
  title: "DARK",
  background: { color: C.text2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.7, y: 1.2, w: 6.6, h: 1.6, fontSize: 44, bold: true,
      color: C.background1, valign: "top", align: "left", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.7, y: 2.9, w: 6.4, h: 1.2, fontSize: 22,
      color: C.accent1, valign: "top", align: "left", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: C.background1 },
  margin: [0.5, 0.6, 0.6, 0.6],
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.35, w: 12.1, h: 0.95, fontSize: 28,
      bold: true, color: C.text2, valign: "middle", align: "left", margin: 0 }, text: "" } },
    { text: { text: "BreakBite · PRM393 · Bài cuối kỳ", options: { x: 0.6, y: 7.02, w: 6, h: 0.3, fontSize: 10,
      color: C.accent5, margin: 0 } } },
  ],
  slideNumber: { x: 12.25, y: 7.02, w: 0.5, h: 0.3, fontSize: 10, color: C.accent5, align: "right" },
});

// ------------------------------------------------------------------------------------------------ helpers
const img = (n) => path.join(IMG, `${n}.png`);

function fit(name, maxW, maxH) {
  const [w, h] = SIZES[name];
  const s = Math.min(maxW / w, maxH / h);
  return { w: w * s, h: h * s };
}

// A screenshot of the phone in a dark rounded frame (the deck's motif), centred in the box.
function phone(slide, name, x, y, boxW, boxH, caption) {
  const capH = caption ? 0.4 : 0;
  const pad = 0.07;
  const { w, h } = fit(name, boxW - 2 * pad, boxH - capH - 2 * pad);
  const fx = x + (boxW - w - 2 * pad) / 2;
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: fx, y, w: w + 2 * pad, h: h + 2 * pad, rectRadius: 0.12,
    fill: { color: C.text1 }, line: { color: C.text1 }, objectName: `frame ${name}` });
  slide.addImage({ path: img(name), x: fx + pad, y: y + pad, w, h, altText: caption || name });
  if (caption) {
    slide.addText(caption, { x, y: y + h + 2 * pad + 0.06, w: boxW, h: capH - 0.06, fontSize: 12, color: C.accent5,
      align: "center", margin: 0, isTextBox: true });
  }
}

// A screenshot of the web or a video frame, with a thin border and an optional caption below.
function screen(slide, name, x, y, boxW, boxH, caption) {
  const capH = caption ? 0.38 : 0;
  const { w, h } = fit(name, boxW, boxH - capH);
  const sx = x + (boxW - w) / 2;
  slide.addImage({ path: img(name), x: sx, y, w, h, altText: caption || name });
  slide.addShape(pres.shapes.RECTANGLE, { x: sx, y, w, h, fill: { type: "none" }, line: { color: C.accent5, width: 0.75 },
    objectName: `border ${name}` });
  if (caption) {
    slide.addText(caption, { x, y: y + h + 0.05, w: boxW, h: capH - 0.05, fontSize: 12, color: C.accent5,
      align: "center", margin: 0, isTextBox: true });
  }
  return { x: sx, y, w, h };
}

// An icon in an orange circle with a bold head and a line of text to its right.
function iconRow(slide, icon, head, text, x, y, w, opts = {}) {
  const d = opts.d || 0.56;
  slide.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: opts.circle || C.accent1 }, line: { type: "none" },
    objectName: `circle ${icon}` });
  slide.addImage({ path: img(`icon-${icon}`), x: x + d * 0.17, y: y + d * 0.17, w: d * 0.66, h: d * 0.66,
    altText: head || icon });
  const runs = [];
  if (head) runs.push({ text: head, options: { bold: true, color: opts.headColor || C.text2, breakLine: !!text } });
  if (text) runs.push({ text, options: { color: opts.textColor || C.text1 } });
  slide.addText(runs, { x: x + d + 0.22, y: y - 0.04, w: w - d - 0.22, h: opts.h || 0.9, fontSize: opts.size || 15,
    valign: "top", margin: 0, isTextBox: true, paraSpaceAfter: 2 });
}

function card(slide, x, y, w, h, name) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.1, fill: { color: C.background2 },
    line: { color: "E4DFD8", width: 0.75 }, objectName: name });
}

function stat(slide, x, y, w, big, label, color) {
  slide.addText(big, { x, y, w, h: 0.95, fontSize: 40, bold: true, color: color || C.accent2, margin: 0,
    isTextBox: true, valign: "bottom" });
  slide.addText(label, { x, y: y + 1.0, w, h: 0.8, fontSize: 14, color: C.text1, margin: 0, isTextBox: true,
    valign: "top" });
}

function source(slide, text) {
  slide.addText(text, { x: 0.6, y: 6.62, w: 12.1, h: 0.32, fontSize: 11, italic: true, color: C.accent5, margin: 0,
    isTextBox: true });
}

function content(section, title) {
  const s = pres.addSlide({ masterName: "CONTENT", sectionTitle: section });
  s.addText(title, { placeholder: "title" });
  return s;
}

// ------------------------------------------------------------------------------------------------ slides
const P1 = "1 · Vấn đề", P2 = "2 · Thiết kế", P3 = "3 · Demo", P4 = "4 · Minh chứng";

// 1 ─ Overview
pres.addSection({ title: P1 });
{
  const s = pres.addSlide({ masterName: "DARK", sectionTitle: P1 });
  s.addText("BreakBite", { placeholder: "title" });
  s.addText("Đặt món trước, nhận tại quầy trong giờ giải lao", { placeholder: "body" });
  s.addText([
    { text: "Bài cuối kỳ PRM393 · Nhóm 2", options: { bold: true, breakLine: true } },
    { text: "Ứng dụng Android cho khách và nhân viên quầy, web admin cho nhân viên và quản trị viên, chung một dự án Firebase.", options: { breakLine: true } },
    { text: "Web admin: https://breakbite-1315b.web.app" },
  ], { x: 0.7, y: 4.35, w: 6.2, h: 1.9, fontSize: 16, color: C.background1, margin: 0, isTextBox: true,
    valign: "top", paraSpaceAfter: 8 });
  const web = fit("w03-queue", 5.6, 3.6);
  s.addImage({ path: img("w03-queue"), x: 7.25, y: 1.0, w: web.w, h: web.h, altText: "Web admin: Duyệt đơn" });
  phone(s, "s02-home", 10.35, 2.45, 2.4, 4.6);
  s.addNotes("BreakBite là hệ thống đặt món trước cho sinh viên Campus Quận 9. Khách đặt và trả tiền trên điện thoại, đến quầy lấy món bằng mã QR. Nhân viên quầy nhận đơn trên điện thoại hoặc trên web, quản trị viên quản lý trên web. Cả hai ứng dụng dùng chung một dự án Firebase. Ảnh bên phải là màn Duyệt đơn trên web và Trang chủ trên điện thoại, chụp từ hệ thống đang chạy.");
}

// 2 ─ Persona and problem
{
  const s = content(P1, "Giờ giải lao chỉ có 15 phút, xếp hàng mua đồ ăn dễ trễ giờ vào lớp");
  const cards = [
    ["person", "P01 · Quân, sinh viên năm 2 (persona chính)",
      "Nghỉ 15 phút, mất khoảng 5 phút đi bộ. Thấy hàng dài là bỏ mua, nhịn đói tới trưa.",
      "Cần: đặt xong một đơn chưa tới 35 giây, không quá 8 lần chạm."],
    ["cart", "P02 · Linh, sinh viên năm 1",
      "Mỗi ngày chi khoảng 40.000đ cho ăn uống. Bỏ ứng dụng nếu tới bước trả tiền mới thấy phí lạ.",
      "Cần: thấy đúng số tiền phải trả ngay từ giỏ hàng."],
    ["shop", "P03 · Cô Hạnh, nhân viên quầy",
      "Giờ nghỉ đông khách, đang phải gọi số và kiểm tra chuyển khoản bằng tay.",
      "Cần: nhận đơn, báo món xong và trả món thật nhanh."],
  ];
  cards.forEach(([icon, head, pain, need], i) => {
    const x = 0.6 + i * 4.1, y = 1.55;
    card(s, x, y, 3.85, 3.7, `persona ${i + 1}`);
    s.addShape(pres.shapes.OVAL, { x: x + 0.3, y: y + 0.3, w: 0.7, h: 0.7, fill: { color: C.accent1 }, line: { type: "none" } });
    s.addImage({ path: img(`icon-${icon}`), x: x + 0.42, y: y + 0.42, w: 0.46, h: 0.46, altText: icon });
    s.addText(head, { x: x + 0.3, y: y + 1.12, w: 3.3, h: 0.7, fontSize: 16, bold: true, color: C.text2, margin: 0,
      isTextBox: true, valign: "top" });
    s.addText([
      { text: pain, options: { breakLine: true } },
      { text: need, options: { bold: true, color: C.accent2 } },
    ], { x: x + 0.3, y: y + 1.85, w: 3.3, h: 1.75, fontSize: 14, color: C.text1, margin: 0, isTextBox: true,
      valign: "top", paraSpaceAfter: 8 });
  });
  s.addText([
    { text: "Cách giải quyết: ", options: { bold: true, color: C.text2 } },
    { text: "khách đặt và trả tiền trên điện thoại trước khi ra quầy, theo dõi đơn theo thời gian thực, tới nơi đưa mã QR là lấy món. Quầy nhận và duyệt đơn trên điện thoại hoặc trên web." },
  ], { x: 0.6, y: 5.5, w: 12.1, h: 0.9, fontSize: 16, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
  source(s, "Nguồn: persona của Lab 2 (03-P2-ux-design/01-persona.md, repository PRM323-Lab2-Group2); đây là proto-persona, nhóm chưa phỏng vấn người dùng thật.");
  s.addNotes("Ba persona lấy từ Lab 2. Quân là persona chính: chỉ có 15 phút nghỉ, mất 5 phút đi bộ, thấy hàng dài là bỏ mua. Vì vậy mục tiêu của luồng đặt món là xong trong chưa tới 35 giây và không quá 8 lần chạm. Linh quan tâm tới giá nên giỏ hàng phải hiện đúng tổng tiền. Cô Hạnh là nhân viên quầy, cần nhận và trả đơn nhanh. Lưu ý đây là proto-persona, chưa có phỏng vấn người thật.");
}

// 3 ─ Roles
{
  const s = content(P1, "Ba vai trò, mỗi vai trò chỉ vào được đúng ứng dụng của mình");
  const rows = [
    ["person", "Khách (user) · ứng dụng Android",
      "Đặt món, trả tiền, theo dõi đơn, nhận thông báo, xuất biên nhận, đánh giá món, báo sự cố."],
    ["shop", "Nhân viên kiosk (staff) · Android và web",
      "Nhận hoặc từ chối đơn kèm lý do, báo món xong, trả món bằng mã QR, sửa thực đơn, thêm món bằng AI, xem thống kê quầy."],
    ["settings", "Quản trị viên (admin) · web",
      "Mọi việc của nhân viên ở mọi kiosk, đăng thông báo, phân quyền, quản lý kiosk, khung giờ, voucher, xem nhật ký."],
  ];
  rows.forEach(([icon, head, text], i) => iconRow(s, icon, head, text, 0.6, 1.65 + i * 1.45, 6.4, { h: 1.3 }));
  const r = screen(s, "w01-reject", 7.4, 1.55, 5.3, 3.8,
    "Web admin từ chối tài khoản khách: \"Trang quản trị chỉ dành cho nhân viên kiosk và quản trị viên\"");
  s.addText([
    { text: "Vai trò lưu ở users/{uid}.role. ", options: { bold: true } },
    { text: "Chỉ quản trị viên được đổi vai trò, không ai tự đổi vai trò của mình (rules R-02, R-05). Ứng dụng Android cũng từ chối tài khoản quản trị viên và chỉ sang web admin." },
  ], { x: 7.4, y: r.y + r.h + 0.55, w: 5.3, h: 1.1, fontSize: 14, color: C.text1, margin: 0, isTextBox: true,
    valign: "top" });
  s.addNotes("Hệ thống có ba vai trò. Khách dùng ứng dụng Android. Nhân viên kiosk dùng cả ứng dụng Android lẫn web, nhưng chỉ thấy đơn và món của kiosk mình. Quản trị viên dùng web và làm được mọi việc. Vai trò nằm trong users/{uid}.role, chỉ quản trị viên được đổi, và Security Rules kiểm tra điều đó. Mỗi ứng dụng cũng từ chối tài khoản sai vai trò, như ảnh bên phải: tài khoản khách đăng nhập web admin bị từ chối với thông báo rõ ràng.");
}

// 4 ─ System diagram
pres.addSection({ title: P2 });
{
  const s = content(P2, "Hai ứng dụng dùng chung một gói code và một dự án Firebase");
  const box = (x, y, w, h, head, text, fill, textColor) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.1, fill: { color: fill },
      line: { color: fill }, objectName: head });
    s.addText([
      { text: head, options: { bold: true, fontSize: 17, breakLine: !!text } },
      ...(text ? [{ text, options: { fontSize: 13 } }] : []),
    ], { x: x + 0.15, y: y + 0.08, w: w - 0.3, h: h - 0.16, color: textColor, margin: 0, isTextBox: true,
      valign: "middle", align: "center" });
  };
  const arrow = (x1, y1, x2, y2) => s.addShape(pres.shapes.LINE, { x: x1, y: y1, w: x2 - x1, h: y2 - y1,
    line: { color: C.accent5, width: 1.5, endArrowType: "triangle" } });
  box(0.9, 1.55, 4.6, 1.05, "Ứng dụng Android (Flutter)", "khách hàng và nhân viên kiosk", C.accent1, C.text1);
  box(6.0, 1.55, 4.6, 1.05, "Web admin (Flutter Web)", "breakbite-1315b.web.app, trên Firebase Hosting", C.accent1, C.text1);
  box(0.9, 3.05, 9.7, 1.0, "packages/core: gói Dart dùng chung",
    "model, repository Firestore, kiểm tra vai trò, theme và widget của Lab 2", C.text2, C.background1);
  arrow(3.2, 2.6, 3.2, 3.05);
  arrow(8.3, 2.6, 8.3, 3.05);
  const fb = [
    ["Authentication", "Google, email"],
    ["Firestore", "dữ liệu và Security Rules"],
    ["Remote Config", "cấu hình đổi ngay"],
    ["App Check", "chặn client giả"],
    ["AI Logic", "Gemini 3.5 Flash Lite"],
  ];
  fb.forEach(([h, t], i) => box(0.9 + i * 1.98, 4.55, 1.86, 1.05, h, t, "FFF1DE", C.text1));
  arrow(5.75, 4.05, 5.75, 4.55);
  s.addText("Firebase (gói Spark, miễn phí)", { x: 0.9, y: 5.65, w: 9.7, h: 0.35, fontSize: 13, color: C.accent5,
    margin: 0, isTextBox: true, align: "center" });
  card(s, 11.0, 1.55, 1.75, 4.45, "other services");
  s.addText([
    { text: "Chỉ ở Android", options: { bold: true, color: C.text2, breakLine: true } },
    { text: "Cloud Messaging, Crashlytics, Analytics", options: { breakLine: true } },
    { text: " ", options: { breakLine: true } },
    { text: "REST API", options: { bold: true, color: C.text2, breakLine: true } },
    { text: "Cloudinary: tải ảnh món, ảnh sự cố và biên nhận PDF lên qua HTTP" },
  ], { x: 11.12, y: 1.7, w: 1.55, h: 4.2, fontSize: 13, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
  source(s, "Không dùng Cloud Functions (cần gói Blaze): logic nằm ở hai ứng dụng, quyền nằm ở Security Rules và App Check. Chi tiết: docs/architecture.md.");
  s.addNotes("Hệ thống có hai ứng dụng Flutter: ứng dụng Android cho khách và nhân viên, web admin chạy trên Firebase Hosting. Cả hai dùng chung gói packages/core gồm model, repository Firestore, kiểm tra vai trò và theme của Lab 2, nên một lần sửa có hiệu lực ở cả hai nơi. Backend là một dự án Firebase gói Spark: Authentication, Firestore với Security Rules, Remote Config, App Check và AI Logic. Không có server riêng và không có Cloud Functions. Phần REST API là Cloudinary, dùng để tải ảnh và file PDF lên qua HTTP.");
}

// 5 ─ Data model and rules
{
  const s = content(P2, "Security Rules mặc định từ chối và kiểm tra quyền theo vai trò");
  s.addText("Vòng đời của một đơn hàng", { x: 0.6, y: 1.5, w: 7.2, h: 0.4, fontSize: 18, bold: true, color: C.text2,
    margin: 0, isTextBox: true });
  const st = [["Chờ xác nhận", "pending"], ["Đang làm", "preparing"], ["Sẵn sàng", "ready"], ["Hoàn tất", "delivered"]];
  st.forEach(([vi, en], i) => {
    const x = 0.6 + i * 1.85;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 2.1, w: 1.55, h: 0.95, rectRadius: 0.1,
      fill: { color: i === 3 ? C.accent3 : C.accent1 }, line: { type: "none" }, objectName: en });
    s.addText([{ text: vi, options: { bold: true, breakLine: true } }, { text: en, options: { fontSize: 12 } }],
      { x, y: 2.1, w: 1.55, h: 0.95, fontSize: 15, color: i === 3 ? C.background1 : C.text1, align: "center",
        valign: "middle", margin: 0, isTextBox: true });
    if (i < 3) s.addShape(pres.shapes.LINE, { x: x + 1.55, y: 2.575, w: 0.3, h: 0, line: { color: C.accent5, width: 1.5, endArrowType: "triangle" } });
  });
  const steps = ["nhân viên kiosk đó duyệt", "nhân viên báo món xong", "quét mã nhận món"];
  steps.forEach((t, i) => s.addText(t, { x: 0.6 + i * 1.85 + 1.0, y: 3.12, w: 1.6, h: 0.55, fontSize: 11,
    color: C.accent5, margin: 0, isTextBox: true, align: "center", valign: "top" }));
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 4.05, w: 1.55, h: 0.95, rectRadius: 0.1,
    fill: { color: C.accent4 }, line: { type: "none" }, objectName: "cancelled" });
  s.addText([{ text: "Đã huỷ", options: { bold: true, breakLine: true } }, { text: "cancelled", options: { fontSize: 12 } }],
    { x: 0.6, y: 4.05, w: 1.55, h: 0.95, fontSize: 15, color: C.background1, align: "center", valign: "middle",
      margin: 0, isTextBox: true });
  s.addShape(pres.shapes.LINE, { x: 1.375, y: 3.05, w: 0, h: 1.0, line: { color: C.accent5, width: 1.5, endArrowType: "triangle" } });
  s.addText("Khách huỷ khi quầy chưa nhận, hoặc quầy từ chối kèm lý do. Mỗi bước đổi trạng thái được rules kiểm tra: ai được đổi, từ trạng thái nào sang trạng thái nào, và có ghi giờ của server.",
    { x: 2.4, y: 4.05, w: 5.3, h: 1.4, fontSize: 14, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
  card(s, 8.3, 1.5, 4.45, 4.9, "rules facts");
  stat(s, 8.6, 1.65, 4.0, "172/172", "test Security Rules đạt trên Emulator, gồm 80 cặp được phép và bị cấm cho từng vai trò", C.accent3);
  s.addText([
    { text: "Quy tắc cuối cùng: cấm mọi thứ chưa được cho phép", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Kiểm tra dữ liệu đúng dạng: đơn, món, thông báo", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Nhân viên chỉ sửa đơn và món của kiosk mình", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "12 collection, mô tả trong docs/data-model.md", options: { bullet: { indent: 15 } } },
  ], { x: 8.6, y: 3.65, w: 4.0, h: 2.6, fontSize: 14, color: C.text1, margin: 0, isTextBox: true, valign: "top",
    paraSpaceAfter: 6 });
  source(s, "Minh chứng: firebase/firestore.rules, firebase/tests/rules.test.mjs, evidence/rules/rules-run-2026-11-13.log.");
  s.addNotes("Mọi quyền đọc và ghi nằm trong Security Rules. Quy tắc cuối cùng cấm mọi thứ, nên cái gì không được cho phép rõ ràng thì bị từ chối. Đơn hàng đi qua năm trạng thái: chờ xác nhận, đang làm, sẵn sàng, hoàn tất, hoặc đã huỷ. Rules kiểm tra ai được đổi trạng thái và đổi từ đâu sang đâu, ví dụ chỉ nhân viên của đúng kiosk mới được duyệt đơn. Bộ test rules có 172 test, đều đạt, trong đó có ma trận 80 cặp được phép và bị cấm cho từng vai trò trên từng collection.");
}

// 6 ─ Mobile app
{
  const s = content(P2, "Ứng dụng Android chạy đủ các luồng của Lab 2 trên dữ liệu Firestore thật");
  const ph = [["s02-home", "Trang chủ (khách)"], ["s07-tracking", "Theo dõi đơn"], ["s19-inbox", "Hộp thư thông báo"],
    ["k02-staff", "Đơn mới (nhân viên)"]];
  ph.forEach(([n, c], i) => phone(s, n, 0.55 + i * 2.15, 1.5, 2.05, 5.05, c));
  card(s, 9.4, 1.5, 3.35, 5.0, "mobile facts");
  s.addText([
    { text: "Đã làm xong", options: { bold: true, color: C.text2, fontSize: 18, breakLine: true } },
    { text: "Các màn S01–S30 cho khách và K01–K15 cho nhân viên của Lab 2", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Đơn, giỏ, thực đơn, hộp thư đều trên Firestore, cập nhật tức thì", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Hộp thư nhận thông báo của quản trị viên ngay khi đăng", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "ARTEMIS: luồng F1, F2, F3, F6, F8, F9 và luồng bán hàng, mỗi luồng đạt 3/3 lần", options: { bullet: { indent: 15 } } },
  ], { x: 9.6, y: 1.7, w: 3.0, h: 4.7, fontSize: 14, color: C.text1, margin: 0, isTextBox: true, valign: "top",
    paraSpaceAfter: 8 });
  s.addNotes("Ứng dụng Android gồm phần cho khách và phần cho nhân viên quầy, đủ 45 màn hình của Lab 2. Toàn bộ dữ liệu nằm trên Firestore và cập nhật theo thời gian thực: thực đơn, giỏ hàng, đơn hàng, hộp thư. Hộp thư nhận cả thông báo trạng thái đơn lẫn thông báo quản trị viên đăng trên web. Các luồng chính của Lab 2 đều có kịch bản ARTEMIS chạy ba lần và đạt cả ba.");
}

// 7 ─ Web admin
{
  const s = content(P2, "Web admin đủ 4 màn hình và form thông báo, chạy trên Firebase Hosting");
  const g = [["w03-queue", "W03 Duyệt đơn"], ["w02-menu", "W02 Thực đơn"], ["w04-stats", "W04 Thống kê"], ["w05-ann", "W05 Thông báo"]];
  g.forEach(([n, c], i) => screen(s, n, 0.6 + (i % 2) * 4.35, 1.5 + Math.floor(i / 2) * 2.6, 4.15, 2.5, c));
  card(s, 9.45, 1.5, 3.3, 5.0, "web facts");
  s.addText([
    { text: "https://breakbite-1315b.web.app", options: { bold: true, color: C.accent2, breakLine: true } },
    { text: "W01 Đăng nhập bằng Google hoặc email, từ chối tài khoản khách", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Kiểm tra từng màn: thao tác chính, từ chối sai vai trò, trạng thái rỗng, trạng thái lỗi khi mất mạng", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Dùng lại theme và widget Lab 2 từ packages/core, bố cục cho màn hình rộng", options: { bullet: { indent: 15 }, breakLine: true } },
    { text: "Quản trị viên có thêm 8 trang hệ thống", options: { bullet: { indent: 15 } } },
  ], { x: 9.65, y: 1.7, w: 2.95, h: 4.7, fontSize: 14, color: C.text1, margin: 0, isTextBox: true, valign: "top",
    paraSpaceAfter: 8 });
  source(s, "Ảnh chụp trên trang đã deploy: evidence/web/. Bảng kiểm tra W01–W05: docs/test-report.md mục 2.");
  s.addNotes("Web admin viết bằng Flutter Web và chạy trên Firebase Hosting. Có đủ bốn màn hình đề yêu cầu: Duyệt đơn, Thực đơn, Thống kê, cộng với form Thông báo, và màn Đăng nhập. Mỗi màn được kiểm tra trên trang đã deploy theo bốn ý: thao tác chính, từ chối tài khoản sai vai trò, trạng thái rỗng và trạng thái lỗi khi mất mạng, ô nào cũng có ảnh chụp. Web dùng lại theme và widget của Lab 2 từ gói dùng chung.");
}

// 8 ─ Cross-role flow 1
pres.addSection({ title: P3 });
{
  const s = content(P3, "Quầy duyệt trên web, điện thoại khách đổi trạng thái sau khoảng 1 giây");
  screen(s, "x1-approved", 0.6, 1.5, 7.9, 3.75, "Bên trái: web admin vừa duyệt đơn RMR1FE. Bên phải: điện thoại khách đã đổi sang Đang làm.");
  const steps = [
    "Khách đặt đơn trên điện thoại, đơn ở trạng thái Chờ xác nhận",
    "Đơn hiện ngay trong hàng chờ Duyệt đơn của kiosk",
    "Nhân viên chọn thời gian làm, bấm Duyệt đơn",
    "Điện thoại tự đổi sang Đang làm và hiện giờ dự kiến, không cần tải lại",
  ];
  steps.forEach((t, i) => {
    const y = 1.55 + i * 1.0;
    s.addShape(pres.shapes.OVAL, { x: 8.85, y, w: 0.5, h: 0.5, fill: { color: C.accent1 }, line: { type: "none" } });
    s.addText(String(i + 1), { x: 8.85, y, w: 0.5, h: 0.5, fontSize: 16, bold: true, color: C.text1, align: "center",
      valign: "middle", margin: 0, isTextBox: true });
    s.addText(t, { x: 9.5, y: y - 0.02, w: 3.25, h: 0.9, fontSize: 14, color: C.text1, margin: 0, isTextBox: true,
      valign: "top" });
  });
  s.addTable([
    [{ text: "Lần chạy thật", options: { bold: true } }, { text: "Trên web", options: { bold: true } },
      { text: "Điện thoại hiện", options: { bold: true } }, { text: "Thời gian", options: { bold: true } }],
    ["1 · đơn #QLOTIR", "Duyệt, 10 phút", "Đang làm", "1,22 s"],
    ["2 · đơn #25RPEH", "Từ chối: Quầy sắp đóng cửa", "Đã huỷ kèm lý do", "1,09 s"],
    ["3 · đơn #S7SWIR", "Duyệt, 15 phút", "Đang làm", "1,14 s"],
  ], { x: 0.6, y: 5.42, w: 7.9, colW: [1.9, 2.75, 2.0, 1.25], fontSize: 12, color: C.text1,
    border: { type: "solid", color: "E4DFD8", pt: 0.75 }, fill: { color: C.background1 }, margin: 0.04, rowH: 0.27 });
  source(s, "Đo bằng screenrecord --bugreport (giờ của máy trên từng khung hình). Sơ đồ tuần tự và rules: docs/cross-role-flow.md. ARTEMIS TC-42, TC-43: 3/3.");
  s.addNotes("Đây là luồng liên vai trò chính. Khách đặt đơn trên điện thoại, đơn ở trạng thái chờ xác nhận. Trên web, đơn hiện ngay trong hàng chờ của kiosk. Nhân viên chọn thời gian làm và bấm duyệt. Điện thoại của khách tự đổi sang đang làm, kèm giờ dự kiến sẵn sàng, không cần tải lại. Nhóm chạy luồng này ba lần trên hệ thống thật và đo thời gian từ lúc bấm trên web tới khi điện thoại đổi: 1,22 giây, 1,09 giây và 1,14 giây. Lần thứ hai là từ chối kèm lý do, điện thoại hiện đơn đã huỷ và lý do.");
}

// 9 ─ Cross-role flow 2
{
  const s = content(P3, "Quản trị viên đăng thông báo trên web, khách nhận được sau 1,13 giây");
  screen(s, "x2-inbox", 0.6, 1.5, 7.9, 3.75, "Thông báo vừa đăng ở W05 nằm trên cùng hộp thư, nhãn \"Thông báo từ BreakBite\".");
  s.addChart(pres.charts.BAR, [{
    name: "Giây",
    labels: ["Duyệt đơn, lần 1: 1,22 s", "Từ chối đơn, lần 2: 1,09 s", "Duyệt đơn, lần 3: 1,14 s",
      "Đăng thông báo: 1,13 s", "Lưu trữ thông báo: 0,81 s"],
    values: [1.22, 1.09, 1.14, 1.13, 0.81],
  }], {
    x: 8.75, y: 1.45, w: 4.0, h: 3.9, barDir: "bar", chartColors: [HEX.accent1],
    showTitle: true, title: "Từ lúc bấm trên web tới khi điện thoại đổi", titleFontSize: 13, titleColor: HEX.dk2,
    titleFontFace: "+mn-lt", showValue: false,
    catAxisLabelColor: HEX.dk1, catAxisLabelFontSize: 12, catAxisLabelFontFace: "+mn-lt", catAxisOrientation: "maxMin",
    valAxisHidden: true, valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false,
    valAxisMinVal: 0, valAxisMaxVal: 1.4,
  });
  s.addText([
    { text: "Luồng liên vai trò thứ hai. ", options: { bold: true, color: C.text2 } },
    { text: "Thông báo gửi cho khách của mọi kiosk hoặc một kiosk. Khi quản trị viên lưu trữ, thông báo biến mất khỏi hộp thư sau 0,81 giây. Chỉ quản trị viên được viết thông báo (rules R-74, R-75)." },
  ], { x: 0.6, y: 5.45, w: 12.1, h: 1.0, fontSize: 15, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
  source(s, "Minh chứng: evidence/cross-role/ (ảnh trước và sau, video, measurements.json); docs/cross-role-flow.md luồng 2.");
  s.addNotes("Luồng thứ hai đi theo chiều từ quản trị viên tới khách. Quản trị viên viết thông báo ở màn W05 và bấm đăng. Hộp thư trên điện thoại của khách hiện thông báo đó trên cùng sau 1,13 giây, có nhãn Thông báo từ BreakBite. Khi quản trị viên lưu trữ, thông báo biến mất khỏi hộp thư sau 0,81 giây. Biểu đồ bên phải gom cả năm lần đo của hai luồng, lần nào cũng dưới một giây rưỡi.");
}

// 10 ─ AI feature
{
  const s = content(P3, "AI điền sẵn thông tin món từ ảnh, nhân viên kiểm tra rồi mới lưu");
  phone(s, "k14-filled", 0.6, 1.5, 2.6, 5.0, "Ảnh bánh mì: AI điền đủ ô");
  phone(s, "k14-not-food", 3.4, 1.5, 2.6, 5.0, "Ảnh không phải món ăn");
  const rows = [
    ["robot", "Gemini 3.5 Flash Lite qua Firebase AI Logic", "Gửi ảnh món, nhận về tên, loại, giá, thời gian làm và mô tả theo một khuôn JSON cố định."],
    ["settings", "Remote Config điều khiển", "ai_enabled bật tắt tính năng; ai_model và ai_prompt đổi mô hình và câu lệnh không cần build lại."],
    ["shield", "App Check và không có dữ liệu cá nhân", "App Check bật cho AI Logic. Chỉ gửi ảnh món, không gửi tên, email hay ảnh người."],
    ["warning", "Lỗi thì vẫn nhập tay được", "Hết hạn mức, mất mạng hay ảnh không phải món ăn: hiện lý do, form vẫn dùng bình thường."],
    ["check", "Có nhãn, sửa được, có số liệu", "Mỗi ô ghi \"Gợi ý từ AI\". Ghi sự kiện ai_request, ai_result_accepted, ai_error."],
  ];
  rows.forEach(([icon, head, text], i) => iconRow(s, icon, head, text, 6.35, 1.5 + i * 1.0, 6.4, { d: 0.5, size: 13, h: 0.95 }));
  source(s, "Mức 2 của đề. Minh chứng: docs/ai-feature.md, evidence/ai/, ARTEMIS TC-40 và TC-41 đều 3/3, DebugView evidence/analytics/debugview-ai-events.png.");
  s.addNotes("Tính năng AI giúp nhân viên thêm món mới. Nhân viên chụp hoặc chọn ảnh món, bấm Điền bằng AI. Ảnh được gửi tới Gemini qua Firebase AI Logic, Gemini trả về tên, loại, giá, thời gian làm và mô tả theo một khuôn JSON cố định. Mỗi ô có nhãn Gợi ý từ AI và nhân viên sửa được trước khi lưu. Tên mô hình, câu lệnh và công tắc bật tắt đều nằm trong Remote Config. App Check được bật cho AI Logic. Khi AI lỗi, ví dụ hết hạn mức hoặc ảnh không phải món ăn như ảnh thứ hai, ứng dụng báo lý do và form vẫn nhập tay được.");
}

// 11 ─ AI off through Remote Config
{
  const s = content(P3, "Tắt AI bằng Remote Config, nút AI biến mất ngay trên điện thoại");
  screen(s, "x3-ai-off", 0.6, 1.5, 8.6, 4.4, "Bên trái: Remote Config đã đăng ai_enabled = false (Version 11). Bên phải: màn Thêm món không còn nút Điền bằng AI.");
  const pts = [
    ["sync", "Cập nhật theo thời gian thực", "Ứng dụng lắng nghe Remote Config, nút AI biến mất vài giây sau khi đăng."],
    ["warning", "Đường lui khi có sự cố", "Hết hạn mức hoặc mô hình trả lời sai thì tắt ngay cho mọi máy."],
    ["check", "Bật lại cũng đơn giản", "Đổi ai_enabled về true và Publish thêm một lần."],
  ];
  pts.forEach(([icon, head, text], i) => iconRow(s, icon, head, text, 9.5, 1.55 + i * 1.5, 3.25, { size: 14, h: 1.35 }));
  source(s, "Quay trực tiếp trong video demo. Cách cấu hình: docs/ai-feature.md, firebase/remote-config-defaults.json.");
  s.addNotes("Đề yêu cầu cho thấy Remote Config tắt được tính năng AI. Trên Firebase console, nhóm đổi ai_enabled thành false và Publish. Điện thoại nhân viên đang mở màn thêm món, vài giây sau nút Điền bằng AI biến mất mà không cần build lại hay mở lại ứng dụng, form vẫn nhập tay được. Đây là đường lui khi AI hết hạn mức hoặc trả lời sai. Muốn bật lại chỉ cần đổi về true và Publish.");
}

// 12 ─ Test results
pres.addSection({ title: P4 });
{
  const s = content(P4, "Mỗi loại kiểm thử đều đạt, và kết quả nào cũng có file minh chứng");
  const stats = [
    ["172/172", "test Security Rules đạt trên Firebase Emulator", C.accent3],
    ["19 × 3/3", "kịch bản ARTEMIS, mỗi kịch bản chạy 3 lần đều đạt", C.accent2],
    ["3 lần", "chạy luồng liên vai trò trên hệ thống thật, khoảng 1 giây mỗi lần", C.accent2],
    ["905", "test đơn vị và widget (821 mobile, 84 web)", C.accent3],
  ];
  stats.forEach(([b, l, c], i) => {
    const x = 0.6 + i * 3.05;
    card(s, x, 1.5, 2.85, 2.25, `stat ${i + 1}`);
    stat(s, x + 0.25, 1.6, 2.4, b, l, c);
  });
  const rows = [
    ["check", "Web admin W01–W05", "Mỗi màn có ảnh cho 4 ý: thao tác chính, từ chối sai vai trò, rỗng, lỗi khi mất mạng."],
    ["robot", "ARTEMIS của Google", "Agent AI tự chạm trên máy Android; test đối chiếu kết quả với Firestore, không chỉ tin lời agent."],
    ["bug", "Lần chạy không tính", "Máy ảo quá tải hoặc mô hình của ARTEMIS lỗi thì chạy lại, nguyên nhân ghi trong test-plan."],
  ];
  rows.forEach(([icon, head, text], i) => iconRow(s, icon, head, text, 0.6, 4.1 + i * 0.82, 12.1, { d: 0.5, size: 14, h: 0.75 }));
  source(s, "Chi tiết: docs/test-report.md, docs/test-plan.md mục 3; JUnit của từng lần chạy: evidence/artemis/run-*.xml.");
  s.addNotes("Kiểm thử gồm bốn phần. Security Rules có 172 test chạy trên Emulator, đều đạt. ARTEMIS có 19 kịch bản cho các luồng Lab 2, tính năng AI và luồng liên vai trò, mỗi kịch bản chạy ba lần và đạt cả ba. Luồng liên vai trò chạy ba lần trên hệ thống thật, mỗi lần khoảng một giây. Ngoài ra có 905 test đơn vị và widget. Web admin có bảng kiểm tra từng màn với ảnh chụp. Các test ARTEMIS mới còn đọc lại Firestore để chắc kết quả là thật. Lần chạy hỏng vì máy ảo quá tải hoặc vì mô hình của ARTEMIS được ghi nguyên nhân và chạy lại.");
}

// 13 ─ Architecture and AI code review
{
  const s = content(P4, "Code theo MVVM với gói dùng chung; AI review tìm ra 10 vấn đề, sửa 9");
  const layers = [["Màn hình (widget)", C.accent1, C.text1], ["ViewModel", C.accent1, C.text1],
    ["Repository, Service (interface)", C.text2, C.background1], ["Firebase, Cloudinary", "FFF1DE", C.text1]];
  layers.forEach(([t, f, c], i) => {
    const y = 1.55 + i * 1.08;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y, w: 3.7, h: 0.78, rectRadius: 0.1, fill: { color: f },
      line: { type: "none" }, objectName: t });
    s.addText(t, { x: 0.6, y, w: 3.7, h: 0.78, fontSize: 15, bold: true, color: c, align: "center", valign: "middle",
      margin: 0, isTextBox: true });
    if (i < 3) s.addShape(pres.shapes.LINE, { x: 2.45, y: y + 0.78, w: 0, h: 0.3, line: { color: C.accent5, width: 1.5, endArrowType: "triangle" } });
  });
  s.addText("Test kiến trúc chạy cùng flutter test: màn hình và ViewModel không được gọi thẳng SDK Firebase; web không có model hay repository riêng.",
    { x: 0.6, y: 5.95, w: 3.7, h: 0.65, fontSize: 12, color: C.accent5, margin: 0, isTextBox: true, valign: "top" });
  const hdr = (t) => ({ text: t, options: { bold: true, color: C.background1, fill: { color: C.text2 } } });
  s.addTable([
    [hdr("Mã"), hdr("Loại"), hdr("Phát hiện"), hdr("Quyết định")],
    ["CR-F01", "Lỗi", "Kết quả AI ghi đè ô nhân viên vừa gõ trong lúc chờ", "Đã sửa"],
    ["CR-F03", "Bảo mật", "Thông báo đẩy chạy nền ghi Firestore mà chưa bật App Check", "Đã sửa"],
    ["CR-F05", "Bảo mật", "Bản release có thể dùng debug token của App Check", "Đã sửa"],
    ["CR-F06", "Lỗi", "Tải ảnh lên trước khi kiểm tra trùng tên, để lại ảnh thừa", "Đã sửa"],
    ["CR-F08", "Giới hạn", "Lấy 50 thông báo mới nhất rồi mới lọc theo kiosk", "Không sửa: mỗi tuần chỉ vài thông báo, đã ghi lại"],
  ], { x: 4.75, y: 1.55, w: 8.0, colW: [0.95, 1.0, 3.85, 2.2], fontSize: 13, color: C.text1,
    border: { type: "solid", color: "E4DFD8", pt: 0.75 }, fill: { color: C.background1 }, margin: 0.06, valign: "middle" });
  s.addText("Tổng cộng 10 phát hiện: 5 lỗi chức năng, 2 bảo mật, 1 hiệu năng, 2 khả năng bảo trì. 9 đã sửa trong 3 pull request.",
    { x: 4.75, y: 5.6, w: 8.0, h: 0.7, fontSize: 14, color: C.text1, margin: 0, isTextBox: true, valign: "top" });
  source(s, "Review bằng Claude Code /code-review: evidence/code-review/final/; quyết định từng mục: docs/test-report.md mục 5.");
  s.addNotes("Code theo MVVM: màn hình chỉ vẽ trạng thái, ViewModel giữ trạng thái và gọi repository qua interface, repository mới làm việc với Firebase. Model và repository nằm trong gói dùng chung nên web và mobile dùng cùng một bản. Có test kiến trúc chạy cùng flutter test để chặn màn hình gọi thẳng SDK. Nhóm dùng Claude Code để review phần code mới, được 10 phát hiện. Ví dụ CR-F03: thông báo đẩy chạy nền ghi Firestore mà chưa bật App Check, đã sửa. Chỉ CR-F08 không sửa vì mỗi tuần chỉ có vài thông báo, nhóm ghi lại là giới hạn đã biết.");
}

// 14 ─ Lessons learned
{
  const s = content(P4, "Bài học: có những lỗi chỉ lộ ra khi chạy trên hệ thống thật");
  const rows = [
    ["bug", "Ba lỗi chỉ lộ ra khi chạy thật",
      "Mất mạng thì web báo \"Kiosk chưa có món\" vì đọc bộ nhớ đệm rỗng; đổi kiosk vẫn hiện hàng chờ cũ; đơn tiền mặt bị từ chối vẫn được hứa hoàn tiền. Cả ba đã sửa (#110, #111, #114)."],
    ["check", "Test tự động phải đối chiếu dữ liệu thật",
      "Agent ARTEMIS từng báo đã thêm món vào giỏ trong khi giỏ trên Firestore vẫn trống. Đọc lại Firestore mới biết kết quả có thật hay không."],
    ["shield", "Xem số liệu trước khi bật App Check",
      "20% yêu cầu chưa xác minh đến từ các bản app cũ. Kiểm tra token của cả hai ứng dụng trước, nên bật xong không ai bị chặn nhầm."],
    ["cloud", "Gói miễn phí giới hạn cả thiết kế",
      "Không có Cloud Functions, nên thông báo trạng thái đơn do ứng dụng tự ghi khi đang mở. Nhắc khách lấy món sau 10 phút thì chưa làm được."],
  ];
  rows.forEach(([icon, head, text], i) => {
    const x = 0.6 + (i % 2) * 6.15, y = 1.5 + Math.floor(i / 2) * 2.6;
    card(s, x, y, 5.95, 2.4, `lesson ${i + 1}`);
    iconRow(s, icon, head, text, x + 0.3, y + 0.3, 5.45, { d: 0.65, size: 15, h: 1.95 });
  });
  s.addNotes("Bài học lớn nhất là phải chạy trên hệ thống thật. Ba lỗi trên web và mobile chỉ lộ ra khi dùng Firebase thật, test với dữ liệu giả đều qua. Thứ hai, test tự động phải đối chiếu dữ liệu thật: agent ARTEMIS có lần báo đã thêm món nhưng giỏ trên Firestore trống. Thứ ba, trước khi bật App Check nên xem số liệu: 20% yêu cầu chưa xác minh đến từ bản app cũ. Cuối cùng, gói miễn phí không có Cloud Functions nên một số việc như nhắc khách lấy món chưa làm được, cần tính từ lúc thiết kế.");
}

// 15 ─ Limitations and conclusion
{
  const s = pres.addSlide({ masterName: "DARK", sectionTitle: P4 });
  s.addText("Hệ thống chạy trọn vẹn trên Firebase", { placeholder: "title" });
  s.addText("Ba giới hạn nhóm đã biết và đã ghi lại", { placeholder: "body" });
  const lim = [
    ["Chưa đăng ký Play Integrity", "Chỉ bản debug có debug token đã đăng ký mới đọc được dữ liệu. Máy khác cần đăng ký thêm token."],
    ["Không có server", "Không có Cloud Functions nên chưa nhắc lại khi khách quên lấy món."],
    ["Thông báo theo kiosk (CR-F08)", "Lấy 50 thông báo mới nhất rồi mới lọc theo kiosk."],
  ];
  lim.forEach(([h, t], i) => s.addText([
    { text: h, options: { bold: true, color: C.accent1, breakLine: true } },
    { text: t, options: { color: C.background1 } },
  ], { x: 0.7, y: 3.85 + i * 0.95, w: 6.3, h: 0.9, fontSize: 15, margin: 0, isTextBox: true, valign: "top" }));
  const links = [
    ["globe", "Web admin", "breakbite-1315b.web.app"],
    ["code", "Mã nguồn", "github.com/baonv0817/PRM393_Lab03_Group2"],
    ["camera", "Video demo", "link trong README của repository"],
    ["chart", "Báo cáo", "report/Final_SE193905.pdf"],
  ];
  links.forEach(([icon, h, t], i) => iconRow(s, icon, h, t, 7.75, 1.3 + i * 1.3, 5.0,
    { size: 15, h: 1.0, headColor: C.background1, textColor: C.accent1 }));
  s.addNotes("Tóm lại, hệ thống chạy trọn vẹn: ứng dụng Android, web admin và backend Firebase, với luồng liên vai trò khoảng một giây và các test đều có minh chứng. Nhóm còn ba giới hạn đã ghi lại: chưa có Play Integrity nên chỉ bản debug có token đăng ký đọc được dữ liệu, chưa có server nên chưa nhắc lại khi khách quên lấy món, và danh sách thông báo theo kiosk lấy 50 bản mới nhất trước khi lọc. Link web, mã nguồn, video và báo cáo ở bên phải. Em xin cảm ơn thầy cô đã lắng nghe.");
}

(async () => {
  await pres.writeFile({ fileName: OUT });
  if (SKILL) {
    const { applyTheme } = require(path.join(SKILL, "scripts", "apply_theme.js"));
    await applyTheme(OUT, THEME);
  }
  console.log("wrote", OUT);
})();
