// Mỗi chi nhánh một thực đơn riêng, để demo thấy kiosk nào cũng có "gu" riêng:
//
//   Q9 · Tầng 2   Tacos và đồ ăn vặt: tacos FtaCode, bánh tráng, tacos bò/gà, khoai chiên, đồ uống
//   Q9 · Tầng 4   Mì và cơm: mọi món mì FtaCode, mì trộn, cơm gà, bánh mì, đồ uống
//   NVH · Tầng 1  Ăn nhẹ (kiosk đang đóng, mở lại sẽ có menu này): bánh mì, khoai chiên, bánh tráng, đồ uống
//
//   Xem trước:  node branch-menus.mjs --project=breakbite-1315b --yes --dry-run
//   Áp dụng:    node branch-menus.mjs --project=breakbite-1315b --yes
//   Trả lại:    node branch-menus.mjs --project=breakbite-1315b --yes --all   (mọi món FtaCode và món mẫu bán ở mọi kiosk)
//
// Chỉ đổi `archived` (và `soldOut` của tacos gà ở Tầng 2, để còn món "Tạm hết" cho demo): không xoá món, không đổi giá,
// ảnh hay tuỳ chọn. Chỉ đụng các món FtaCode (id `ftacode-*`) và 9 món mẫu; món khác của nhóm (ví dụ gà nướng) giữ nguyên.
// Chạy `node backup.mjs` trước khi ghi vào project thật. Chạy lại không đổi gì thêm.
//
// Lưu ý: migration `2026-11-t32-ftacode-menu` đặt MỌI kiosk có đủ danh mục FtaCode; chạy lại nó sẽ xoá khác biệt này.
import { connect } from './admin.mjs';

const argv = process.argv.slice(2);
const dryRun = argv.includes('--dry-run');
const everything = argv.includes('--all');
const { admin, db, projectId } = connect(argv);

const SAMPLE = ['tacos-bo', 'tacos-ga', 'mi-tron-ga', 'mi-tron-bo', 'com-ga', 'banh-mi', 'khoai-chien', 'tra-dao', 'tra-sua', 'cafe-sua'];
const DRINKS = ['tra-dao', 'tra-sua', 'cafe-sua'];
const TACOS = [
  'ftacode-c01', 'ftacode-c05', 'ftacode-c06', 'ftacode-c10', 'ftacode-special',
  'ftacode-banh-trang-muoi-tac', 'ftacode-banhtrang-sate-hanhphi',
];

const isNoodle = (dishId) => dishId.startsWith('ftacode-mi');

/** Món nào bán ở kiosk nào. */
const MENUS = {
  'q9-t2': (d) => TACOS.includes(d) || ['tacos-bo', 'tacos-ga', 'khoai-chien', ...DRINKS].includes(d),
  'q9-t4': (d) => isNoodle(d) || ['mi-tron-ga', 'mi-tron-bo', 'com-ga', 'banh-mi', ...DRINKS].includes(d),
  'nvh-t1': (d) => ['banh-mi', 'khoai-chien', 'ftacode-banh-trang-muoi-tac', 'ftacode-banhtrang-sate-hanhphi', ...DRINKS].includes(d),
};
/** Món "Tạm hết" có chủ ý để demo màn S22 (khớp dữ liệu mẫu gốc). */
const SOLD_OUT = { 'q9-t2': ['tacos-ga'] };

const managed = (dishId) => dishId.startsWith('ftacode-') || SAMPLE.includes(dishId);

const changes = [];
for (const kioskId of Object.keys(MENUS)) {
  const snap = await db.collection('menu_items').where('kioskId', '==', kioskId).get();
  for (const doc of snap.docs) {
    const m = doc.data();
    const dishId = doc.id.slice(kioskId.length + 1);
    if (!managed(dishId)) continue;
    const onSale = everything || MENUS[kioskId](dishId);
    const soldOut = onSale && (SOLD_OUT[kioskId] ?? []).includes(dishId);
    const patch = {};
    if (m.archived !== !onSale) patch.archived = !onSale;
    if (onSale && Boolean(m.soldOut) !== soldOut) patch.soldOut = soldOut;
    if (Object.keys(patch).length) changes.push({ ref: doc.ref, kioskId, name: m.name, patch });
  }
}

const per = {};
for (const c of changes) {
  per[c.kioskId] ??= { ban: 0, gỡ: 0, tạmHết: 0 };
  if (c.patch.archived === false) per[c.kioskId].ban++;
  if (c.patch.archived === true) per[c.kioskId].gỡ++;
  if (c.patch.soldOut === true) per[c.kioskId].tạmHết++;
}
console.log(`Project ${projectId}: ${changes.length} thay đổi`, per);
for (const c of changes) console.log(`  ${c.kioskId.padEnd(7)} ${c.patch.archived === true ? 'gỡ ' : c.patch.archived === false ? 'bán ' : 'hết '} ${c.name}`);

if (dryRun) {
  console.log('(--dry-run: chưa ghi gì)');
  process.exit(0);
}
for (let i = 0; i < changes.length; i += 400) {
  const batch = db.batch();
  for (const c of changes.slice(i, i + 400)) {
    batch.update(c.ref, { ...c.patch, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  }
  await batch.commit();
}
console.log('Đã ghi.');
