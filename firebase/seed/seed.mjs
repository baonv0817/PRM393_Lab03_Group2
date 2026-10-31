// Nạp dữ liệu mẫu (kiosk, slot, món, voucher) theo docs/data-model.md mục 8.
//
//   Emulator:  npm run seed:emulator
//   Thật:      GOOGLE_APPLICATION_CREDENTIALS=<khoá ngoài repo> node seed.mjs --project=<id> --yes
//
// Mặc định KHÔNG ghi đè tài liệu đã có (nên không làm mất việc staff đã sửa như soldOut, booked).
// Thêm --overwrite để ghi đè tài liệu cùng id, hoặc --reset để xoá sạch bốn collection mẫu (kiosks và
// slots, menu_items, vouchers) rồi nạp lại. --reset không đụng users, orders, reviews, incidents.
// Tài khoản staff và admin gán bằng set-role.mjs.
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { connect } from './admin.mjs';
import { BREAK_STARTS, KIOSKS, SLOT_CAPACITY, SLOT_DAYS, SLOT_MINUTES, VOUCHERS, menuItemsFor } from './data.mjs';

const argv = process.argv.slice(2);
const reset = argv.includes('--reset');
const overwrite = argv.includes('--overwrite') || reset;
const verify = argv.includes('--verify');
const { admin, db, projectId, emulator } = connect(argv);
const { Timestamp, FieldValue } = admin.firestore;

const VN_OFFSET_HOURS = 7;

/** Ngày làm việc (T2–T6) từ hôm nay theo giờ Việt Nam, dạng {y, m, d}. */
export function workdays(now = new Date(), days = SLOT_DAYS) {
  const vn = new Date(now.getTime() + VN_OFFSET_HOURS * 3600 * 1000);
  const out = [];
  for (let i = 0; i < days; i++) {
    const day = new Date(Date.UTC(vn.getUTCFullYear(), vn.getUTCMonth(), vn.getUTCDate() + i));
    const dow = day.getUTCDay();
    if (dow !== 0 && dow !== 6) out.push({ y: day.getUTCFullYear(), m: day.getUTCMonth(), d: day.getUTCDate() });
  }
  return out;
}

const pad = (n) => String(n).padStart(2, '0');

function slotsFor() {
  const slots = [];
  for (const { y, m, d } of workdays()) {
    for (const hhmm of BREAK_STARTS) {
      const [h, min] = hhmm.split(':').map(Number);
      const startMs = Date.UTC(y, m, d, h - VN_OFFSET_HOURS, min);
      slots.push({
        id: `${y}${pad(m + 1)}${pad(d)}-${pad(h)}${pad(min)}`,
        startAt: Timestamp.fromMillis(startMs),
        endAt: Timestamp.fromMillis(startMs + SLOT_MINUTES * 60 * 1000),
        capacity: SLOT_CAPACITY,
        booked: 0,
      });
    }
  }
  return slots;
}

/** Ghi danh sách [ref, data]; trả về số tài liệu thực sự ghi. */
async function writeAll(entries) {
  let toWrite = entries;
  if (!overwrite) {
    const existing = await db.getAll(...entries.map(([ref]) => ref));
    toWrite = entries.filter((_, i) => !existing[i].exists);
  }
  for (let i = 0; i < toWrite.length; i += 400) {
    const batch = db.batch();
    for (const [ref, data] of toWrite.slice(i, i + 400)) batch.set(ref, data);
    await batch.commit();
  }
  return toWrite.length;
}

const now = FieldValue.serverTimestamp();
const kioskEntries = KIOSKS.map(({ id, ...k }) => [db.doc(`kiosks/${id}`), { ...k, createdAt: now, updatedAt: now }]);
const menuEntries = KIOSKS.flatMap((k) => menuItemsFor(k).map(({ id, ...m }) => [db.doc(`menu_items/${id}`), { ...m, createdAt: now, updatedAt: now }]));
const voucherEntries = VOUCHERS.map(({ code, expiresAt, ...v }) => [db.doc(`vouchers/${code}`), { ...v, expiresAt: Timestamp.fromDate(new Date(expiresAt)), createdAt: now, updatedAt: now }]);
const slotEntries = KIOSKS.filter((k) => k.open).flatMap((k) => slotsFor().map(({ id, ...s }) => [db.doc(`kiosks/${k.id}/slots/${id}`), { ...s, createdAt: now, updatedAt: now }]));

if (reset) {
  // recursiveDelete xoá cả subcollection slots của kiosk.
  for (const name of ['kiosks', 'menu_items', 'vouchers']) await db.recursiveDelete(db.collection(name));
  console.log('Đã xoá kiosks (kèm slots), menu_items, vouchers để nạp lại.');
}

const written = {
  kiosks: await writeAll(kioskEntries),
  menu_items: await writeAll(menuEntries),
  vouchers: await writeAll(voucherEntries),
  slots: await writeAll(slotEntries),
};
console.log(`Project ${projectId}${emulator ? ' (emulator)' : ''}: đã ghi`, written, overwrite ? '(ghi đè)' : '(bỏ qua tài liệu đã có)');

if (verify) {
  const expected = { kiosks: kioskEntries.length, menu_items: menuEntries.length, vouchers: voucherEntries.length, slots: slotEntries.length };
  const fail = (msg) => { console.error(`VERIFY LỖI: ${msg}`); process.exit(1); };

  const count = async (q) => (await q.count().get()).data().count;
  const actual = {
    kiosks: await count(db.collection('kiosks')),
    menu_items: await count(db.collection('menu_items')),
    vouchers: await count(db.collection('vouchers')),
    slots: await count(db.collectionGroup('slots')),
  };
  for (const k of Object.keys(expected)) if (actual[k] !== expected[k]) fail(`${k}: cần ${expected[k]}, có ${actual[k]}`);

  // Chạy lần hai không được ghi thêm gì (idempotent), trừ khi --overwrite.
  if (!overwrite) {
    const again = { kiosks: await writeAll(kioskEntries), menu_items: await writeAll(menuEntries), vouchers: await writeAll(voucherEntries), slots: await writeAll(slotEntries) };
    for (const [k, n] of Object.entries(again)) if (n !== 0) fail(`chạy lần hai vẫn ghi ${n} tài liệu ${k}`);
  }

  // Mọi món phải đúng dạng mà rules yêu cầu (tên không rỗng, giá > 0, kioskId có thật).
  const kioskIds = new Set(KIOSKS.map((k) => k.id));
  for (const doc of (await db.collection('menu_items').get()).docs) {
    const m = doc.data();
    if (!m.name || !(m.priceVnd > 0) || !(m.prepMinutes >= 0) || typeof m.soldOut !== 'boolean') fail(`món ${doc.id} sai dạng`);
    if (!kioskIds.has(m.kioskId)) fail(`món ${doc.id} trỏ tới kiosk không tồn tại`);
    if (!['food', 'drink', 'other'].includes(m.category)) fail(`món ${doc.id}: category ${m.category} không thuộc food/drink/other`);
    if (!m.dishId || doc.id !== `${m.kioskId}-${m.dishId}`) fail(`món ${doc.id}: id phải là {kioskId}-{dishId}`);
    if (!m.createdAt || !m.updatedAt) fail(`món ${doc.id} thiếu createdAt/updatedAt`);
    // Mỗi món phải có ảnh đóng gói trong app và file ảnh phải tồn tại trong repo.
    if (!m.imageUrl?.startsWith('assets/images/menu/')) fail(`món ${doc.id} thiếu imageUrl`);
    if (!existsSync(fileURLToPath(new URL(`../../${m.imageUrl}`, import.meta.url)))) fail(`món ${doc.id}: không có file ${m.imageUrl}`);
    if (m.searchName !== m.searchName.toLowerCase() || /[̀-ͯ]/.test(m.searchName.normalize('NFD'))) fail(`món ${doc.id} searchName còn dấu`);
  }
  if ((await db.collection('menu_items').where('soldOut', '==', true).get()).empty) fail('không có món hết hàng để thử S22');
  for (const doc of (await db.collection('vouchers').get()).docs) {
    const { discount: x } = doc.data();
    const fixed = x?.type === 'fixed' && Object.keys(x).sort().join() === 'amountVnd,type' && x.amountVnd > 0;
    const percent = x?.type === 'percent' && Object.keys(x).sort().join() === 'maxVnd,percent,type' && x.percent >= 1 && x.percent <= 100 && x.maxVnd > 0;
    if (!fixed && !percent) fail(`voucher ${doc.id}: discount phải đúng một trong hai dạng fixed/percent`);
  }
  if ((await db.doc('kiosks/nvh-t1').get()).data().open !== false) fail('nvh-t1 phải đóng cửa để thử S21');
  console.log('VERIFY ĐẠT:', actual);
}
