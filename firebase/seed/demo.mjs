// Nạp dữ liệu DEMO: lịch sử đơn hàng 2 tuần (để biểu đồ thống kê, "Mọi đơn hàng", doanh thu có số đẹp), vài đơn đang
// xử lý hôm nay, đánh giá, sự cố, thông báo, và tuỳ chọn món (size, topping, mức cay) cho các món đã có.
//
//   Emulator:  firebase emulators:exec --config ../firebase.json --only firestore --project demo-breakbite "node demo.mjs --verify"
//   Thật:      GOOGLE_APPLICATION_CREDENTIALS=<khoá ngoài repo> node demo.mjs --project=<id> --yes
//                [--customer-email=<email khách demo>] [--admin-email=<email admin>] [--days=14]
//
// An toàn để chạy lại: mọi tài liệu demo có id bắt đầu bằng `demo-` và ghi lại cùng id (không nhân đôi). Món chỉ bị
// đụng ở trường `optionGroups` (soldOut, giá, ảnh… do staff sửa vẫn giữ). Không đụng users, kiosks, slots, vouchers.
//   --clean   xoá mọi tài liệu `demo-*` của orders, reviews, incidents, announcements (tuỳ chọn món giữ nguyên).
// Chạy `node backup.mjs` trước khi ghi vào project thật.
import { connect } from './admin.mjs';
import { KIOSKS, OPTIONS, menuItemsFor } from './data.mjs';

const argv = process.argv.slice(2);
const arg = (name) => argv.find((a) => a.startsWith(`--${name}=`))?.split('=').slice(1).join('=');
const clean = argv.includes('--clean');
const verify = argv.includes('--verify');
const days = Number(arg('days') ?? 14);
const { admin, db, projectId, emulator } = connect(argv);
const { Timestamp, FieldPath } = admin.firestore;

const PREFIX = 'demo-';
const VN = 7 * 3600 * 1000;

// ---- Số ngẫu nhiên có hạt giống: chạy lại ra cùng dữ liệu ----
let state = 20261114;
function rand() {
  state = (state + 0x6d2b79f5) | 0;
  let t = Math.imul(state ^ (state >>> 15), 1 | state);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const int = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1));
const pick = (list) => list[Math.floor(rand() * list.length)];
const chance = (p) => rand() < p;
function weighted(pairs) {
  let r = rand() * pairs.reduce((a, [, w]) => a + w, 0);
  for (const [v, w] of pairs) if ((r -= w) <= 0) return v;
  return pairs[pairs.length - 1][0];
}

async function deleteDemo() {
  let n = 0;
  for (const name of ['orders', 'reviews', 'incidents', 'announcements']) {
    const snap = await db.collection(name).where(FieldPath.documentId(), '>=', PREFIX).where(FieldPath.documentId(), '<', 'demo.').get();
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const d of snap.docs.slice(i, i + 400)) batch.delete(d.ref);
      await batch.commit();
    }
    n += snap.size;
    console.log(`  ${name}: xoá ${snap.size} tài liệu demo`);
  }
  return n;
}

if (clean) {
  console.log(`Project ${projectId}${emulator ? ' (emulator)' : ''}: dọn dữ liệu demo`);
  await deleteDemo();
  process.exit(0);
}

// ---- Người dùng: khách demo thật (nếu có email) để điện thoại có lịch sử đơn ----
async function lookup(email) {
  if (!email || emulator) return null;
  const user = await admin.auth().getUserByEmail(email);
  return { uid: user.uid, name: user.displayName || email.split('@')[0] };
}
const realCustomer = await lookup(arg('customer-email'));
const realAdmin = await lookup(arg('admin-email'));

const CUSTOMERS = [
  'Nguyễn Minh Quân', 'Trần Thu Hà', 'Lê Hoàng Nam', 'Phạm Ngọc Anh', 'Võ Thanh Tùng', 'Đặng Khánh Linh',
  'Bùi Quốc Bảo', 'Hoàng Mai Chi', 'Ngô Đức Huy', 'Đỗ Thảo Vy', 'Dương Gia Hân', 'Lý Tuấn Kiệt',
].map((name, i) => ({ uid: `demo-user-${i + 1}`, name }));

const publicName = (full) => {
  const parts = full.trim().split(/\s+/);
  return `${parts[parts.length - 2] ?? parts[0]} ${parts[parts.length - 1][0]}.`;
};

// ---- 1. Tuỳ chọn cho món đã có (chỉ trường optionGroups) ----
async function applyOptions() {
  let touched = 0;
  for (const kiosk of KIOSKS) {
    for (const item of menuItemsFor(kiosk)) {
      if (!OPTIONS[item.dishId]) continue;
      const ref = db.doc(`menu_items/${item.id}`);
      if (!(await ref.get()).exists) continue;
      await ref.update({ optionGroups: OPTIONS[item.dishId], updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      touched++;
    }
  }
  return touched;
}

// ---- 2. Đơn hàng ----
const REJECT_REASONS = ['Hết nguyên liệu', 'Quầy sắp đóng cửa', 'Quá tải, không kịp làm', 'Đơn trùng'];
const NOTES = ['Không hành', 'Ít đá', 'Cho thêm ớt', 'Gói riêng giúp mình', 'Lấy lúc 10:40 nhé', 'Không cay'];
const BREAKS = [[10, 20], [10, 35], [12, 5], [12, 20], [12, 40], [15, 10]];
const BREAK_WEIGHTS = [4, 5, 5, 4, 3, 1];

function buildLine(menu) {
  const dish = pick(menu);
  const picked = [];
  let unit = dish.priceVnd;
  for (const g of dish.optionGroups ?? []) {
    let chosen = [];
    if (g.required) chosen = [pick(g.choices)];
    else if (chance(0.45)) chosen = g.maxChoices > 1 && chance(0.3) ? [...g.choices].sort(() => rand() - 0.5).slice(0, 2) : [pick(g.choices)];
    for (const c of chosen) {
      picked.push({ groupId: g.id, groupName: g.name, choiceId: c.id, name: c.name, extraVnd: c.extraVnd });
      unit += c.extraVnd;
    }
  }
  return {
    itemId: dish.id,
    name: dish.name,
    priceVnd: unit,
    quantity: chance(0.78) ? 1 : 2,
    note: chance(0.12) ? pick(NOTES) : '',
    ...(picked.length ? { options: picked } : {}),
  };
}

const ymd = (ms) => new Date(ms + VN).toISOString().slice(0, 10).replaceAll('-', '');
const code = () => Array.from({ length: 6 }, () => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[int(0, 31)]).join('');

function orderDoc({ id, kiosk, menu, customer, createdMs, status, active }) {
  const items = Array.from({ length: weighted([[1, 5], [2, 4], [3, 1]]) }, () => buildLine(menu))
    .filter((l, i, all) => all.findIndex((x) => x.itemId === l.itemId && JSON.stringify(x.options) === JSON.stringify(l.options)) === i);
  const subtotal = items.reduce((a, l) => a + l.priceVnd * l.quantity, 0);
  const voucher = subtotal >= 40000 && chance(0.25);
  const discount = voucher ? 10000 : 0;
  const method = weighted([['momo', 35], ['vnpay', 20], ['card', 10], ['cash', 35]]);
  const at = (ms) => Timestamp.fromMillis(ms);
  const prep = int(2, 8) * 60 + int(0, 50);
  const accepted = createdMs + int(40, 180) * 1000;
  const doc = {
    uid: customer.uid,
    customerName: customer.name,
    kioskId: kiosk.id,
    kioskName: kiosk.name,
    items,
    subtotalVnd: subtotal,
    discountVnd: discount,
    totalVnd: subtotal - discount,
    ...(voucher ? { voucherCode: 'BBSTUDENT' } : {}),
    paymentMethod: method,
    paymentStatus: method === 'cash' ? 'unpaid' : 'paid',
    status,
    pickupAt: at(createdMs + 15 * 60 * 1000),
    pickupCode: String(int(100000, 999999)),
    orderCode: code(),
    createdAt: at(createdMs),
    updatedAt: at(createdMs),
    demo: true,
  };
  if (chance(0.06)) doc.note = pick(NOTES);
  if (status === 'cancelled') {
    const byStaff = chance(0.6);
    const when = createdMs + int(60, 240) * 1000;
    Object.assign(doc, byStaff
      ? { cancelledBy: 'staff', cancelReason: pick(REJECT_REASONS) }
      : { cancelledBy: 'customer', cancelReason: pick(['Đổi ý', 'Đặt nhầm kiosk', 'Có việc đột xuất']) });
    doc.cancelledAt = at(when);
    doc.updatedAt = at(when);
  } else if (status !== 'pending') {
    doc.acceptedAt = at(accepted);
    doc.readyBy = at(accepted + prep * 1000 + 2 * 60 * 1000);
    doc.updatedAt = at(accepted);
    if (status === 'ready' || status === 'delivered') {
      doc.readyAt = at(accepted + prep * 1000);
      doc.prepSeconds = prep;
      doc.updatedAt = doc.readyAt;
    }
    if (status === 'delivered') {
      doc.deliveredAt = at(accepted + prep * 1000 + int(30, 240) * 1000);
      doc.updatedAt = doc.deliveredAt;
      doc.paymentStatus = 'paid';
    }
  }
  return doc;
}

function buildOrders(now) {
  const orders = [];
  const nowVn = new Date(now + VN);
  const todayStart = Date.UTC(nowVn.getUTCFullYear(), nowVn.getUTCMonth(), nowVn.getUTCDate()) - VN;
  for (const kiosk of KIOSKS.filter((k) => k.open)) {
    const menu = menuItemsFor(kiosk).filter((m) => !m.soldOut);
    const perDay = kiosk.id === 'q9-t2' ? [6, 11] : [3, 7];
    for (let back = days; back >= 0; back--) {
      const dayStart = todayStart - back * 86400000;
      const dow = new Date(dayStart + VN).getUTCDay();
      if (dow === 0 || dow === 6) continue;
      const count = back === 0 ? int(3, 5) : int(perDay[0], perDay[1]);
      for (let n = 0; n < count; n++) {
        const [h, m] = weighted(BREAKS.map((b, i) => [b, BREAK_WEIGHTS[i]]));
        const createdMs = dayStart + (h * 60 + m + int(-12, 6)) * 60000;
        if (createdMs > now - 35 * 60000) continue;
        const customer = realCustomer && chance(0.12) ? realCustomer : pick(CUSTOMERS);
        const status = chance(0.84) ? 'delivered' : 'cancelled';
        orders.push({ id: `${PREFIX}${kiosk.id}-${ymd(createdMs)}-${n + 1}`, doc: orderDoc({ id: '', kiosk, menu, customer, createdMs, status }) });
      }
    }
    // Đơn đang chạy hôm nay: để demo hàng chờ duyệt (W03, K01) và theo dõi đơn (S07).
    const live = kiosk.id === 'q9-t2' ? ['pending', 'pending', 'pending', 'preparing', 'preparing', 'ready'] : ['pending', 'pending', 'preparing'];
    live.forEach((status, i) => {
      const createdMs = now - (live.length - i) * 90000 - int(0, 60000);
      const customer = realCustomer && i === 0 ? realCustomer : pick(CUSTOMERS);
      orders.push({ id: `${PREFIX}${kiosk.id}-live-${i + 1}`, doc: orderDoc({ id: '', kiosk, menu, customer, createdMs, status }) });
    });
  }
  return orders;
}

// ---- 3. Đánh giá, sự cố, thông báo ----
const COMMENTS = {
  5: ['Món ngon, ra nhanh, đúng giờ nghỉ giải lao.', 'Rất ngon, sẽ đặt lại!', 'Đóng gói gọn, còn nóng khi nhận.', 'Giá sinh viên mà ngon bất ngờ.'],
  4: ['Ngon, hơi đông nên chờ một chút.', 'Ổn, vừa miệng.', 'Làm nhanh, hơi ít topping.'],
  3: ['Tạm được, mong nêm đậm vị hơn.', 'Bình thường, giao đúng giờ.'],
  2: ['Hơi nguội khi lấy.', 'Làm chậm hơn dự kiến.'],
  1: ['Thiếu món, mong kiosk kiểm tra lại.'],
};
const TAGS = ['tasty', 'fast', 'hot', 'wellPacked'];

function buildReviews(orders) {
  const out = [];
  for (const { id, doc } of orders) {
    if (doc.status !== 'delivered' || !doc.uid.startsWith('demo-user') || !chance(0.45)) continue;
    const line = pick(doc.items);
    const rating = weighted([[5, 55], [4, 25], [3, 12], [2, 5], [1, 3]]);
    const dishId = line.itemId.slice(doc.kioskId.length + 1);
    out.push({
      id: `${id}_${line.itemId}`,
      doc: {
        orderId: id,
        itemId: line.itemId,
        dishId,
        kioskId: doc.kioskId,
        uid: doc.uid,
        authorName: publicName(doc.customerName),
        rating,
        comment: chance(0.8) ? pick(COMMENTS[rating]) : '',
        tags: rating >= 4 ? [...TAGS].sort(() => rand() - 0.5).slice(0, int(1, 3)) : [],
        createdAt: Timestamp.fromMillis(doc.deliveredAt.toMillis() + int(10, 180) * 60000),
        demo: true,
      },
    });
  }
  return out;
}

function buildIncidents(orders) {
  const delivered = orders.filter((o) => o.doc.status === 'delivered' && o.doc.uid.startsWith('demo-user'));
  const specs = [
    ['missingItem', 'Thiếu một phần khoai chiên so với đơn.', 'resolved', 'refunded'],
    ['quality', 'Trà sữa nhạt, trân châu còn cứng.', 'resolved', 'rejected'],
    ['late', 'Đơn ra trễ hơn giờ hẹn khoảng 10 phút.', 'inProgress'],
    ['wrongItem', 'Mình đặt mì cay vừa nhưng nhận mì siêu cay.', 'open'],
    ['other', 'Túi đựng bị rách khi nhận.', 'open'],
  ];
  return specs.map(([type, description, status, resolution], i) => {
    const o = delivered[(i * 17 + 5) % delivered.length];
    const createdMs = o.doc.deliveredAt.toMillis() + 20 * 60000;
    const doc = {
      orderId: o.id, kioskId: o.doc.kioskId, uid: o.doc.uid, customerName: o.doc.customerName,
      type, description, status, createdAt: Timestamp.fromMillis(createdMs), updatedAt: Timestamp.fromMillis(createdMs), demo: true,
    };
    if (status === 'resolved') {
      doc.resolution = resolution;
      doc.handledBy = 'demo-staff';
      doc.resolvedAt = Timestamp.fromMillis(createdMs + 40 * 60000);
      doc.updatedAt = doc.resolvedAt;
      if (resolution === 'refunded') doc.refundVnd = Math.min(15000, o.doc.totalVnd);
      else doc.resolutionNote = 'Đã kiểm tra, món đúng công thức của quầy.';
    }
    return { id: o.id, doc };
  });
}

function buildAnnouncements(now) {
  const by = realAdmin?.uid ?? 'demo-admin';
  const at = (minutesAgo) => Timestamp.fromMillis(now - minutesAgo * 60000);
  return [
    ['demo-ann-1', { title: 'Combo Giờ Vàng giảm 15%', body: 'Từ 10:15 đến 10:30 mỗi ngày, nhập mã GIOVANG để giảm 15% (tối đa 15.000đ). Áp dụng mọi kiosk.', status: 'published', createdBy: by, publishedAt: at(60 * 20), createdAt: at(60 * 20), updatedAt: at(60 * 20) }],
    ['demo-ann-2', { title: 'Trà sữa có thêm topping mới', body: 'Kem cheese và pudding đã có ở Kiosk Q9 · Tầng 2. Chọn topping ngay khi thêm món vào giỏ.', status: 'published', kioskId: 'q9-t2', createdBy: by, publishedAt: at(60 * 5), createdAt: at(60 * 5), updatedAt: at(60 * 5) }],
    ['demo-ann-3', { title: 'Kiosk Tầng 4 mở thêm giờ nghỉ trưa', body: 'Từ tuần này Kiosk Q9 · Tầng 4 nhận đơn đến 13:30 để kịp giờ học chiều.', status: 'published', kioskId: 'q9-t4', createdBy: by, publishedAt: at(60 * 2), createdAt: at(60 * 2), updatedAt: at(60 * 2) }],
    ['demo-ann-4', { title: 'Nghỉ lễ 2/9 (đã qua)', body: 'Thông báo cũ, đã lưu trữ.', status: 'archived', createdBy: by, publishedAt: at(60 * 24 * 60), createdAt: at(60 * 24 * 60), updatedAt: at(60 * 24 * 50) }],
    ['demo-ann-5', { title: 'Khảo sát món mới (bản nháp)', body: 'Bạn muốn kiosk bán thêm món nào? Gửi ý kiến cho quản trị viên.', status: 'draft', createdBy: by, createdAt: at(30), updatedAt: at(30) }],
  ].map(([id, doc]) => ({ id, doc: { ...doc, demo: true } }));
}

async function writeAll(collection, entries) {
  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    for (const { id, doc } of entries.slice(i, i + 400)) batch.set(db.doc(`${collection}/${id}`), doc);
    await batch.commit();
  }
  return entries.length;
}

// ---- Chạy ----
const now = Date.now();
const touched = await applyOptions();
const orders = buildOrders(now);
const reviews = buildReviews(orders);
const incidents = buildIncidents(orders);
const announcements = buildAnnouncements(now);
const written = {
  options_on_menu_items: touched,
  orders: await writeAll('orders', orders),
  reviews: await writeAll('reviews', reviews),
  incidents: await writeAll('incidents', incidents),
  announcements: await writeAll('announcements', announcements),
};
console.log(`Project ${projectId}${emulator ? ' (emulator)' : ''}: đã ghi`, written);
const delivered = orders.filter((o) => o.doc.status === 'delivered');
console.log(`  ${delivered.length} đơn đã giao, doanh thu ${delivered.reduce((a, o) => a + o.doc.totalVnd, 0).toLocaleString('vi-VN')}đ, ` +
  `${orders.filter((o) => ['pending', 'preparing', 'ready'].includes(o.doc.status)).length} đơn đang chạy`);

if (verify) {
  const fail = (m) => { console.error(`VERIFY LỖI: ${m}`); process.exit(1); };
  const count = async (name) => (await db.collection(name).where(FieldPath.documentId(), '>=', PREFIX).where(FieldPath.documentId(), '<', 'demo.').count().get()).data().count;
  for (const [name, n] of [['orders', orders.length], ['reviews', reviews.length], ['incidents', incidents.length], ['announcements', announcements.length]]) {
    const got = await count(name);
    if (got !== n) fail(`${name}: cần ${n}, có ${got}`);
  }
  for (const { doc } of orders) {
    if (doc.totalVnd !== doc.subtotalVnd - doc.discountVnd) fail('tổng tiền không khớp');
    if (doc.subtotalVnd !== doc.items.reduce((a, l) => a + l.priceVnd * l.quantity, 0)) fail('subtotal không khớp các dòng');
    if (doc.status === 'delivered' && !(doc.deliveredAt && doc.readyAt && doc.acceptedAt)) fail('đơn đã giao thiếu mốc thời gian');
    if (doc.status === 'cancelled' && !doc.cancelReason) fail('đơn huỷ thiếu lý do');
    if (!/^[A-Z0-9]{6}$/.test(doc.orderCode)) fail('orderCode sai dạng');
  }
  if (new Set(orders.map((o) => o.id)).size !== orders.length) fail('id đơn trùng');
  const again = await writeAll('orders', orders);
  if ((await count('orders')) !== orders.length) fail(`chạy lần hai làm số đơn đổi (${again})`);
  await deleteDemo();
  for (const name of ['orders', 'reviews', 'incidents', 'announcements']) if ((await count(name)) !== 0) fail(`--clean còn sót ${name}`);
  console.log('VERIFY OK: đúng số lượng, tổng tiền khớp, ghi lại không nhân đôi, --clean dọn sạch.');
}
