// Kiểm Security Rules bằng Firebase Emulator: với mỗi vai trò (user, staff, admin) và mỗi collection
// có ít nhất một ca được phép và một ca bị từ chối. Chạy: `npm test` trong thư mục này.
// Mô hình dữ liệu: docs/data-model.md.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc, Timestamp } from 'firebase/firestore';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-breakbite',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});

after(async () => {
  await env.cleanup();
});

const item = { itemId: 'm1', name: 'Combo Tacos', priceVnd: 39000, quantity: 1, note: '' };

// Đơn đầy đủ trường như app tạo (dữ liệu nạp thẳng, bỏ qua rules).
const seedOrder = (over) => ({
  uid: 'u1', customerName: 'Quân', kioskId: 'k1', kioskName: 'Kiosk Q9 · Tầng 2',
  items: [item], subtotalVnd: 39000, discountVnd: 0, totalVnd: 39000,
  paymentMethod: 'momo', paymentStatus: 'paid', status: 'pending', pickupCode: '482915',
  createdAt: Timestamp.now(), ...over,
});

// Đơn khách gửi lên (createdAt phải là serverTimestamp).
const newOrder = (over) => ({
  uid: 'u1', customerName: 'Quân', kioskId: 'k1', kioskName: 'Kiosk Q9 · Tầng 2',
  items: [item], subtotalVnd: 39000, discountVnd: 0, totalVnd: 39000,
  paymentMethod: 'momo', paymentStatus: 'paid', status: 'pending', pickupCode: '123456',
  createdAt: serverTimestamp(), ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/u1'), { role: 'user', displayName: 'Quân' });
    await setDoc(doc(db, 'users/u2'), { role: 'user', displayName: 'Linh' });
    await setDoc(doc(db, 'users/s1'), { role: 'staff', displayName: 'Hạnh', kioskId: 'k1' });
    await setDoc(doc(db, 'users/s2'), { role: 'staff', displayName: 'Nam', kioskId: 'k2' });
    await setDoc(doc(db, 'users/s0'), { role: 'staff', displayName: 'Chưa gán kiosk' });
    await setDoc(doc(db, 'users/a1'), { role: 'admin', displayName: 'Admin' });
    await setDoc(doc(db, 'kiosks/k1'), { name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 6 });
    await setDoc(doc(db, 'kiosks/k2'), { name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 10 });
    await setDoc(doc(db, 'kiosks/k3'), { name: 'Nhà văn hóa SV · Tầng 1', open: false, waitMinutes: 0 });
    await setDoc(doc(db, 'kiosks/k1/slots/sl1'), { capacity: 2, booked: 1 });
    await setDoc(doc(db, 'kiosks/k1/slots/sl2'), { capacity: 1, booked: 1 });
    await setDoc(doc(db, 'menu_items/m1'), { kioskId: 'k1', name: 'Combo Tacos', priceVnd: 39000, prepMinutes: 4, soldOut: false });
    await setDoc(doc(db, 'vouchers/BBSTUDENT'), { discountVnd: 10000, expiresAt: Timestamp.fromDate(new Date('2100-01-01')) });
    await setDoc(doc(db, 'orders/o1'), seedOrder({ paymentMethod: 'cash', paymentStatus: 'unpaid' }));
    await setDoc(doc(db, 'orders/o2'), seedOrder({ uid: 'u2', customerName: 'Linh' }));
    await setDoc(doc(db, 'orders/o3'), seedOrder({ status: 'preparing' }));
    await setDoc(doc(db, 'orders/o4'), seedOrder({ status: 'ready', paymentMethod: 'cash', paymentStatus: 'unpaid' }));
    await setDoc(doc(db, 'orders/o5'), seedOrder({ kioskId: 'k2', kioskName: 'Kiosk Q9 · Tầng 4' }));
    await setDoc(doc(db, 'orders/o6'), seedOrder({ status: 'delivered' }));
  });
});

const as = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());

describe('users', () => {
  test('user tạo hồ sơ của chính mình với role user: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u3'), 'users/u3'), { role: 'user', displayName: 'Mới' }));
  });
  test('user tự tạo hồ sơ với role staff: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u3'), 'users/u3'), { role: 'staff', displayName: 'Mới' }));
  });
  test('user tự gán kiosk khi tạo hồ sơ: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u3'), 'users/u3'), { role: 'user', displayName: 'Mới', kioskId: 'k1' }));
  });
  test('user tự đổi role hoặc kiosk của mình: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { role: 'admin' }));
    await assertFails(updateDoc(doc(as('s1'), 'users/s1'), { kioskId: 'k2' }));
  });
  test('user đổi tên, MSSV, FCM token của mình: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'Quân N.', studentId: 'SE183398', fcmTokens: ['t1'] }));
  });
  test('user và staff đọc hồ sơ người khác: bị từ chối', async () => {
    await assertFails(getDoc(doc(as('u1'), 'users/u2')));
    await assertFails(getDoc(doc(as('s1'), 'users/u1')));
  });
  test('chủ hồ sơ và admin đọc: được phép', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'users/u1')));
    await assertSucceeds(getDoc(doc(as('a1'), 'users/u1')));
  });
  test('admin đổi role và gán kiosk: được phép; staff đổi role người khác: bị từ chối', async () => {
    await assertSucceeds(updateDoc(doc(as('a1'), 'users/u2'), { role: 'staff', kioskId: 'k2' }));
    await assertFails(updateDoc(doc(as('s1'), 'users/u2'), { role: 'admin' }));
  });
  test('favorites và notifications: chủ ghi được, người khác bị từ chối', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'users/u1/favorites/m1'), { itemId: 'm1', name: 'Combo Tacos' }));
    await assertSucceeds(setDoc(doc(as('u1'), 'users/u1/notifications/n1'), { title: 'Đơn sẵn sàng', read: false }));
    await assertFails(setDoc(doc(as('u2'), 'users/u1/favorites/m2'), { itemId: 'm2' }));
    await assertFails(getDoc(doc(as('s1'), 'users/u1/notifications/n1')));
  });
});

describe('kiosks và slots', () => {
  test('chưa đăng nhập không đọc được kiosk; user đọc được', async () => {
    await assertFails(getDoc(doc(as(null), 'kiosks/k1')));
    await assertSucceeds(getDoc(doc(as('u1'), 'kiosks/k1')));
  });
  test('user sửa kiosk: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1'), { open: false }));
  });
  test('staff sửa kiosk của mình: được phép; kiosk khác: bị từ chối', async () => {
    await assertSucceeds(updateDoc(doc(as('s1'), 'kiosks/k1'), { open: false }));
    await assertFails(updateDoc(doc(as('s1'), 'kiosks/k2'), { open: false }));
  });
  test('staff chưa được gán kiosk: không sửa được kiosk nào', async () => {
    await assertFails(updateDoc(doc(as('s0'), 'kiosks/k1'), { open: false }));
  });
  test('chỉ admin tạo kiosk; không ai xoá', async () => {
    await assertSucceeds(setDoc(doc(as('a1'), 'kiosks/k9'), { name: 'Mới', open: true }));
    await assertFails(setDoc(doc(as('s1'), 'kiosks/k8'), { name: 'Mới', open: true }));
    await assertFails(deleteDoc(doc(as('a1'), 'kiosks/k1')));
  });
  test('khách đặt chỗ slot còn trống (booked +1): được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { booked: 2 }));
  });
  test('khách đặt chỗ slot đã đầy: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl2'), { booked: 2 }));
  });
  test('khách đổi booked nhiều hơn 1 hoặc sửa capacity: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { booked: 5 }));
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { capacity: 99 }));
  });
  test('khách huỷ chỗ (booked -1): được phép; staff của kiosk sửa capacity: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl2'), { booked: 0 }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'kiosks/k1/slots/sl1'), { capacity: 4 }));
  });
});

describe('menu_items và vouchers', () => {
  test('chưa đăng nhập không đọc được thực đơn', async () => {
    await assertFails(getDoc(doc(as(null), 'menu_items/m1')));
  });
  test('user đọc thực đơn và voucher: được phép', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'menu_items/m1')));
    await assertSucceeds(getDoc(doc(as('u1'), 'vouchers/BBSTUDENT')));
  });
  test('user sửa món: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'menu_items/m1'), { soldOut: true }));
  });
  test('staff thêm và sửa món của kiosk mình: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('s1'), 'menu_items/m2'), { kioskId: 'k1', name: 'Trà đào', priceVnd: 20000, prepMinutes: 2, soldOut: false }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'menu_items/m1'), { soldOut: true }));
  });
  test('staff sửa hoặc thêm món của kiosk khác: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s2'), 'menu_items/m1'), { soldOut: true }));
    await assertFails(setDoc(doc(as('s2'), 'menu_items/m3'), { kioskId: 'k1', name: 'X', priceVnd: 1000, prepMinutes: 1, soldOut: false }));
  });
  test('staff chuyển món sang kiosk khác: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'menu_items/m1'), { kioskId: 'k2' }));
  });
  test('món thiếu tên hoặc giá không dương: bị từ chối (K14-ERR)', async () => {
    await assertFails(setDoc(doc(as('s1'), 'menu_items/m4'), { kioskId: 'k1', name: '', priceVnd: 20000, prepMinutes: 2, soldOut: false }));
    await assertFails(setDoc(doc(as('s1'), 'menu_items/m5'), { kioskId: 'k1', name: 'Trà', priceVnd: 0, prepMinutes: 2, soldOut: false }));
  });
  test('admin sửa món của mọi kiosk: được phép; không ai xoá món', async () => {
    await assertSucceeds(updateDoc(doc(as('a1'), 'menu_items/m1'), { priceVnd: 41000 }));
    await assertFails(deleteDoc(doc(as('s1'), 'menu_items/m1')));
  });
  test('voucher: user và staff ghi bị từ chối; admin được phép', async () => {
    await assertFails(setDoc(doc(as('u1'), 'vouchers/X'), { discountVnd: 99999 }));
    await assertFails(setDoc(doc(as('s1'), 'vouchers/Y'), { discountVnd: 99999 }));
    await assertSucceeds(setDoc(doc(as('a1'), 'vouchers/Z'), { discountVnd: 5000 }));
  });
});

describe('carts', () => {
  test('user ghi giỏ hàng của mình: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'carts/u1'), { kioskId: 'k1', items: [] }));
  });
  test('user ghi hoặc đọc giỏ của người khác: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'carts/u2'), { items: [] }));
    await assertFails(getDoc(doc(as('u1'), 'carts/u2')));
  });
  test('giỏ quá 30 dòng: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'carts/u1'), { items: Array.from({ length: 31 }, () => item) }));
  });
});

describe('orders: tạo', () => {
  test('khách tạo đơn hợp lệ ở kiosk đang mở: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/n1'), newOrder()));
  });
  test('tiền mặt phải ở trạng thái chưa thu (unpaid), cổng khác phải paid', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/n2'), newOrder({ paymentMethod: 'cash', paymentStatus: 'unpaid' })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n3'), newOrder({ paymentMethod: 'cash', paymentStatus: 'paid' })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n4'), newOrder({ paymentMethod: 'momo', paymentStatus: 'unpaid' })));
  });
  test('tạo đơn ở kiosk đóng cửa: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n5'), newOrder({ kioskId: 'k3' })));
  });
  test('tạo đơn đã ở trạng thái khác pending: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n6'), newOrder({ status: 'delivered' })));
  });
  test('tạo đơn mang tên người khác: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n7'), newOrder({ uid: 'u2' })));
  });
  test('tổng tiền không khớp (total ≠ subtotal − discount): bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n8'), newOrder({ totalVnd: 1000 })));
  });
  test('giảm giá lớn hơn tạm tính hoặc đơn không có món: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n9'), newOrder({ discountVnd: 50000, totalVnd: -11000 })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n10'), newOrder({ items: [] })));
  });
  test('thiếu pickupCode hoặc createdAt không phải giờ máy chủ: bị từ chối', async () => {
    const { pickupCode, ...noCode } = newOrder();
    await assertFails(setDoc(doc(as('u1'), 'orders/n11'), noCode));
    await assertFails(setDoc(doc(as('u1'), 'orders/n12'), newOrder({ createdAt: Timestamp.fromDate(new Date('2020-01-01')) })));
  });
  test('chưa đăng nhập tạo đơn: bị từ chối', async () => {
    await assertFails(setDoc(doc(as(null), 'orders/n13'), newOrder()));
  });
});

describe('orders: đọc', () => {
  test('khách đọc đơn của mình: được phép; đơn người khác: bị từ chối', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'orders/o1')));
    await assertFails(getDoc(doc(as('u1'), 'orders/o2')));
  });
  test('staff đọc đơn của kiosk mình: được phép; kiosk khác: bị từ chối', async () => {
    await assertSucceeds(getDoc(doc(as('s1'), 'orders/o2')));
    await assertFails(getDoc(doc(as('s1'), 'orders/o5')));
  });
  test('admin đọc mọi đơn: được phép', async () => {
    await assertSucceeds(getDoc(doc(as('a1'), 'orders/o5')));
  });
});

describe('orders: khách sửa và huỷ', () => {
  test('khách huỷ đơn pending của mình: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'cancelled', cancelledBy: 'customer', cancelReason: 'Đổi ý' }));
  });
  test('khách huỷ nhưng ghi cancelledBy là staff: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'cancelled', cancelledBy: 'staff' }));
  });
  test('khách huỷ đơn đã chuyển sang preparing: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o3'), { status: 'cancelled', cancelledBy: 'customer' }));
  });
  test('khách tự chuyển đơn sang preparing hoặc delivered: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'delivered' }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'preparing' }));
  });
  test('khách sửa món và giờ nhận khi còn pending, tổng khớp: được phép (S09)', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'orders/o1'), {
      items: [{ ...item, quantity: 2 }], subtotalVnd: 78000, discountVnd: 0, totalVnd: 78000, note: 'Ít cay', updatedAt: serverTimestamp(),
    }));
  });
  test('khách sửa mà tổng không khớp: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { subtotalVnd: 78000, totalVnd: 1000 }));
  });
  test('khách đổi uid, kiosk, mã nhận hoặc cách thanh toán: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { uid: 'u2' }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { kioskId: 'k2' }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { pickupCode: '000000' }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { paymentStatus: 'paid' }));
  });
  test('khách sửa đơn của người khác: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o2'), { status: 'cancelled', cancelledBy: 'customer' }));
  });
});

describe('orders: nhân viên xử lý', () => {
  test('staff đi đúng chuỗi pending → preparing → ready → delivered (đơn đã thanh toán): được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'preparing', acceptedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'ready', readyAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'delivered', deliveredAt: serverTimestamp() }));
  });
  test('staff nhảy bước (pending → ready, pending → delivered): bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'ready' }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'delivered' }));
  });
  test('staff đưa đơn lùi trạng thái hoặc sửa đơn đã giao: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o3'), { status: 'pending' }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o6'), { status: 'preparing' }));
  });
  test('staff giao đơn tiền mặt: phải ghi paymentStatus paid (K06-CASH)', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o4'), { status: 'delivered' }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o4'), { status: 'delivered', paymentStatus: 'paid' }));
  });
  test('staff đánh dấu đã thu tiền với đơn không phải tiền mặt: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { paymentStatus: 'unpaid' }));
  });
  test('staff từ chối đơn phải có lý do và cancelledBy staff (K12)', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'cancelled' }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'cancelled', cancelledBy: 'staff', cancelReason: 'Hết nguyên liệu' }));
  });
  test('staff xử lý đơn của kiosk khác: bị từ chối; admin: được phép', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o5'), { status: 'preparing' }));
    await assertSucceeds(updateDoc(doc(as('a1'), 'orders/o5'), { status: 'preparing' }));
  });
  test('staff sửa nội dung đơn (items, tổng tiền, mã nhận): bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { totalVnd: 1000 }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { pickupCode: '999999' }));
  });
  test('không ai xoá được đơn', async () => {
    await assertFails(deleteDoc(doc(as('u1'), 'orders/o1')));
    await assertFails(deleteDoc(doc(as('s1'), 'orders/o1')));
    await assertFails(deleteDoc(doc(as('a1'), 'orders/o1')));
  });
});

describe('reviews', () => {
  const review = (over) => ({ uid: 'u1', orderId: 'o6', itemId: 'm1', kioskId: 'k1', rating: 5, comment: 'Ngon', createdAt: serverTimestamp(), ...over });

  test('khách đánh giá món trong đơn đã giao của mình: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'reviews/o6_m1'), review()));
  });
  test('đánh giá khi đơn chưa giao: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'reviews/o3_m1'), review({ orderId: 'o3' })));
  });
  test('đánh giá đơn của người khác hoặc đứng tên người khác: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u2'), 'reviews/o6_m1'), review({ uid: 'u2' })));
    await assertFails(setDoc(doc(as('u2'), 'reviews/o6_m1'), review()));
  });
  test('id không theo dạng {orderId}_{itemId} hoặc sao ngoài 1–5: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'reviews/tuychon'), review()));
    await assertFails(setDoc(doc(as('u1'), 'reviews/o6_m1'), review({ rating: 6 })));
    await assertFails(setDoc(doc(as('u1'), 'reviews/o6_m1'), review({ rating: 0 })));
  });
  test('mọi người đăng nhập đọc được; chủ sửa được; người khác không sửa; không ai xoá', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'reviews/o6_m1'), review({ createdAt: Timestamp.now() })));
    await assertSucceeds(getDoc(doc(as('u2'), 'reviews/o6_m1')));
    await assertSucceeds(updateDoc(doc(as('u1'), 'reviews/o6_m1'), { rating: 4, comment: 'Ổn', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('u2'), 'reviews/o6_m1'), { rating: 1 }));
    await assertFails(deleteDoc(doc(as('u1'), 'reviews/o6_m1')));
  });
});

describe('incidents', () => {
  const incident = (over) => ({
    uid: 'u1', orderId: 'o6', kioskId: 'k1', type: 'missing_item', description: 'Thiếu một ly trà',
    status: 'open', createdAt: serverTimestamp(), ...over,
  });
  const seedIncident = async () => env.withSecurityRulesDisabled(async (ctx) =>
    setDoc(doc(ctx.firestore(), 'incidents/i9'), incident({ createdAt: Timestamp.now() })));

  test('khách báo sự cố về đơn của mình: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'incidents/i1'), incident()));
  });
  test('báo sự cố cho đơn người khác, sai kiosk hoặc đứng tên người khác: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'incidents/i2'), incident({ orderId: 'o2' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/i3'), incident({ kioskId: 'k2' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/i4'), incident({ uid: 'u2' })));
  });
  test('loại sự cố lạ, mô tả quá 500 ký tự hoặc tự tạo ở trạng thái resolved: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'incidents/i5'), incident({ type: 'hack' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/i6'), incident({ description: 'a'.repeat(501) })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/i7'), incident({ status: 'resolved' })));
  });
  test('chủ và staff của kiosk đọc được; người khác và staff kiosk khác bị từ chối', async () => {
    await seedIncident();
    await assertSucceeds(getDoc(doc(as('u1'), 'incidents/i9')));
    await assertSucceeds(getDoc(doc(as('s1'), 'incidents/i9')));
    await assertFails(getDoc(doc(as('u2'), 'incidents/i9')));
    await assertFails(getDoc(doc(as('s2'), 'incidents/i9')));
  });
  test('staff của kiosk xử lý sự cố: được phép; khách hoặc kiosk khác: bị từ chối', async () => {
    await seedIncident();
    await assertSucceeds(updateDoc(doc(as('s1'), 'incidents/i9'), { status: 'resolved', resolution: 'Đã hoàn món', resolvedAt: serverTimestamp(), handledBy: 's1' }));
    await assertFails(updateDoc(doc(as('u1'), 'incidents/i9'), { status: 'resolved' }));
    await assertFails(updateDoc(doc(as('s2'), 'incidents/i9'), { status: 'resolved' }));
  });
  test('staff sửa nội dung khách đã gửi: bị từ chối', async () => {
    await seedIncident();
    await assertFails(updateDoc(doc(as('s1'), 'incidents/i9'), { description: 'Đã sửa' }));
  });
});

describe('collection lạ', () => {
  test('collection không khai báo: mặc định bị từ chối cho mọi vai trò', async () => {
    await assertFails(setDoc(doc(as('a1'), 'secrets/x'), { v: 1 }));
    await assertFails(getDoc(doc(as('s1'), 'secrets/x')));
  });
});

describe('Cloud Storage', () => {
  const pdf = new Uint8Array([37, 80, 68, 70]); // %PDF
  const png = new Uint8Array([137, 80, 78, 71]);
  const st = (uid) => (uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage());

  test('reports: chủ thư mục tải PDF lên và đọc lại: được phép', async () => {
    await assertSucceeds(uploadBytes(ref(st('u1'), 'reports/u1/bien-lai.pdf'), pdf, { contentType: 'application/pdf' }));
    await assertSucceeds(getBytes(ref(st('u1'), 'reports/u1/bien-lai.pdf')));
  });
  test('reports: người khác ghi vào thư mục của u1: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u2'), 'reports/u1/x.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('reports: người khác đọc tệp của u1: bị từ chối', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), 'reports/u1/y.pdf'), pdf, { contentType: 'application/pdf' }));
    await assertFails(getBytes(ref(st('u2'), 'reports/u1/y.pdf')));
  });
  test('reports: chưa đăng nhập: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st(null), 'reports/u1/z.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('reports: tệp không phải PDF: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u1'), 'reports/u1/a.png'), pdf, { contentType: 'image/png' }));
  });
  test('reports: tệp lớn hơn 5 MB: bị từ chối', async () => {
    const big = new Uint8Array(5 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(st('u1'), 'reports/u1/big.pdf'), big, { contentType: 'application/pdf' }));
  });
  test('đường dẫn ngoài danh sách: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u1'), 'other/u1/a.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('incidents: khách tải ảnh vào thư mục của mình: được phép; thư mục người khác: bị từ chối', async () => {
    await assertSucceeds(uploadBytes(ref(st('u1'), 'incidents/u1/a.png'), png, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(st('u2'), 'incidents/u1/b.png'), png, { contentType: 'image/png' }));
  });
  test('incidents: tệp không phải ảnh: bị từ chối; staff đọc ảnh khách: được phép; khách khác: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u1'), 'incidents/u1/c.pdf'), pdf, { contentType: 'application/pdf' }));
    await env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), 'incidents/u1/d.png'), png, { contentType: 'image/png' }));
    await assertSucceeds(getBytes(ref(st('s1'), 'incidents/u1/d.png')));
    await assertFails(getBytes(ref(st('u2'), 'incidents/u1/d.png')));
  });
  test('menu: staff của kiosk tải ảnh món: được phép; kiosk khác và khách: bị từ chối', async () => {
    await assertSucceeds(uploadBytes(ref(st('s1'), 'menu/k1/tacos.png'), png, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(st('s2'), 'menu/k1/x.png'), png, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(st('u1'), 'menu/k1/y.png'), png, { contentType: 'image/png' }));
  });
  test('menu: mọi người đăng nhập xem được ảnh món; chưa đăng nhập thì không', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), 'menu/k1/z.png'), png, { contentType: 'image/png' }));
    await assertSucceeds(getBytes(ref(st('u1'), 'menu/k1/z.png')));
    await assertFails(getBytes(ref(st(null), 'menu/k1/z.png')));
  });
});
