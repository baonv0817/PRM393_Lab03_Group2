// Kiểm Security Rules bằng Firebase Emulator: với mỗi vai trò (user, staff, admin) và mỗi collection
// có ít nhất một ca được phép và một ca bị từ chối. Chạy: `npm test` trong thư mục này.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc, Timestamp } from 'firebase/firestore';
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

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/u1'), { role: 'user', displayName: 'Quân' });
    await setDoc(doc(db, 'users/u2'), { role: 'user', displayName: 'Linh' });
    await setDoc(doc(db, 'users/s1'), { role: 'staff', displayName: 'Hạnh' });
    await setDoc(doc(db, 'users/a1'), { role: 'admin', displayName: 'Admin' });
    await setDoc(doc(db, 'menu_items/m1'), { name: 'Combo Tacos', priceVnd: 39000, soldOut: false });
    await setDoc(doc(db, 'kiosks/k1'), { name: 'Kiosk Q9 · Tầng 2', open: true });
    await setDoc(doc(db, 'vouchers/BBSTUDENT'), { discountVnd: 10000, expiresAt: Timestamp.fromDate(new Date('2100-01-01')) });
    await setDoc(doc(db, 'orders/o1'), { uid: 'u1', status: 'pending', totalVnd: 54000 });
    await setDoc(doc(db, 'orders/o2'), { uid: 'u2', status: 'pending', totalVnd: 20000 });
    await setDoc(doc(db, 'orders/o3'), { uid: 'u1', status: 'preparing', totalVnd: 20000 });
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
  test('user tự đổi role của mình: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { role: 'admin' }));
  });
  test('user đổi tên hiển thị của mình: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'Quân N.' }));
  });
  test('user đọc hồ sơ người khác: bị từ chối', async () => {
    await assertFails(getDoc(doc(as('u1'), 'users/u2')));
  });
  test('staff đọc hồ sơ bất kỳ: được phép', async () => {
    await assertSucceeds(getDoc(doc(as('s1'), 'users/u1')));
  });
  test('admin đổi role người khác: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('a1'), 'users/u2'), { role: 'staff' }));
  });
  test('staff đổi role người khác: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'users/u2'), { role: 'admin' }));
  });
});

describe('menu_items, kiosks, vouchers', () => {
  test('chưa đăng nhập không đọc được thực đơn', async () => {
    await assertFails(getDoc(doc(as(null), 'menu_items/m1')));
  });
  test('user đọc thực đơn, kiosk, voucher: được phép', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'menu_items/m1')));
    await assertSucceeds(getDoc(doc(as('u1'), 'kiosks/k1')));
    await assertSucceeds(getDoc(doc(as('u1'), 'vouchers/BBSTUDENT')));
  });
  test('user sửa món: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'menu_items/m1'), { soldOut: true }));
  });
  test('staff thêm và sửa món: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('s1'), 'menu_items/m2'), { name: 'Trà đào', priceVnd: 20000, soldOut: false }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'menu_items/m1'), { soldOut: true }));
  });
  test('staff xoá món: bị từ chối (dùng soldOut thay vì xoá)', async () => {
    await assertFails(deleteDoc(doc(as('s1'), 'menu_items/m1')));
  });
  test('user sửa kiosk hoặc voucher: bị từ chối; staff: được phép', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1'), { open: false }));
    await assertFails(setDoc(doc(as('u1'), 'vouchers/X'), { discountVnd: 99999 }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'kiosks/k1'), { open: false }));
  });
});

describe('carts', () => {
  test('user ghi giỏ hàng của mình: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'carts/u1'), { items: [] }));
  });
  test('user ghi hoặc đọc giỏ của người khác: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'carts/u2'), { items: [] }));
    await assertFails(getDoc(doc(as('u1'), 'carts/u2')));
  });
});

describe('orders', () => {
  test('user tạo đơn của mình ở trạng thái pending: được phép', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/n1'), { uid: 'u1', status: 'pending', totalVnd: 39000 }));
  });
  test('user tạo đơn đã ở trạng thái approved hoặc delivered: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n2'), { uid: 'u1', status: 'delivered', totalVnd: 39000 }));
  });
  test('user tạo đơn mang tên người khác: bị từ chối', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n3'), { uid: 'u2', status: 'pending', totalVnd: 39000 }));
  });
  test('user đọc đơn của mình: được phép; đơn người khác: bị từ chối', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'orders/o1')));
    await assertFails(getDoc(doc(as('u1'), 'orders/o2')));
  });
  test('staff đọc mọi đơn: được phép', async () => {
    await assertSucceeds(getDoc(doc(as('s1'), 'orders/o2')));
  });
  test('user huỷ đơn pending của mình: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'cancelled' }));
  });
  test('user huỷ đơn đã chuyển sang preparing: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o3'), { status: 'cancelled' }));
  });
  test('user tự chuyển đơn sang preparing hoặc delivered: bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'delivered' }));
  });
  test('staff chuyển đơn sang preparing, ready, delivered: được phép', async () => {
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o1'), { status: 'preparing' }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o1'), { status: 'ready' }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o1'), { status: 'delivered' }));
  });
  test('staff đưa đơn về trạng thái không hợp lệ (pending): bị từ chối', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o3'), { status: 'pending' }));
  });
  test('không ai xoá được đơn', async () => {
    await assertFails(deleteDoc(doc(as('u1'), 'orders/o1')));
    await assertFails(deleteDoc(doc(as('s1'), 'orders/o1')));
    await assertFails(deleteDoc(doc(as('a1'), 'orders/o1')));
  });
});

describe('reviews, incidents và collection lạ', () => {
  test('user gửi đánh giá và sự cố của mình: được phép; đứng tên người khác: bị từ chối', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'reviews/r1'), { uid: 'u1', orderId: 'o1', stars: 5 }));
    await assertFails(setDoc(doc(as('u1'), 'reviews/r2'), { uid: 'u2', orderId: 'o1', stars: 5 }));
    await assertSucceeds(setDoc(doc(as('u1'), 'incidents/i1'), { uid: 'u1', orderId: 'o1', text: 'Thiếu món' }));
  });
  test('staff đọc sự cố của khách: được phép; user khác: bị từ chối', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'incidents/i9'), { uid: 'u1', orderId: 'o1' }));
    await assertSucceeds(getDoc(doc(as('s1'), 'incidents/i9')));
    await assertFails(getDoc(doc(as('u2'), 'incidents/i9')));
  });
  test('collection không khai báo: mặc định bị từ chối cho mọi vai trò', async () => {
    await assertFails(setDoc(doc(as('a1'), 'secrets/x'), { v: 1 }));
    await assertFails(getDoc(doc(as('s1'), 'secrets/x')));
  });
});

describe('Cloud Storage reports/{uid}', () => {
  const pdf = new Uint8Array([37, 80, 68, 70]); // %PDF
  const st = (uid) => (uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage());

  test('chủ thư mục tải PDF lên và đọc lại: được phép', async () => {
    await assertSucceeds(uploadBytes(ref(st('u1'), 'reports/u1/bien-lai.pdf'), pdf, { contentType: 'application/pdf' }));
    await assertSucceeds(getBytes(ref(st('u1'), 'reports/u1/bien-lai.pdf')));
  });
  test('người khác ghi vào thư mục của u1: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u2'), 'reports/u1/x.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('người khác đọc tệp của u1: bị từ chối', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), 'reports/u1/y.pdf'), pdf, { contentType: 'application/pdf' }));
    await assertFails(getBytes(ref(st('u2'), 'reports/u1/y.pdf')));
  });
  test('chưa đăng nhập: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st(null), 'reports/u1/z.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('tệp không phải PDF: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u1'), 'reports/u1/a.png'), pdf, { contentType: 'image/png' }));
  });
  test('tệp lớn hơn 5 MB: bị từ chối', async () => {
    const big = new Uint8Array(5 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(st('u1'), 'reports/u1/big.pdf'), big, { contentType: 'application/pdf' }));
  });
  test('đường dẫn ngoài reports/: bị từ chối', async () => {
    await assertFails(uploadBytes(ref(st('u1'), 'other/u1/a.pdf'), pdf, { contentType: 'application/pdf' }));
  });
});
