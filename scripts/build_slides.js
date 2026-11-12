// Builds slides/Lab03_SE193905_slides.pptx (15 slides, text in Vietnamese) from the repo's own evidence.
//
// Run from the repo root:
//   python scripts/prepare_slide_images.py             (crops the console screenshots into slides/img/)
//   NODE_PATH=<folder with node_modules/pptxgenjs> node scripts/build_slides.js
// SKILL_DIR=<Claude pptx skill folder> writes the theme colours into the file with its apply_theme.js;
// without it the file still opens, with Office's stock scheme colours.
//
// Structure: Lab 3 handout section 9 (slide list) and Software_Project_Presentation_Guideline (one message per
// slide, the title states the conclusion, evidence on every "it works" slide). Every cloud-service slide has the
// same frame, because the lecturer grades how well each service is explained:
//   left   how it works, as a sequence diagram (who issues what, where it is stored, what the app does)
//   right  evidence from the app or the console
//   bottom "Khi lỗi" (failure handling) and the code path
// Icons in slides/img/icons are Lucide icons (ISC licence) rendered to PNG through react-icons.
const path = require('path');
const fs = require('fs');
const pptxgen = require('pptxgenjs');

const ROOT = path.resolve(__dirname, '..');
const OUT = process.env.OUT || path.join(ROOT, 'slides', 'Lab03_SE193905_slides.pptx');
const SKILL_DIR = process.env.SKILL_DIR || '';
const ev = (...p) => path.join(ROOT, 'evidence', ...p);
const crop = (f) => path.join(ROOT, 'slides', 'img', f);
const icon = (name, tone) => path.join(ROOT, 'slides', 'img', 'icons', `${name}-${tone || 'w'}.png`);

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
pres.layout = 'LAYOUT_WIDE'; // 13.333 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = 'BreakBite - PRM393 Lab 3';
pres.author = 'Team BreakBite (Group 2)';
pres.company = 'PRM393';
const C = pres.SchemeColor;
const S = pres.ShapeType;

const MX = 0.6; // side margin
const CW = 12.133; // content width
const RIGHT = MX + CW;
const TOP = 2.05; // top of the content area
const CODE_FONT = 'Courier New';
const FOOTER = 'BreakBite · PRM393 Lab 3 · Nhóm 2';

// -- layouts ---------------------------------------------------------------------------------------------------
const titleBox = { x: MX, y: 0.88, w: CW, h: 1.05 };
pres.defineSlideMaster({
  title: 'TITLE',
  background: { color: C.text2 },
  placeholders: [
    { placeholder: { options: { name: 'title', type: 'title', x: MX, y: 2.5, w: 6.4, h: 1.2, fontSize: 60, bold: true, color: C.background1, valign: 'top', margin: 0 }, text: '' } },
  ],
});
pres.defineSlideMaster({
  title: 'CONTENT',
  background: { color: C.background1 },
  objects: [
    { text: { text: FOOTER, options: { x: MX, y: 7.02, w: 6, h: 0.3, fontSize: 10, color: C.accent5, margin: 0 } } },
  ],
  slideNumber: { x: RIGHT - 0.6, y: 7.02, w: 0.6, h: 0.3, fontSize: 10, color: C.accent5, align: 'right' },
  placeholders: [
    { placeholder: { options: Object.assign({ name: 'title', type: 'title', fontSize: 28, bold: true, color: C.text2, valign: 'top', margin: 0 }, titleBox), text: '' } },
  ],
});
pres.defineSlideMaster({
  title: 'CLOSING',
  background: { color: C.text2 },
  objects: [
    { text: { text: FOOTER, options: { x: MX, y: 7.02, w: 6, h: 0.3, fontSize: 10, color: C.accent6, margin: 0 } } },
  ],
  slideNumber: { x: RIGHT - 0.6, y: 7.02, w: 0.6, h: 0.3, fontSize: 10, color: C.accent6, align: 'right' },
  placeholders: [
    { placeholder: { options: Object.assign({ name: 'title', type: 'title', fontSize: 28, bold: true, color: C.background1, valign: 'top', margin: 0 }, titleBox), text: '' } },
  ],
});

// -- building blocks -------------------------------------------------------------------------------------------
// Text margins in pptxgenjs are points, ordered [left, right, bottom, top]; table margins below 1 are inches.
function text(s, str, o) {
  s.addText(str, Object.assign({ isTextBox: true, fontSize: 14, color: C.text1, margin: 0, valign: 'top' }, o));
}
// Kicker above the title: an icon in an orange circle and the section label.
function kicker(s, label, iconName, dark) {
  s.addShape(S.ellipse, { x: MX, y: 0.33, w: 0.42, h: 0.42, fill: { color: C.accent1 }, line: { type: 'none' }, objectName: 'kicker-icon-bg' });
  s.addImage({ path: icon(iconName, 'w'), x: MX + 0.09, y: 0.42, w: 0.24, h: 0.24, objectName: 'kicker-icon' });
  text(s, label, { x: MX + 0.56, y: 0.33, w: 10, h: 0.42, fontSize: 12, bold: true, charSpacing: 1.5, color: dark ? C.accent1 : C.accent2, valign: 'middle' });
}
// The placeholder gets its position and style again on the slide: LibreOffice (used for the PDF) does not
// inherit them from the layout and would put the title at the top-left corner.
function titleOpts(dark) {
  return Object.assign({ placeholder: 'title', fontSize: 28, bold: true, fontFace: THEME.headFontFace, color: dark ? C.background1 : C.text2, valign: 'top', margin: 0 }, titleBox);
}
function slide(section, layout, label, iconName, title, notes) {
  const s = pres.addSlide({ masterName: layout, sectionTitle: section });
  kicker(s, label, iconName, layout === 'CLOSING');
  s.addText(title, titleOpts(layout === 'CLOSING'));
  if (notes) s.addNotes(notes);
  return s;
}
function caption(s, str, x, y, w, o) {
  text(s, str, Object.assign({ x, y, w, h: 0.3, fontSize: 11, color: C.accent5 }, o));
}
function shadow() {
  return { type: 'outer', color: '000000', opacity: 0.22, blur: 6, offset: 2, angle: 90 };
}
// A phone screenshot (1080 x 2400) in a dark frame. Returns the frame width.
function phone(s, file, x, y, h, name) {
  const b = 0.06;
  const ih = h - 2 * b;
  const iw = ih * 0.45;
  s.addShape(S.roundRect, { x, y, w: iw + 2 * b, h, rectRadius: 0.12, fill: { color: C.text1 }, line: { type: 'none' }, shadow: shadow(), objectName: `${name}-frame` });
  s.addImage({ path: file, x: x + b, y: y + b, w: iw, h: ih, objectName: name });
  return iw + 2 * b;
}
// A console screenshot or crop with a thin border. Width is given; returns the height used.
function shot(s, file, x, y, w, aspect, name) {
  const h = w / aspect;
  s.addShape(S.rect, { x: x - 0.02, y: y - 0.02, w: w + 0.04, h: h + 0.04, fill: { color: C.accent6 }, line: { type: 'none' }, objectName: `${name}-border` });
  s.addImage({ path: file, x, y, w, h, objectName: name });
  return h;
}
function card(s, x, y, w, h, o) {
  s.addShape(S.roundRect, Object.assign({ x, y, w, h, rectRadius: 0.08, fill: { color: C.background2 }, line: { color: C.accent6, width: 0.75 } }, o));
}
function failure(s, str, x, y, w, h) {
  s.addText([
    { text: 'Khi lỗi   ', options: { bold: true, color: C.accent4 } },
    { text: str, options: { color: C.text1 } },
  ], {
    isTextBox: true, shape: S.roundRect, rectRadius: 0.08, x, y, w, h, fontSize: 13.5, valign: 'middle',
    fill: { color: C.accent4, transparency: 91 }, line: { type: 'none' }, margin: [12, 12, 4, 4], objectName: 'khi-loi',
  });
}
function code(s, paths, x, y, w) {
  s.addText([
    { text: 'Mã nguồn  ', options: { bold: true, color: C.accent5, fontFace: THEME.bodyFontFace, fontSize: 11 } },
    { text: paths, options: { color: C.text2, fontFace: CODE_FONT, fontSize: 10 } },
  ], { isTextBox: true, x, y, w, h: 0.42, margin: 0, valign: 'top', objectName: 'code-path' });
}
function badge(s, n, cx, cy, d) {
  const r = (d || 0.28) / 2;
  s.addText(String(n), {
    shape: S.ellipse, x: cx - r, y: cy - r, w: 2 * r, h: 2 * r, fontSize: 10.5, bold: true, align: 'center', valign: 'middle',
    color: C.background1, fill: { color: C.accent2 }, line: { color: C.background1, width: 1 }, margin: 0,
  });
}

// Sequence diagram: actors in lanes, one numbered message per row.
// msgs: { from, to, text } ; from === to draws a note on that lane.
function seq(s, { x, y, w, actors, msgs, rowH }) {
  rowH = rowH || 0.62;
  const lane = w / actors.length;
  const cx = {};
  actors.forEach((a, i) => { cx[a.key] = x + lane * (i + 0.5); });
  const headH = 0.5;
  const hw = Math.min(lane - 0.14, 1.9);
  const top = y + headH;
  const end = top + 0.12 + msgs.length * rowH;
  actors.forEach((a) => s.addShape(S.line, { x: cx[a.key], y: top, w: 0, h: end - top, line: { color: C.accent6, width: 1.5, dashType: 'dash' } }));
  actors.forEach((a) => s.addText(a.label, {
    shape: S.roundRect, rectRadius: 0.06, x: cx[a.key] - hw / 2, y, w: hw, h: headH, fontSize: 12.5, bold: true,
    align: 'center', valign: 'middle', color: C.background1, fill: { color: C.text2 }, line: { type: 'none' }, margin: 3,
  }));
  const clamp = (lx, lw) => Math.max(x, Math.min(lx, x + w - lw));
  msgs.forEach((m, i) => {
    const rowTop = top + 0.12 + i * rowH;
    const ay = rowTop + rowH - 0.13;
    const x1 = cx[m.from];
    if (m.from === m.to) {
      const nw = Math.min(w, 4.6);
      const nx = clamp(x1 - nw / 2, nw);
      s.addText(m.text, {
        shape: S.roundRect, rectRadius: 0.06, x: nx, y: rowTop + 0.04, w: nw, h: rowH - 0.1, fontSize: 12, align: 'left', valign: 'middle',
        color: C.text1, fill: { color: C.background2 }, line: { color: C.accent1, width: 1 }, margin: [27, 6, 1, 1],
      });
      badge(s, i + 1, nx + 0.2, rowTop + 0.04 + (rowH - 0.1) / 2);
      return;
    }
    const x2 = cx[m.to];
    const right = x2 > x1;
    const lx = Math.min(x1, x2);
    const rx = Math.max(x1, x2);
    s.addShape(S.line, {
      x: lx, y: ay, w: rx - lx, h: 0,
      line: Object.assign({ color: C.accent2, width: 1.75 }, right ? { endArrowType: 'triangle' } : { beginArrowType: 'triangle' }),
    });
    // The label starts next to the numbered badge and runs in the arrow's direction, so the badge never covers it.
    const room = right ? x + w - x1 - 0.2 : x1 - 0.2 - x;
    const lw = Math.min(Math.max(rx - lx - 0.3, 3.3), room);
    const lxx = right ? x1 + 0.2 : x1 - 0.2 - lw;
    s.addText(m.text, {
      isTextBox: true, x: lxx, y: rowTop, w: lw, h: ay - rowTop - 0.06, fontSize: 12, align: right ? 'left' : 'right', valign: 'bottom',
      color: C.text1, margin: [2, 2, 0, 0],
    });
    badge(s, i + 1, x1, ay);
  });
  return end;
}

// Row of boxes joined by arrows.
function flow(s, items, x, y, w, h, o) {
  const gap = 0.42;
  const bw = (w - gap * (items.length - 1)) / items.length;
  items.forEach((it, i) => {
    const bx = x + i * (bw + gap);
    s.addText([
      { text: it[0], options: { bold: true, fontSize: 15, color: C.text2, breakLine: true } },
      { text: it[1], options: { fontSize: 12, color: C.text1 } },
    ], Object.assign({
      shape: S.roundRect, rectRadius: 0.08, x: bx, y, w: bw, h, align: 'center', valign: 'middle',
      fill: { color: C.background2 }, line: { color: C.accent6, width: 0.75 }, margin: 6,
    }, o));
    if (i < items.length - 1) s.addShape(S.rightArrow, { x: bx + bw + 0.08, y: y + h / 2 - 0.13, w: gap - 0.16, h: 0.26, fill: { color: C.accent1 }, line: { type: 'none' } });
  });
}
function stat(s, big, label, x, y, w, o) {
  o = o || {};
  s.addText(big, { isTextBox: true, x, y, w, h: o.bigH || 0.8, fontSize: o.size || 44, bold: true, fontFace: THEME.headFontFace, color: o.color || C.accent2, margin: 0, valign: 'bottom' });
  text(s, label, { x, y: y + (o.bigH || 0.8) + 0.05, w, h: o.labelH || 0.7, fontSize: o.labelSize || 13, color: o.labelColor || C.text1 });
}
const hdr = (t, o) => ({ text: t, options: Object.assign({ bold: true, color: C.background1, fill: { color: C.text2 }, fontSize: 12, valign: 'middle' }, o) });
const cellOpts = (o) => Object.assign({ fontSize: 12.5, color: C.text1, valign: 'middle' }, o);

// Service-slide grid
const LX = MX; // diagram
const LW = 6.2;
const RX = 7.1; // evidence
const RW = RIGHT - RX;

// ===============================================================================================================
// 1. Title
pres.addSection({ title: 'Sản phẩm' });
{
  const s = pres.addSlide({ masterName: 'TITLE', sectionTitle: 'Sản phẩm' });
  s.addImage({ path: path.join(ROOT, 'assets', 'brand', 'breakbite_logo.png'), x: MX, y: 0.75, w: 1.0, h: 1.0, objectName: 'logo' });
  text(s, 'PRM393 · LAB 3 · NHÓM 2', { x: MX, y: 2.1, w: 6.4, h: 0.35, fontSize: 13, bold: true, charSpacing: 2, color: C.accent1 });
  s.addText('BreakBite', { placeholder: 'title', x: MX, y: 2.5, w: 6.4, h: 1.2, fontSize: 60, bold: true, fontFace: THEME.headFontFace, color: C.background1, valign: 'top', margin: 0 });
  text(s, 'App cho sinh viên đặt món trước trong giờ giải lao, rồi đến kiosk lấy.', { x: MX, y: 3.75, w: 6.2, h: 1.0, fontSize: 22, color: C.background1 });
  const facts = [
    ['NGƯỜI DÙNG', 'Sinh viên và nhân viên kiosk, Campus Quận 9'],
    ['ỨNG DỤNG', 'Flutter trên Android; một app có cả phần khách và phần bếp'],
    ['BACKEND', 'Firebase (gói miễn phí Spark); tệp PDF lưu trên Cloudinary'],
  ];
  facts.forEach((f, i) => {
    const x = MX + i * 2.2;
    text(s, f[0], { x, y: 5.0, w: 2.0, h: 0.3, fontSize: 11, bold: true, charSpacing: 1.5, color: C.accent1 });
    text(s, f[1], { x, y: 5.32, w: 2.0, h: 0.95, fontSize: 14, color: C.background1 });
  });
  text(s, 'github.com/baonv0817/PRM393_Lab03_Group2', { x: MX, y: 6.75, w: 6.5, h: 0.3, fontSize: 12, color: C.accent6 });
  const pw = phone(s, ev('auth', '2-signed-in.png'), 7.15, 0.7, 5.7, 'customer-home');
  phone(s, ev('p4-real', 'K02-new-order.png'), 7.15 + pw + 0.35, 0.7, 5.7, 'seller-orders');
  caption(s, 'App khách · Trang chủ', 7.15, 6.5, pw, { align: 'center', color: C.accent6 });
  caption(s, 'App bếp · đơn mới', 7.15 + pw + 0.35, 6.5, pw, { align: 'center', color: C.accent6 });
  s.addNotes('BreakBite là app đặt món trước cho sinh viên Campus Quận 9: đặt trong giờ giải lao, đến kiosk lấy món. '
    + 'Một project Flutter chứa cả app khách và app bếp; vai trò trong tài khoản (users/{uid}.role) quyết định mở app nào. '
    + 'Backend là Firebase gói Spark miễn phí; tệp PDF lưu trên Cloudinary vì Cloud Storage cần gói trả phí. '
    + 'Hai ảnh bên phải chụp trên Firebase thật: Trang chủ của khách và màn đơn mới của bếp.');
}

// 2. Persona, success criterion, flows
{
  const s = slide('Sản phẩm', 'CONTENT', 'SẢN PHẨM · TÓM TẮT LAB 2', 'user',
    'Mục tiêu: sinh viên đặt xong một đơn trong 35 giây, tối đa 8 lần chạm',
    'Persona từ Lab 2: sinh viên học ở Campus Quận 9, có khoảng 15 phút giữa hai tiết. '
    + 'Tiêu chí thành công: đặt xong một đơn dưới 35 giây, tối đa 8 lần chạm, đo bằng sự kiện purchase trong kế hoạch Analytics. '
    + 'Bảng bên phải là ba luồng Lab 2 và luồng của bếp. Mỗi luồng có nhánh lỗi và một ca ARTEMIS chạy hết luồng đó (TC-03, 04, 05, 12). '
    + 'Đã làm 44/44 màn của trang Final UI: 30 màn khách S01–S30 và các màn bếp K01–K15 (K07 không có khung Figma).');
  card(s, MX, TOP, 3.75, 4.8);
  const ix = MX + 0.25;
  text(s, 'PERSONA', { x: ix, y: TOP + 0.2, w: 3.3, h: 0.3, fontSize: 11, bold: true, charSpacing: 1.5, color: C.accent2 });
  text(s, 'Sinh viên học ở Campus Quận 9, có khoảng 15 phút giữa hai tiết.', { x: ix, y: TOP + 0.52, w: 3.3, h: 0.95, fontSize: 15 });
  text(s, 'TIÊU CHÍ THÀNH CÔNG (LAB 2)', { x: ix, y: TOP + 1.6, w: 3.3, h: 0.3, fontSize: 11, bold: true, charSpacing: 1.5, color: C.accent2 });
  stat(s, '< 35 s', 'để đặt xong một đơn', ix, TOP + 1.9, 1.4, { size: 30, bigH: 0.6, labelH: 0.5 });
  stat(s, '≤ 8 chạm', 'từ Trang chủ đến khi đặt đơn', ix + 1.45, TOP + 1.9, 1.85, { size: 30, bigH: 0.6, labelH: 0.6 });
  text(s, 'PHẠM VI ĐÃ LÀM', { x: ix, y: TOP + 3.3, w: 3.3, h: 0.3, fontSize: 11, bold: true, charSpacing: 1.5, color: C.accent2 });
  text(s, [
    { text: '44 / 44', options: { bold: true, fontFace: THEME.headFontFace, fontSize: 22, color: C.accent2 } },
    { text: '  màn hình trong Figma đã làm xong (app khách và app bếp)', options: { fontSize: 14 } },
  ], { x: ix, y: TOP + 3.6, w: 3.3, h: 0.75 });
  caption(s, 'Đo bằng sự kiện purchase trong kế hoạch Analytics.', ix, TOP + 4.3, 3.3, { h: 0.4 });

  const rows = [
    [hdr(''), hdr('Luồng'), hdr('Màn hình'), hdr('Nhánh lỗi'), hdr('Test', { align: 'center' })],
    ['F1', 'Đặt nhanh từ Trang chủ', 'S02 → S05 giỏ → S06 thanh toán → cổng thanh toán → S07 theo dõi', 'Thanh toán bị từ chối →\nS06-ERR', 'TC-03'],
    ['F2', 'Tuỳ chọn món và dùng mã giảm giá', 'S03 thực đơn → S04 món → S05 giỏ → S29 mã', 'Mã BB20 hết hạn →\nS05-VOUCHER-ERR', 'TC-04'],
    ['F3', 'Xử lý khi thanh toán thất bại', 'S06-ERR → S07-CASH →\nS07-DIALOG → S10', 'Trả tiền mặt tại kiosk; giỏ hàng được giữ', 'TC-05'],
    ['K', 'Bếp: nhận, làm và giao đơn', 'K02 → K03 → K04 → K05 quét mã → K06', 'Sai mã nhận món →\nK05-ERR', 'TC-12'],
  ].map((r, i) => (i === 0 ? r : r.map((t, j) => ({
    text: t,
    options: cellOpts({
      bold: j <= 1, color: j === 0 ? C.background1 : j === 3 ? C.accent4 : C.text1, align: j === 0 || j === 4 ? 'center' : 'left',
      fill: { color: j === 0 ? C.accent2 : (i % 2 ? C.background1 : C.background2) }, fontSize: j === 0 ? 14 : 13,
    }),
  }))));
  s.addTable(rows, { x: 4.65, y: TOP, w: 8.083, colW: [0.55, 2.1, 2.55, 2.08, 0.803], rowH: [0.42, 0.95, 0.95, 0.95, 0.95], border: { type: 'solid', pt: 0.75, color: C.accent6 }, margin: [0.04, 0.1, 0.04, 0.1] });
  caption(s, 'Mã màn hình theo file Figma Lab 2; bảng đầy đủ ở docs/design-traceability.md, mục 3.', 4.65, 6.45, 8.0);
}

// 3. Figma vs app
pres.addSection({ title: 'Thiết kế' });
{
  const s = slide('Thiết kế', 'CONTENT', 'THIẾT KẾ · FIGMA VÀ APP', 'palette',
    'App làm theo Figma; 34 chỗ khác Figma đều có ghi lý do',
    'Mỗi ảnh là một cặp: bên trái là Figma (Final UI v2), bên phải là app thật trên Android. Ba cặp ứng với ba luồng F1, F2, F3. '
    + 'Có 34 khác biệt D01–D34, mỗi khác biệt ghi lý do trong docs/design-traceability.md mục 5. '
    + 'Ví dụ D01: đổi đăng nhập e-mail + OTP sang Google Sign-In vì đề Lab 3 bắt buộc. D12: nút + biến thành bộ tăng giảm số lượng nên bỏ snackbar. '
    + 'D23: form món của bếp không có ô ảnh vì app không tải ảnh lên, Cloudinary chỉ nhận PDF.');
  const pairs = [['p1-S02.png', 'F1 · Trang chủ (S02)'], ['p1-S05-VOUCHER-ERR.png', 'F2 · giỏ có mã hết hạn (S05)'], ['p1-S06-ERR.png', 'F3 · lỗi thanh toán (S06-ERR)']];
  const ph = 3.4;
  const pw = ph * 1110 / 1250;
  pairs.forEach((p, i) => {
    const x = MX + i * (pw + 0.3);
    shot(s, ev('figma', p[0]), x, TOP, pw, 1110 / 1250, `figma-pair-${i + 1}`);
    caption(s, p[1], x, TOP + ph + 0.08, pw);
  });
  const sx = MX + 3 * (pw + 0.3) + 0.1;
  stat(s, '34', 'chỗ khác Figma, chỗ nào cũng có lý do', sx, TOP, RIGHT - sx, { size: 54, bigH: 0.9, labelH: 0.6, labelSize: 14 });
  caption(s, 'D01–D34, ghi ở mục 5 của\ndocs/design-traceability.md', sx, TOP + 1.65, RIGHT - sx, { h: 0.5 });
  text(s, 'Mỗi cặp: bên trái là Figma, bên phải là app.', { x: sx, y: TOP + 2.4, w: RIGHT - sx, h: 0.8, fontSize: 12, color: C.accent5 });
  const devs = [
    ['D01  ', 'Đăng nhập bằng Google thay cho e-mail + OTP, vì đề Lab 3 bắt buộc.'],
    ['D12  ', 'Bấm + thì hiện ô tăng/giảm số lượng, bỏ snackbar: khách thấy ngay số món.'],
    ['D23  ', 'Form thêm món của bếp bỏ ô ảnh: app chỉ tải PDF lên, không tải ảnh.'],
  ];
  devs.forEach((d, i) => {
    const x = MX + i * (pw + 0.3);
    s.addText([{ text: d[0], options: { bold: true, color: C.accent2 } }, { text: d[1], options: { color: C.text1 } }], {
      isTextBox: true, shape: S.roundRect, rectRadius: 0.08, x, y: 5.95, w: pw, h: 0.85, fontSize: 13, valign: 'middle',
      fill: { color: C.background2 }, line: { color: C.accent6, width: 0.75 }, margin: [9, 9, 3, 3],
    });
  });
}

// 4. Architecture
{
  const s = slide('Thiết kế', 'CONTENT', 'THIẾT KẾ · KIẾN TRÚC', 'layers',
    'Màn hình không gọi thẳng Firebase: mọi lệnh gọi đi qua ViewModel rồi tới service',
    'MVVM với Provider. Màn hình chỉ vẽ ViewState và chuyển thao tác. ViewModel giữ trạng thái kiểu sealed class ViewState: đang tải, rỗng, lỗi, có dữ liệu. '
    + 'Repository hoặc service mới gọi SDK; mỗi SDK có một lớp, được tiêm qua Provider nên khi test thay bằng bản giả trong dev/. '
    + 'test/architecture_test.dart thất bại nếu màn hình import SDK, dùng literal màu hoặc kiểu chữ, hoặc ViewModel thiếu SafeChangeNotifier. '
    + 'Nhóm không có server riêng: dữ liệu được bảo vệ bằng Security Rules chạy trên máy chủ Firebase. Cloudinary thay Cloud Storage vì Cloud Storage cần gói Blaze.');
  const layers = [
    ['phone', 'Màn hình', 'ui/*/widgets', 'Chỉ hiển thị và nhận thao tác. Không gọi Firebase, không tự đặt màu.'],
    ['layers', 'ViewModel', 'ui/*/view_models', 'Giữ trạng thái màn hình: đang tải, rỗng, lỗi, có dữ liệu. Kiểm tra dữ liệu nhập.'],
    ['firestore', 'Repository / Service', 'data/', 'Mỗi dịch vụ một lớp, cấp qua Provider. Lỗi trả về dạng Result, không ném exception.'],
  ];
  const lw = 6.3;
  layers.forEach((l, i) => {
    const y = TOP + i * 1.3;
    card(s, MX, y, lw, 0.98);
    s.addShape(S.ellipse, { x: MX + 0.2, y: y + 0.25, w: 0.48, h: 0.48, fill: { color: C.accent1 }, line: { type: 'none' } });
    s.addImage({ path: icon(l[0], 'w'), x: MX + 0.31, y: y + 0.36, w: 0.26, h: 0.26 });
    text(s, l[1], { x: MX + 0.85, y: y + 0.17, w: 1.95, h: 0.36, fontSize: 16, bold: true, color: C.text2 });
    text(s, l[2], { x: MX + 0.85, y: y + 0.55, w: 1.95, h: 0.3, fontSize: 10.5, fontFace: CODE_FONT, color: C.accent5 });
    text(s, l[3], { x: MX + 2.85, y: y + 0.08, w: lw - 3.0, h: 0.82, fontSize: 13.5, valign: 'middle' });
    if (i < 2) s.addShape(S.downArrow, { x: MX + lw / 2 - 0.15, y: y + 1.02, w: 0.3, h: 0.24, fill: { color: C.accent1 }, line: { type: 'none' } });
  });
  s.addText([
    { text: 'domain/models', options: { fontFace: CODE_FONT, fontSize: 11, color: C.text2, bold: true } },
    { text: '   dữ liệu và quy tắc nghiệp vụ, lớp nào cũng dùng được', options: { fontSize: 13 } },
  ], { isTextBox: true, shape: S.roundRect, rectRadius: 0.08, x: MX, y: TOP + 3.95, w: lw, h: 0.5, valign: 'middle', color: C.text1, fill: { color: C.background1 }, line: { color: C.accent5, width: 0.75, dashType: 'dash' }, margin: [14, 14, 0, 0] });
  s.addShape(S.rightArrow, { x: MX + lw + 0.08, y: TOP + 2.6 + 0.36, w: 0.42, h: 0.26, fill: { color: C.accent1 }, line: { type: 'none' } });

  const bx = MX + lw + 0.58;
  const bw = RIGHT - bx;
  s.addShape(S.roundRect, { x: bx, y: TOP, w: bw, h: 4.45, rectRadius: 0.1, fill: { color: C.text2 }, line: { type: 'none' } });
  s.addImage({ path: icon('cloud', 'w'), x: bx + 0.25, y: TOP + 0.2, w: 0.32, h: 0.32 });
  text(s, 'Dịch vụ đám mây (nhóm không có server riêng)', { x: bx + 0.7, y: TOP + 0.18, w: bw - 0.9, h: 0.36, fontSize: 16, bold: true, color: C.background1, valign: 'middle' });
  const chips = [
    ['auth', 'Authentication'], ['firestore', 'Cloud Firestore'], ['shield', 'Security Rules'], ['fcm', 'Cloud Messaging'],
    ['analytics', 'Analytics'], ['crash', 'Crashlytics'], ['config', 'Remote Config'], ['upload', 'Cloudinary (tệp PDF)'],
  ];
  const cw = (bw - 0.6) / 2;
  chips.forEach((c, i) => {
    const x = bx + 0.2 + (i % 2) * (cw + 0.2);
    const y = TOP + 0.75 + Math.floor(i / 2) * 0.74;
    s.addShape(S.roundRect, { x, y, w: cw, h: 0.6, rectRadius: 0.08, fill: { color: C.background1 }, line: { type: 'none' } });
    s.addImage({ path: icon(c[0], 'o'), x: x + 0.15, y: y + 0.15, w: 0.3, h: 0.3 });
    text(s, c[1], { x: x + 0.55, y, w: cw - 0.6, h: 0.6, fontSize: 13.5, bold: true, color: C.text2, valign: 'middle' });
  });
  text(s, 'Security Rules chạy trên máy chủ Firebase. Cloudinary thay Cloud Storage vì Cloud Storage cần gói Blaze trả phí.', { x: bx + 0.25, y: TOP + 3.75, w: bw - 0.5, h: 0.6, fontSize: 12.5, color: C.background2 });
  s.addText([
    { text: 'Có test kiểm tra  ', options: { bold: true, color: C.accent2 } },
    { text: 'test/architecture_test.dart báo lỗi nếu màn hình gọi thẳng SDK · 752 test widget và ViewModel chạy với dữ liệu giả, không cần điện thoại', options: { color: C.text1 } },
  ], { isTextBox: true, x: MX, y: 6.6, w: CW, h: 0.34, fontSize: 13, margin: 0, valign: 'top' });
}

// 5. Design system
{
  const s = slide('Thiết kế', 'CONTENT', 'THIẾT KẾ · DESIGN SYSTEM TRONG CODE', 'palette',
    'Màu và kích thước lấy từ một bộ token chung; màn hình nào tự đặt màu thì test báo lỗi',
    'Token nằm ở lib/ui/core/theme: app_colors (màu từ Figma v2), app_dimens (khoảng cách, bo góc, vùng chạm 48 dp), app_theme dựng ThemeData gồm ColorScheme và TextTheme. '
    + 'Mỗi component Lab 2 là một widget trong lib/ui/core/widgets, có biến thể và trạng thái là tham số. Trạng thái đang tải, rỗng, lỗi là widget dùng chung (state_views.dart). '
    + 'Kiểm thử: widget catalog chạy ở 360 và 412 dp, cỡ chữ 1.0 và 1.3, không tràn; các cặp màu có test độ tương phản WCAG.');
  flow(s, [
    ['Token', 'app_colors · app_dimens'],
    ['Theme', 'ThemeData: ColorScheme, TextTheme'],
    ['Component', 'mỗi component là một widget dùng lại'],
    ['Màn hình', 'lấy màu và cỡ chữ từ theme'],
  ], MX, TOP, 7.9, 1.05);
  text(s, 'TOKEN MÀU · lib/ui/core/theme/app_colors.dart', { x: MX, y: 3.35, w: 7.9, h: 0.3, fontSize: 11, bold: true, charSpacing: 1, color: C.accent2 });
  const sw = [
    ['primary', 'F69D39', C.accent1], ['onPrimary', '622B14', C.text2], ['primaryText', 'B45309', C.accent2], ['background', 'FAF8F5', C.background2],
    ['border', 'E4DFD8', C.accent6], ['muted', '6B5F55', C.accent5], ['success', '15803D', C.accent3], ['error', 'B91C1C', C.accent4],
  ];
  const sww = (7.9 - 7 * 0.13) / 8;
  sw.forEach((c, i) => {
    const x = MX + i * (sww + 0.13);
    s.addShape(S.roundRect, { x, y: 3.7, w: sww, h: 0.6, rectRadius: 0.06, fill: { color: c[2] }, line: { color: C.accent6, width: 0.75 } });
    text(s, c[0], { x, y: 4.36, w: sww, h: 0.25, fontSize: 11, bold: true, color: C.text1 });
    text(s, c[1], { x, y: 4.6, w: sww, h: 0.25, fontSize: 10, fontFace: CODE_FONT, color: C.accent5 });
  });
  text(s, 'TOKEN KHOẢNG CÁCH VÀ KÍCH THƯỚC · app_dimens.dart', { x: MX, y: 5.05, w: 7.9, h: 0.3, fontSize: 11, bold: true, charSpacing: 1, color: C.accent2 });
  let x = MX;
  [4, 8, 12, 16, 24, 32].forEach((dp) => {
    const sz = 0.1 + dp * 0.016;
    s.addShape(S.rect, { x, y: 5.95 - sz, w: sz, h: sz, fill: { color: C.accent1 }, line: { type: 'none' } });
    text(s, String(dp), { x, y: 6.0, w: 0.6, h: 0.25, fontSize: 11, color: C.accent5 });
    x += Math.max(sz, 0.3) + 0.25;
  });
  text(s, 'Nút bấm ≥ 48 dp · chữ nội dung ≥ 14 sp · bo góc 8 (chip), 16 (thẻ), 24 (sheet)', { x: x + 0.2, y: 5.45, w: MX + 7.9 - x - 0.2, h: 0.75, fontSize: 13.5, valign: 'middle' });
  caption(s, 'Đã test trên màn rộng 360 và 412 dp, cỡ chữ ×1.0 và ×1.3: không tràn chữ; các cặp màu đạt độ tương phản WCAG.', MX, 6.5, 7.9, { h: 0.4 });
  const ph = 4.1;
  const w1 = phone(s, ev('auth', '2-signed-in.png'), 8.75, TOP, ph, 'state-data');
  phone(s, ev('p1', 'S05-EMPTY.png'), 8.75 + w1 + 0.15, TOP, ph, 'state-empty');
  caption(s, 'Có dữ liệu: Trang chủ', 8.75, TOP + ph + 0.08, w1, { align: 'center' });
  caption(s, 'Trạng thái rỗng: giỏ hàng', 8.75 + w1 + 0.15 - 0.1, TOP + ph + 0.08, w1 + 0.2, { align: 'center' });
}

// 6. Authentication
pres.addSection({ title: 'Dịch vụ đám mây' });
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 1 / 7 · FIREBASE AUTHENTICATION', 'auth',
    'Đăng nhập: Google xác nhận tài khoản, Firebase cấp token; app không lưu mật khẩu',
    'Luồng: google_sign_in mở hộp chọn tài khoản, Google trả Google ID token. App đưa token đó cho FirebaseAuth.signInWithCredential, Firebase Auth cấp Firebase ID token (JWT, hết hạn sau khoảng 1 giờ) và refresh token; SDK giữ và tự làm mới, app không lưu mật khẩu. '
    + 'Vì sao cần SHA-1: Google chỉ trả token cho app có chứng chỉ ký đã khai báo trong project; mỗi máy build debug có SHA-1 riêng. '
    + 'authStateChanges báo người dùng hiện tại cho router: chưa đăng nhập thì ở màn đăng nhập S26, đã đăng nhập thì đọc role trong users/{uid} để mở app khách hoặc app bếp. '
    + 'Phía server: mọi yêu cầu Firestore mang ID token, Rules đọc request.auth.uid. Danh sách tài khoản xem ở Console, Authentication, Users (evidence/auth/4-console-users.png).');
  seq(s, {
    x: LX, y: TOP, w: LW,
    actors: [{ key: 'app', label: 'App BreakBite' }, { key: 'g', label: 'Google Sign-In' }, { key: 'fa', label: 'Firebase Auth' }],
    msgs: [
      { from: 'app', to: 'g', text: 'Mở hộp chọn tài khoản Google' },
      { from: 'g', to: 'app', text: 'Trả Google ID token (chỉ khi SHA-1 của app đã đăng ký)' },
      { from: 'app', to: 'fa', text: 'Gửi Google ID token: signInWithCredential(...)' },
      { from: 'fa', to: 'app', text: 'Trả Firebase ID token (hết hạn sau khoảng 1 giờ) và refresh token; SDK tự lưu, tự làm mới' },
      { from: 'app', to: 'app', text: 'Router nghe authStateChanges: chưa đăng nhập → S26; đã đăng nhập → đọc role, mở app khách hoặc app bếp' },
    ],
  });
  failure(s, 'Người dùng huỷ: app báo “Bạn đã huỷ đăng nhập.” và ở lại màn đăng nhập. Mất mạng hoặc không lấy được token: app báo lỗi riêng cho từng trường hợp. Khi đăng xuất, app gỡ token FCM rồi xoá phiên.', LX, 5.92, LW, 0.95);
  const ph = 3.85;
  const shots = [['1-signed-out.png', 'Chưa đăng nhập'], ['3-cancelled.png', 'Người dùng huỷ'], ['2-signed-in.png', 'Đã đăng nhập']];
  let px = RX;
  shots.forEach((p, i) => {
    const w = phone(s, ev('auth', p[0]), px, TOP, ph, `auth-${i + 1}`);
    caption(s, p[1], px - 0.05, TOP + ph + 0.06, w + 0.1, { align: 'center' });
    px += w + 0.08;
  });
  code(s, 'data/services/firebase/firebase_auth_service.dart · routing/router.dart', RX, 6.42, RW);
}

// 7. Firestore and Rules
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 2 / 7 · CLOUD FIRESTORE VÀ SECURITY RULES', 'firestore',
    'Dữ liệu nằm ở Firestore; quy tắc chạy trên máy chủ quyết định ai được đọc, ai được ghi',
    'Firestore là cơ sở dữ liệu NoSQL trên máy chủ Google; SDK trong app nói chuyện trực tiếp với nó, không qua server của nhóm. '
    + 'Màn hình lắng nghe bằng snapshots(), nên khi bếp báo hết món thì app khách thấy ngay. '
    + 'Mỗi yêu cầu đi qua Security Rules (firebase/firestore.rules) trên máy chủ: mặc định từ chối; khách chỉ đọc ghi dữ liệu của mình (request.auth.uid); nhân viên chỉ làm ở kiosk của mình. 88 test rules chạy trên Emulator. '
    + 'Đặt đơn chạy trong transaction: đọc kiosk (còn nhận đơn không), mã giảm giá và suất giờ nhận, rồi mới ghi đơn và trừ suất; sửa và huỷ đơn cũng vậy, nên hai người cùng sửa không ghi đè nhau. '
    + 'Truy vấn lọc nhiều trường cần index tổng hợp: Emulator không đòi, Firestore thật thì báo lỗi, nên đã thêm 16 index. '
    + 'Hạn chế đã biết (CR-01): giá trong đơn do app gửi, Rules mới kiểm giá > 0, chưa đối chiếu với thực đơn.');
  seq(s, {
    x: LX, y: TOP, w: LW,
    actors: [{ key: 'c', label: 'App khách' }, { key: 'fs', label: 'Firestore + Rules' }, { key: 'k', label: 'App bếp' }],
    msgs: [
      { from: 'c', to: 'fs', text: 'Theo dõi thực đơn của kiosk (snapshots())' },
      { from: 'fs', to: 'fs', text: 'Rules kiểm tra từng yêu cầu: mặc định từ chối; chỉ chủ dữ liệu hoặc nhân viên kiosk đó được phép' },
      { from: 'k', to: 'fs', text: 'Nhân viên báo món hết' },
      { from: 'fs', to: 'c', text: 'Báo ngay cho app khách: món đã hết' },
      { from: 'c', to: 'fs', text: 'Đặt đơn bằng transaction: đọc kiosk, mã giảm giá, giờ nhận rồi mới ghi' },
    ],
  });
  failure(s, 'Bị từ chối hoặc mất mạng: màn hình báo lỗi, có nút Thử lại; khi mất mạng app đọc dữ liệu đã lưu trên máy. Hai nhân viên cùng xử lý một đơn: người sau thấy “Đơn này vừa được xử lý ở nơi khác.”', LX, 5.92, LW, 0.95);
  const tw = (RW - 0.25) / 2;
  card(s, RX, TOP, tw, 1.55);
  stat(s, '88', 'test kiểm tra Rules, chạy trên Emulator', RX + 0.2, TOP + 0.05, tw - 0.3, { size: 40, bigH: 0.7, labelH: 0.6 });
  card(s, RX + tw + 0.25, TOP, tw, 1.55);
  stat(s, '16', 'index ghép; thiếu thì Firestore thật báo lỗi, Emulator thì không', RX + tw + 0.45, TOP + 0.05, tw - 0.3, { size: 40, bigH: 0.7, labelH: 0.75, labelSize: 12.5 });
  const h = shot(s, crop('firestore-reports.png'), RX, TOP + 1.85, RW, 1200 / 390, 'firestore-console');
  caption(s, 'Firestore console: tài liệu reports có uid, fileName, sizeKb và url Cloudinary', RX, TOP + 1.85 + h + 0.06, RW, { h: 0.45 });
  code(s, 'firebase/firestore.rules · firebase/tests/ · data/repositories/firestore/', RX, 6.42, RW);
}

// 8. File upload (Cloudinary)
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 3 / 7 · TẢI TỆP LÊN (CLOUDINARY THAY CLOUD STORAGE)', 'upload',
    'Biên nhận PDF được tải lên Cloudinary; trong app không có khoá bí mật nào',
    'Cloud Storage for Firebase cần gói Blaze (thẻ thanh toán); thầy đã đồng ý dùng Cloudinary hoặc S3. '
    + 'App tạo biên nhận PDF trên máy, gửi HTTP multipart tới api.cloudinary.com/v1_1/<cloud>/auto/upload kèm upload preset không ký, thư mục breakbite/reports/{uid}. '
    + 'Preset không ký nghĩa là app không giữ khoá bí mật nào; nếu để khoá trong app thì ai tải app cũng lấy được. Giới hạn (loại tệp, dung lượng) đặt trong cấu hình preset. '
    + 'Cloudinary trả URL; app lưu uid, tên tệp, URL, dung lượng vào Firestore reports, và Rules chỉ cho chủ sở hữu đọc. '
    + 'StorageService là interface: muốn đổi sang S3 thì viết một lớp mới, không sửa màn hình. Giới hạn 5 MB, chờ tối đa 60 giây.');
  seq(s, {
    x: LX, y: TOP, w: LW,
    actors: [{ key: 'app', label: 'App BreakBite' }, { key: 'cl', label: 'Cloudinary' }, { key: 'fs', label: 'Firestore' }],
    msgs: [
      { from: 'app', to: 'app', text: 'Tạo biên nhận PDF ngay trên điện thoại' },
      { from: 'app', to: 'cl', text: 'Gửi tệp vào thư mục breakbite/reports/{uid}, kèm upload preset (app hiện % tiến độ)' },
      { from: 'cl', to: 'app', text: 'Trả về đường link của tệp' },
      { from: 'app', to: 'fs', text: 'Lưu vào reports: uid, tên tệp, link, dung lượng' },
      { from: 'fs', to: 'fs', text: 'Rules: chỉ người tạo đọc được bản ghi này' },
    ],
  });
  failure(s, 'Chưa cấu hình, tệp quá 5 MB, mất mạng, hoặc chờ quá 60 giây: app báo đúng lỗi đó và vẫn cho bấm Thử lại.', LX, 5.92, LW, 0.95);
  const ph = 3.85;
  const w = phone(s, ev('storage', '2-url.png'), RX, TOP, ph, 'upload-done');
  caption(s, 'Tải xong, hiện URL', RX, TOP + ph + 0.06, w, { align: 'center' });
  const cx = RX + w + 0.3;
  const cw = RIGHT - cx;
  const h = shot(s, crop('cloudinary-library.png'), cx, TOP, cw, 1238 / 520, 'cloudinary-library');
  caption(s, 'Cloudinary: tệp PDF trong breakbite/reports/{uid}', cx, TOP + h + 0.06, cw, { h: 0.45 });
  s.addText([
    { text: 'Vì sao dùng Cloudinary\n', options: { bold: true, color: C.text2, fontSize: 14 } },
    { text: 'Cloud Storage cần gói Blaze trả phí; thầy đã đồng ý cho dùng Cloudinary hoặc S3. Upload preset “unsigned” giữ các giới hạn ở phía Cloudinary, nên app không cần khoá bí mật.', options: { fontSize: 13, color: C.text1 } },
  ], { isTextBox: true, shape: S.roundRect, rectRadius: 0.08, x: cx, y: TOP + h + 0.55, w: cw, h: ph - h - 0.55, valign: 'top', fill: { color: C.background2 }, line: { color: C.accent6, width: 0.75 }, margin: [10, 10, 7, 7] });
  code(s, 'data/services/cloudinary/cloudinary_storage_service.dart', RX, 6.42, RW);
}

// 9. FCM
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 4 / 7 · FIREBASE CLOUD MESSAGING', 'fcm',
    'Mỗi máy cài app có một token FCM riêng; bên gửi dùng token đó để gửi thông báo tới máy',
    'Token FCM là chuỗi định danh một bản cài app trên một thiết bị. Dịch vụ FCM của Google cấp nó qua Google Play Services khi app gọi getToken(); token có thể đổi (cài lại app, xoá dữ liệu) nên app nghe onTokenRefresh. '
    + 'Client có lưu: sau đăng nhập app ghi token vào users/{uid}.fcmTokens (tối đa 5 thiết bị) và gỡ khi đăng xuất, để bên gửi biết gửi tới đâu. '
    + 'Gửi tin: phải có một bên có quyền server gọi FCM HTTP v1 messages:send kèm token. Ở đây là Firebase Console, mục Send test message (dán token), hoặc script firebase/seed/send-push.mjs dùng Admin SDK đọc token trong Firestore rồi gửi; script đã viết nhưng chưa chạy với FCM thật vì cần khoá tài khoản dịch vụ. '
    + 'Không có Cloud Functions vì gói Spark; hệ thống thật sẽ đặt đoạn gửi trên server, chạy khi bếp đổi trạng thái đơn. '
    + 'Nhận: app đang mở thì onMessage hiện banner trong app; chạy nền hoặc đã đóng thì hệ thống hiện thông báo; chạm vào thì onMessageOpenedApp hoặc getInitialMessage, rồi PushRouter mở đúng đơn. Mọi tin đều lưu vào users/{uid}/notifications (màn S19). '
    + 'Lỗi tìm được khi test: chạm thông báo lúc app đã đóng thì mở đơn rồi bị Trang chủ đè lên; đã sửa trong lib/app.dart (chờ router sẵn sàng).');
  seq(s, {
    x: LX, y: TOP, w: LW, rowH: 0.58,
    actors: [{ key: 'app', label: 'App trên điện thoại' }, { key: 'f', label: 'FCM (Google)' }, { key: 'snd', label: 'Bên gửi' }],
    msgs: [
      { from: 'app', to: 'f', text: 'Xin token (getToken) sau khi đăng nhập' },
      { from: 'f', to: 'app', text: 'Trả token riêng cho máy này' },
      { from: 'app', to: 'app', text: 'Lưu token vào users/{uid}.fcmTokens (tối đa 5 máy); xoá khi đăng xuất' },
      { from: 'snd', to: 'snd', text: 'Bên gửi lấy token: dán vào Firebase Console,\nhoặc script send-push.mjs đọc từ Firestore' },
      { from: 'snd', to: 'f', text: 'Gửi tới FCM: token, tiêu đề, nội dung, orderId' },
      { from: 'f', to: 'app', text: 'App đang mở: hiện trong app; app chạy nền hoặc đã tắt: hiện ở thanh thông báo' },
    ],
  });
  failure(s, 'Người dùng không cấp quyền (Android 13+): app vẫn chạy, chỉ không hiện thông báo. Lưu token bị lỗi cũng không chặn đăng nhập hay đăng xuất.', LX, 6.3, LW, 0.6);
  const ph = 3.85;
  const shots = [['2-foreground.png', 'Đang mở: hiện trong app'], ['3-background.png', 'Chạy nền: thanh thông báo'], ['4-terminated-tap-after-fix.png', 'Đã tắt: chạm mở đúng đơn']];
  let px = RX;
  shots.forEach((p, i) => {
    const w = phone(s, ev('fcm', p[0]), px, TOP, ph, `fcm-${i + 1}`);
    caption(s, p[1], px - 0.05, TOP + ph + 0.06, w + 0.1, { align: 'center' });
    px += w + 0.08;
  });
  code(s, 'data/services/firebase/firebase_messaging_service.dart · routing/push_router.dart · firebase/seed/send-push.mjs', RX, 6.38, RW);
}

// 10. Analytics
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 5 / 7 · GOOGLE ANALYTICS FOR FIREBASE', 'analytics',
    'App ghi 11 sự kiện theo kế hoạch, và cả 11 đều hiện trong DebugView',
    'Kế hoạch docs/analytics-plan.md viết trước khi code: 11 sự kiện, mỗi sự kiện trả lời một câu hỏi sản phẩm và gắn với một bước của luồng Lab 2; purchase dùng để kiểm mục tiêu dưới 35 giây và 8 lần chạm. '
    + 'App gọi logEvent qua AnalyticsService (màn hình không gọi SDK). SDK gom sự kiện trên máy và gửi theo lô nên báo cáo thường chậm. '
    + 'Muốn thấy ngay thì bật chế độ debug: adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite, sự kiện hiện trong DebugView sau vài giây. '
    + 'setUserId(uid) sau khi đăng nhập; tham số không chứa tên hay e-mail. reorder có ghi trong code nhưng không nằm trong bảng kế hoạch.');
  seq(s, {
    x: LX, y: TOP, w: LW,
    actors: [{ key: 'app', label: 'App (AnalyticsService)' }, { key: 'sdk', label: 'Analytics SDK' }, { key: 'fb', label: 'Firebase' }],
    msgs: [
      { from: 'app', to: 'sdk', text: 'Ghi sự kiện: logEvent(tên, tham số); sau khi đăng nhập gọi setUserId(uid)' },
      { from: 'sdk', to: 'sdk', text: 'SDK giữ sự kiện trên máy' },
      { from: 'sdk', to: 'fb', text: 'Gửi theo lô, nên báo cáo hiện chậm' },
      { from: 'sdk', to: 'fb', text: 'Bật debug mode: gửi ngay, vài giây sau thấy trong DebugView' },
    ],
  });
  text(s, [
    { text: 'Viết kế hoạch trước khi code. ', options: { bold: true, color: C.text2 } },
    { text: 'Mỗi sự kiện trả lời một câu hỏi, ví dụ purchase cho biết có đạt mục tiêu 35 giây, 8 lần chạm không. Không ghi tên hay e-mail.' },
  ], { x: LX, y: 5.2, w: LW, h: 0.8, fontSize: 13.5 });
  failure(s, 'Ghi sự kiện bị lỗi thì AnalyticsService bắt lỗi đó; người dùng vẫn dùng app bình thường.', LX, 6.1, LW, 0.75);
  const dh = 4.0;
  const dw = dh * 660 / 680;
  shot(s, crop('debugview.png'), RX, TOP, dw, 660 / 680, 'debugview');
  caption(s, 'DebugView bật debug mode: dòng sự kiện và top events', RX, TOP + dh + 0.06, dw + 0.3);
  const lx = RX + dw + 0.25;
  const lw = RIGHT - lx;
  text(s, 'ĐÃ THẤY TRONG DEBUGVIEW', { x: lx, y: TOP, w: lw, h: 0.3, fontSize: 11, bold: true, charSpacing: 1, color: C.accent2 });
  const events = ['login', 'logout', 'search', 'view_menu_item', 'add_to_cart', 'begin_checkout', 'purchase', 'payment_failed', 'export_report', 'order_accepted', 'order_delivered'];
  events.forEach((e, i) => {
    const y = TOP + 0.38 + i * 0.31;
    s.addImage({ path: icon('check', 'o'), x: lx, y: y + 0.05, w: 0.2, h: 0.2 });
    text(s, e, { x: lx + 0.27, y, w: lw - 0.27, h: 0.3, fontSize: 12.5, color: C.text1, valign: 'middle' });
  });
  caption(s, '+ reorder (có ghi, không nằm trong kế hoạch)', lx, TOP + 0.42 + 11 * 0.31, lw, { h: 0.45 });
  code(s, 'data/services/firebase/firebase_analytics_service.dart', RX, 6.55, RW);
}

// 11. Crashlytics
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 6 / 7 · FIREBASE CRASHLYTICS', 'crash',
    'Khi app lỗi, Crashlytics lưu báo cáo trên máy và gửi lên khi app mở lại',
    'Khi app sập, SDK ghi báo cáo vào bộ nhớ máy và chỉ gửi ở lần mở app kế tiếp, nên Console cập nhật chậm sau một crash. '
    + 'Lỗi Flutter chưa bắt được thu qua FlutterError.onError và PlatformDispatcher.onError (lib/config/firebase_setup.dart), ghi là fatal. '
    + 'Lỗi đã bắt nhưng đáng ghi thì gọi recordNonFatal kèm lý do, ví dụ auth.signInWithGoogle, push.opened. Ảnh trên cùng là một non-fatal thật: Firestore permission-denied trong một stream. '
    + 'Mỗi báo cáo có uid (setUserIdentifier) và hai khoá role, kiosk_id. Nút Ghi lỗi thử và Làm sập app thử nằm trong Khu demo Firebase, có hỏi xác nhận trước khi crash.');
  seq(s, {
    x: LX, y: TOP, w: LW, rowH: 0.66,
    actors: [{ key: 'app', label: 'App Flutter' }, { key: 'sdk', label: 'Crashlytics SDK' }, { key: 'con', label: 'Crashlytics console' }],
    msgs: [
      { from: 'app', to: 'sdk', text: 'Lỗi không ai bắt (FlutterError.onError, PlatformDispatcher.onError): ghi là fatal' },
      { from: 'app', to: 'sdk', text: 'Lỗi app đã bắt, ví dụ đăng nhập thất bại: recordNonFatal(...)' },
      { from: 'sdk', to: 'sdk', text: 'Lưu báo cáo trên máy, kèm uid và hai khoá role, kiosk_id' },
      { from: 'sdk', to: 'con', text: 'Lần mở app sau mới gửi lên; console gom lỗi giống nhau thành một issue' },
    ],
  });
  failure(s, 'Crashlytics chỉ ghi lại lỗi, không đổi màn hình: người dùng vẫn thấy thông báo lỗi như thường. Nút làm sập app thử nằm trong Khu demo Firebase và phải xác nhận trước.', LX, 5.55, LW, 0.95);
  let y = TOP;
  const items = [
    ['crash-nonfatal.png', 1120 / 213, 'Lỗi không làm sập app: Firestore từ chối quyền (lỗi thật) và lỗi demo'],
    ['crash-fatal.png', 1120 / 130, 'Lỗi làm sập app: crash thử'],
    ['crash-keys.png', 1092 / 260, 'Thông tin kèm theo: kiosk_id = q9-t2, role = user'],
  ];
  items.forEach((it, i) => {
    const h = shot(s, crop(it[0]), RX, y, RW, it[1], `crashlytics-${i + 1}`);
    caption(s, it[2], RX, y + h + 0.05, RW);
    y += h + 0.45;
  });
  code(s, 'data/services/firebase/firebase_crash_service.dart · config/firebase_setup.dart', RX, 6.42, RW);
}

// 12. Remote Config
{
  const s = slide('Dịch vụ đám mây', 'CONTENT', 'DỊCH VỤ ĐÁM MÂY 7 / 7 · FIREBASE REMOTE CONFIG', 'config',
    'Đổi giá trị trên Firebase console là Trang chủ đổi theo, không cần cài lại app',
    'Giá trị nằm trên server Remote Config; app có giá trị mặc định (RemoteKeys.defaults, khớp firebase/remote-config-defaults.json): quick_items_limit 5, promo_banner_enabled true, pickup_slot_enabled true. '
    + 'App fetch giá trị mới tối đa mỗi giờ một lần (0 khi debug), chờ tối đa 10 giây, rồi activate để dùng. '
    + 'onConfigUpdated là kênh thời gian thực: khi bấm Publish trên Console, server báo cho app, app activate và Trang chủ vẽ lại ngay, không cần build hay khởi động lại. '
    + 'Ảnh: trước là giá trị mặc định (có banner Giờ Vàng, 5 món nhanh); sau khi publish quick_items_limit = 2 và promo_banner_enabled = false thì Trang chủ còn 2 món, mất banner. '
    + 'Mất mạng: dùng giá trị activate lần cuối, hoặc mặc định ở lần mở đầu tiên.');
  seq(s, {
    x: LX, y: TOP, w: LW, rowH: 0.66,
    actors: [{ key: 'app', label: 'App BreakBite' }, { key: 'rc', label: 'Remote Config' }, { key: 'con', label: 'Firebase console' }],
    msgs: [
      { from: 'app', to: 'app', text: 'Giá trị mặc định có sẵn trong app: quick_items_limit = 5, banner và chọn giờ nhận đều bật' },
      { from: 'app', to: 'rc', text: 'Tải giá trị mới (fetch) tối đa 1 lần mỗi giờ, rồi áp dụng (activate)' },
      { from: 'con', to: 'rc', text: 'Đặt quick_items_limit = 2, tắt banner, bấm Publish' },
      { from: 'rc', to: 'app', text: 'Báo ngay cho app (onConfigUpdated); app áp dụng, Trang chủ đổi theo' },
    ],
  });
  failure(s, 'Mất mạng hoặc tải lỗi: app dùng giá trị lần trước; lần mở app đầu tiên thì dùng giá trị mặc định.', LX, 5.55, LW, 0.95);
  const ih = 2.5;
  const iw = ih * 1080 / 1320;
  const gap = RW - 2 * iw;
  shot(s, crop('rc-before.png'), RX, TOP, iw, 1080 / 1320, 'rc-before');
  s.addShape(S.rightArrow, { x: RX + iw + gap / 2 - 0.3, y: TOP + ih / 2 - 0.17, w: 0.6, h: 0.34, fill: { color: C.accent1 }, line: { type: 'none' } });
  shot(s, crop('rc-after.png'), RX + iw + gap, TOP, iw, 1080 / 1320, 'rc-after');
  caption(s, 'Trước: mặc định, có banner, 5 món', RX, TOP + ih + 0.06, iw + 0.5);
  caption(s, 'Sau khi publish: không banner, 2 món', RX + iw + gap - 0.6, TOP + ih + 0.06, iw + 0.6, { align: 'right' });
  const cy = TOP + ih + 0.5;
  const h = shot(s, crop('rc-console.png'), RX, cy, RW, 1122 / 230, 'rc-console');
  caption(s, 'Firebase console: các giá trị vừa đổi (“Just now”)', RX, cy + h + 0.05, RW);
  code(s, 'data/services/firebase/firebase_remote_config_service.dart', RX, 6.62, RW);
}

// 13. ARTEMIS
pres.addSection({ title: 'Bằng chứng' });
{
  const s = slide('Bằng chứng', 'CONTENT', 'BẰNG CHỨNG · KIỂM THỬ ĐẦU CUỐI BẰNG GOOGLE ARTEMIS', 'bot',
    'ARTEMIS chạy 11 ca kiểm thử, mỗi ca 3 lần, đều đạt 3/3; khi chạy đã tìm ra một lỗi app và sửa xong',
    'ARTEMIS là agent AI điều khiển máy Android từ câu lệnh tiếng tự nhiên. Chạy hồ sơ Flash, model Gemini 3.5 Flash Lite, trên máy ảo với project Firebase thật; commit ARTEMIS được ghim trong README. '
    + 'Mỗi test là một hàm pytest gửi một chỉ dẫn: điểm bắt đầu, các bước, và điều phải thấy cuối cùng. Agent trả về các giá trị nó đọc được dạng JSON, test so sánh các giá trị đó, không chỉ xem trạng thái SUCCESS. '
    + '11 ca được chấm, mỗi ca 3 lần chạy chính thức, đều đạt 3/3. Riêng TC-05 còn một lần chạy nữa (run-21) bị hỏng vì máy đang chạy cả bộ flutter test cùng lúc nên app bị ANR; lần đó không phải lỗi app và vẫn ghi trong docs/test-plan.md mục 3. Nếu thầy hỏi thì nói rõ: tổng cộng TC-05 chạy 4 lần, đạt 3. '
    + 'Các lần hỏng trước đó đều tìm ra nguyên nhân: câu chỉ dẫn mơ hồ (TC-03, TC-10), ARTEMIS dán chữ bằng KEYCODE_PASTE mà ô nhập Flutter bỏ qua (TC-04, đã vá), và lỗi thật của app P-01 (TC-05), đã sửa. '
    + 'Phiên khám phá hồ sơ Pro 15,8 phút, 57 bước, tìm được một lỗi mức trung bình: xuất được biên nhận cho đơn đã huỷ.');
  const rows = [
    ['TC-01', 'Đăng nhập qua hộp chọn tài khoản Google (native)', '3', '3/3'],
    ['TC-02', 'Đăng xuất; nút Back không quay lại Trang chủ', '3', '3/3'],
    ['TC-03', 'F1 đặt nhanh + sự kiện purchase trong Logcat', '3', '3/3'],
    ['TC-04', 'F2 mã BB20 hết hạn (nhánh lỗi)', '3', '3/3'],
    ['TC-05', 'F3 thanh toán bị từ chối, chuyển tiền mặt *', '3', '3/3'],
    ['TC-06', 'Tìm kiếm không có kết quả (nhánh lỗi)', '3', '3/3'],
    ['TC-07', 'Bấm từng tab, mở đúng màn hình', '3', '3/3'],
    ['TC-08', 'Chi tiết món và chi tiết đơn', '3', '3/3'],
    ['TC-09', 'Xuất và tải lên biên nhận', '3', '3/3'],
    ['TC-10', 'Giá trị Remote Config trên Trang chủ', '3', '3/3'],
    ['TC-12', 'Bếp: nhận, làm, quét mã, giao đơn', '3', '3/3'],
  ].map((r, i) => r.map((t, j) => ({
    text: t,
    options: cellOpts({
      bold: j === 0 || j === 3, align: j >= 2 ? 'center' : 'left', fontSize: 12.5,
      color: j === 3 ? (t === '3/3' ? C.accent3 : C.accent2) : C.text1,
      fill: { color: i % 2 ? C.background2 : C.background1 },
    }),
  })));
  rows.unshift([hdr('Ca'), hdr('Kiểm tra gì'), hdr('Số lần chạy', { align: 'center' }), hdr('Đạt', { align: 'center' })]);
  s.addTable(rows, { x: MX, y: TOP, w: 7.3, colW: [0.85, 4.55, 1.05, 0.85], rowH: 0.34, border: { type: 'solid', pt: 0.75, color: C.accent6 }, margin: [0, 0.1, 0, 0.1] });
  caption(s, '* TC-05 còn 1 lần chạy nữa (run-21) bị hỏng vì máy đang chạy flutter test cùng lúc nên app bị ANR, không phải lỗi app. Trước khi sửa, các lần hỏng là do câu yêu cầu chưa rõ (TC-03, TC-10), ARTEMIS gõ chữ lỗi (TC-04) và lỗi app P-01 (TC-05). Chi tiết: docs/test-plan.md §3, evidence/artemis/run-*.xml.', MX, 6.2, 7.3, { h: 0.7 });
  const cx = 8.25;
  const cw = RIGHT - cx;
  const cards = [
    ['test', 'Cách chấm một test', 'pytest gửi cho agent một yêu cầu bằng lời: bắt đầu ở đâu, làm gì, cuối cùng phải thấy gì. Agent trả lại những gì nó đọc được trên màn hình (JSON); test so từng giá trị, không chỉ xem chữ SUCCESS.', 1.85],
    ['alert', 'Lỗi app tìm được và đã sửa (P-01)', 'Thanh toán bị từ chối, khách chọn trả tiền mặt: đơn đã tạo nhưng màn hình vẫn đứng ở trang lỗi. Đã sửa trong CheckoutScreen._confirm.', 1.45],
    ['bot', 'Chạy thử tự do 15,8 phút (hồ sơ Pro)', 'Agent tự đi 57 bước, tìm được 1 lỗi chưa sửa: đơn đã huỷ vẫn xuất được biên nhận.', 1.15],
  ];
  let y = TOP;
  cards.forEach((c) => {
    card(s, cx, y, cw, c[3]);
    s.addShape(S.ellipse, { x: cx + 0.18, y: y + 0.17, w: 0.38, h: 0.38, fill: { color: C.accent1 }, line: { type: 'none' } });
    s.addImage({ path: icon(c[0], 'w'), x: cx + 0.26, y: y + 0.25, w: 0.22, h: 0.22 });
    text(s, c[1], { x: cx + 0.68, y: y + 0.16, w: cw - 0.85, h: 0.4, fontSize: 14.5, bold: true, color: C.text2, valign: 'middle' });
    text(s, c[2], { x: cx + 0.68, y: y + 0.58, w: cw - 0.85, h: c[3] - 0.68, fontSize: 13 });
    y += c[3] + 0.2;
  });
}

// 14. AI code review
{
  const s = slide('Bằng chứng', 'CONTENT', 'BẰNG CHỨNG · REVIEW CODE BẰNG AI', 'review',
    'AI review code tìm ra 10 vấn đề: nhóm sửa 5, ghi nhận 1, bác 4 kèm lý do',
    'Công cụ: Claude Code, lệnh /code-review, chạy trên pull request để phát hiện chỉ đúng dòng. Đầu ra gốc lưu ở evidence/code-review/. '
    + 'Mỗi phát hiện đều mở code ra đọc trước khi quyết định vì công cụ có thể sai: CR-10 nói mô tả không được trim nhưng repository có trim. '
    + 'Năm lỗi được sửa, mỗi lỗi một commit có mã CR và có test; test mới hỏng trên code cũ và qua trên code mới (CR-05 đã chạy cả hai chiều). '
    + 'CR-01 được chấp nhận nhưng chưa sửa: muốn sửa phải đọc giá từng món trong transaction đặt đơn và thêm kiểm tra trong Rules, đụng vào luồng F1, F2 của thành viên khác sát hạn nộp, nên ghi là hạn chế đã biết. '
    + 'Bốn phát hiện bị bác, mỗi cái có lý do dựa trên Rules, trạng thái nút hoặc số lần đọc thật.');
  const data = [
    ['CR-01', 'bảo mật', 'firestore_order_repository.dart:52', 'Tổng tiền dùng giá do app gửi lên', 'Đồng ý, ghi là hạn chế', '—'],
    ['CR-02', 'lỗi', 'firestore_menu_repository.dart:91', 'Thêm món mới có thể ghi đè món khác', 'Đã sửa', 'd6d8113'],
    ['CR-03', 'lỗi', 'firestore_incident_repository.dart:98', 'Một sự cố có thể bị xử lý hai lần', 'Đã sửa (transaction)', 'd1291a6'],
    ['CR-04', 'hiệu năng', 'firestore_notification_repository.dart:55', 'markAllRead lỗi khi quá 500 thông báo', 'Đã sửa (lô 400)', '9243bf3'],
    ['CR-05', 'lỗi', 'order_history_view_model.dart:98', '“Xem đơn cũ hơn” có thể thêm trang rỗng', 'Đã sửa (test hỏng ở bản cũ)', '2980559'],
    ['CR-06', 'lỗi', 'seller_menu_view_model.dart:41', 'Mốc “Có lại lúc” đầu tiên bỏ qua giây', 'Đã sửa', 'ba8dc33'],
    ['CR-07', 'lỗi', 'firestore_order_repository.dart:275', 'Trả suất giờ nhận mà không đọc trước', 'Bác: không suất nào bị xoá', '—'],
    ['CR-08', 'bảo trì', 'shop_view_model.dart:134', 'Lệnh ghi bị bỏ qua mà vẫn báo thành công', 'Bác: nút đã khoá khi đang ghi', '—'],
    ['CR-09', 'hiệu năng', 'shift_stats_view_model.dart:116', 'K11 đọc mọi kiosk để lấy một giờ mở cửa', 'Bác: chỉ 2 kiosk, 2 lượt đọc', '—'],
    ['CR-10', 'thiếu test', 'incident_view_model.dart:128', 'Gửi báo cáo sự cố không kiểm trạng thái', 'Bác: AI đọc sai một phần', '—'],
  ];
  const rows = data.map((r, i) => r.map((t, j) => ({
    text: t,
    options: cellOpts({
      bold: j === 0, fontSize: j === 2 ? 10 : j >= 3 && j <= 4 ? 11.5 : 12, fontFace: j === 2 || j === 5 ? CODE_FONT : THEME.bodyFontFace,
      color: j === 4 ? (t.startsWith('Đã sửa') ? C.accent3 : t.startsWith('Bác') ? C.accent5 : C.accent2) : (j === 2 ? C.text2 : C.text1),      fill: { color: i % 2 ? C.background2 : C.background1 },
    }),
  })));
  rows.unshift([hdr('Mã'), hdr('Loại'), hdr('File:dòng'), hdr('Vấn đề AI nêu ra'), hdr('Nhóm quyết định'), hdr('Commit')]);
  s.addTable(rows, { x: MX, y: TOP, w: CW, colW: [0.75, 1.15, 3.62, 3.45, 2.28, 0.883], rowH: 0.4, border: { type: 'solid', pt: 0.75, color: C.accent6 }, margin: [0, 0.08, 0, 0.08] });
  caption(s, 'Công cụ: Claude Code /code-review trên một pull request · đầu ra gốc ở evidence/code-review/ · lý do từng mục ở docs/code-review.md', MX, 6.6, CW);
}

// 15. Lessons and links
{
  const s = slide('Bằng chứng', 'CLOSING', 'TỔNG KẾT · BÀI HỌC VÀ ĐƯỜNG DẪN', 'lesson',
    'Bài học: phải chạy trên Firebase thật và kiểm lại kết quả của AI mới thấy hết lỗi',
    'Bốn bài học. Một: chạy trên project thật sớm; thiếu index và lỗi chạm thông báo khi app đóng chỉ lộ ra ở đó. '
    + 'Hai: dữ liệu được bảo vệ bởi Rules trên server, không phải bởi giao diện. '
    + 'Ba: agent kiểm thử AI cần câu chỉ dẫn chính xác; phần lớn lần chạy hỏng là do câu chữ hoặc công cụ, không phải do app. '
    + 'Bốn: kết quả review AI là danh sách câu hỏi; 4/10 phát hiện sai khi đọc code. '
    + 'Bên phải là đường dẫn tới từng tài liệu trong repo, và công cụ AI đã dùng để làm slide này.');
  const lessons = [
    ['Chạy trên project thật từ sớm', 'Thiếu index và lỗi chạm thông báo khi app đã tắt chỉ lộ ra khi chạy với Firebase thật.'],
    ['Bảo vệ dữ liệu ở server, không ở màn hình', 'Rules và transaction giữ dữ liệu đúng; 88 test kiểm tra Rules.'],
    ['Viết yêu cầu cho agent test thật rõ', 'Phần lớn lần chạy hỏng là do câu yêu cầu chưa rõ hoặc do công cụ, không phải do app.'],
    ['Đọc lại code trước khi tin AI review', '4/10 vấn đề AI nêu ra là sai khi đọc kỹ code.'],
  ];
  lessons.forEach((l, i) => {
    const y = TOP + i * 1.18;
    s.addText(String(i + 1), { shape: S.ellipse, x: MX, y: y + 0.03, w: 0.46, h: 0.46, fontSize: 16, bold: true, align: 'center', valign: 'middle', color: C.text2, fill: { color: C.accent1 }, line: { type: 'none' }, margin: 0 });
    text(s, l[0], { x: MX + 0.65, y, w: 5.9, h: 0.4, fontSize: 17, bold: true, color: C.background1, valign: 'middle' });
    text(s, l[1], { x: MX + 0.65, y: y + 0.42, w: 5.9, h: 0.6, fontSize: 14, color: C.accent6 });
  });
  const lx = 7.55;
  const lw = RIGHT - lx;
  text(s, 'TÀI LIỆU TRONG REPO', { x: lx, y: TOP, w: lw, h: 0.3, fontSize: 11, bold: true, charSpacing: 1.5, color: C.accent1 });
  const links = [
    ['Truy vết, khác biệt', 'docs/design-traceability.md'],
    ['Kiến trúc, Firebase', 'docs/architecture.md\ndocs/firebase-design.md'],
    ['Kế hoạch Analytics', 'docs/analytics-plan.md'],
    ['Test và kết quả chạy', 'docs/test-plan.md · e2e_test/\nevidence/artemis/'],
    ['Review code', 'docs/code-review.md\nevidence/code-review/'],
    ['Báo cáo, video demo', 'report/Lab03_SE193905.pdf\nlink video trong README.md'],
  ].map((r) => r.map((t, j) => ({ text: t, options: { fontSize: j ? 12 : 13, color: j ? C.accent1 : C.background1, valign: 'middle', border: [{ type: 'none' }, { type: 'none' }, { type: 'solid', pt: 0.5, color: C.accent5 }, { type: 'none' }] } })));
  s.addTable(links, { x: lx, y: TOP + 0.38, w: lw, colW: [1.95, lw - 1.95], rowH: 0.46, margin: [0, 0.05, 0, 0.05] });
  text(s, 'CÔNG CỤ AI DÙNG ĐỂ LÀM SLIDE', { x: lx, y: 5.3, w: lw, h: 0.3, fontSize: 11, bold: true, charSpacing: 1.5, color: C.accent1 });
  text(s, 'Claude Code (Claude Opus 5.5) viết scripts/build_slides.js (pptxgenjs) và scripts/prepare_slide_images.py. Icon: Lucide (giấy phép ISC). Mọi ảnh chụp lấy từ evidence/.', { x: lx, y: 5.62, w: lw, h: 0.9, fontSize: 12.5, color: C.background1 });
  text(s, 'github.com/baonv0817/PRM393_Lab03_Group2', { x: lx, y: 6.6, w: lw, h: 0.3, fontSize: 12, color: C.accent6 });
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
