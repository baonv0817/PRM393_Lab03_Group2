import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  average, collection, count, deleteDoc, deleteField, doc, getAggregateFromServer, getDoc, getDocs, increment, limit,
  orderBy, query, serverTimestamp, setDoc, sum, updateDoc, where, Timestamp,
} from 'firebase/firestore';
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

const created = () => ({ createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const touched = () => ({ updatedAt: serverTimestamp() });
const stored = () => ({ createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
const future = Timestamp.fromDate(new Date('2100-01-01'));
const past = Timestamp.fromDate(new Date('2020-01-01'));

const item = { itemId: 'k1-tacos', name: 'Combo Tacos', priceVnd: 39000, quantity: 1, note: '' };

const storedOrder = (over) => ({
  uid: 'u1', customerName: 'Quân', kioskId: 'k1', kioskName: 'Kiosk Q9 · Tầng 2',
  items: [item], subtotalVnd: 39000, discountVnd: 0, totalVnd: 39000,
  paymentMethod: 'momo', paymentStatus: 'paid', status: 'pending', pickupCode: '482915', ...stored(), ...over,
});

const newOrder = (over) => ({
  uid: 'u1', customerName: 'Quân', kioskId: 'k1', kioskName: 'Kiosk Q9 · Tầng 2',
  items: [item], subtotalVnd: 39000, discountVnd: 0, totalVnd: 39000,
  paymentMethod: 'momo', paymentStatus: 'paid', status: 'pending', pickupCode: '123456', ...created(), ...over,
});

const menuItem = (over) => ({
  kioskId: 'k1', dishId: 'tra-dao', name: 'Trà Đào', searchName: 'tra dao', category: 'drink',
  priceVnd: 20000, prepMinutes: 2, soldOut: false, ...over,
});

const voucher = (over) => ({
  title: 'Giảm 10K', discount: { type: 'fixed', amountVnd: 10000 }, minOrderVnd: 0,
  expiresAt: future, active: true, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/u1'), { role: 'user', displayName: 'Quân', email: 'u1@x.vn', ...stored() });
    await setDoc(doc(db, 'users/u2'), { role: 'user', displayName: 'Linh', ...stored() });
    await setDoc(doc(db, 'users/s1'), { role: 'staff', displayName: 'Hạnh', kioskId: 'k1', ...stored() });
    await setDoc(doc(db, 'users/s2'), { role: 'staff', displayName: 'Nam', kioskId: 'k2', ...stored() });
    await setDoc(doc(db, 'users/s0'), { role: 'staff', displayName: 'No kiosk yet', ...stored() });
    await setDoc(doc(db, 'users/a1'), { role: 'admin', displayName: 'Admin', ...stored() });
    await setDoc(doc(db, 'kiosks/k1'), { name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 6, ...stored() });
    await setDoc(doc(db, 'kiosks/k2'), { name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 10, ...stored() });
    await setDoc(doc(db, 'kiosks/k3'), { name: 'Nhà văn hóa SV · Tầng 1', open: false, waitMinutes: 0, ...stored() });
    await setDoc(doc(db, 'kiosks/k4'), { name: 'Paused', open: true, waitMinutes: 5, pausedUntil: future, ...stored() });
    await setDoc(doc(db, 'kiosks/k1/slots/sl1'), { capacity: 2, booked: 1, ...stored() });
    await setDoc(doc(db, 'kiosks/k1/slots/sl2'), { capacity: 1, booked: 1, ...stored() });
    await setDoc(doc(db, 'menu_items/k1-tacos'), menuItem({ dishId: 'tacos', name: 'Combo Tacos', searchName: 'combo tacos', category: 'food', priceVnd: 39000, prepMinutes: 4, ...stored() }));
    await setDoc(doc(db, 'vouchers/BBSTUDENT'), voucher({ minOrderVnd: 30000, ...stored() }));
    await setDoc(doc(db, 'vouchers/GIOVANG'), voucher({ discount: { type: 'percent', percent: 15, maxVnd: 15000 }, ...stored() }));
    await setDoc(doc(db, 'vouchers/BB20'), voucher({ discount: { type: 'fixed', amountVnd: 20000 }, expiresAt: past, ...stored() }));
    await setDoc(doc(db, 'vouchers/OFF'), voucher({ active: false, ...stored() }));
    await setDoc(doc(db, 'orders/o1'), storedOrder({ paymentMethod: 'cash', paymentStatus: 'unpaid' }));
    await setDoc(doc(db, 'orders/o2'), storedOrder({ uid: 'u2', customerName: 'Linh' }));
    await setDoc(doc(db, 'orders/o3'), storedOrder({ status: 'preparing' }));
    await setDoc(doc(db, 'orders/o4'), storedOrder({ status: 'ready', paymentMethod: 'cash', paymentStatus: 'unpaid' }));
    await setDoc(doc(db, 'orders/o5'), storedOrder({ kioskId: 'k2', kioskName: 'Kiosk Q9 · Tầng 4' }));
    await setDoc(doc(db, 'orders/o6'), storedOrder({ status: 'delivered' }));
  });
});

const as = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());

describe('timestamps (DB-16)', () => {
  test('a create without server createdAt/updatedAt, or with a device time, is denied', async () => {
    await assertFails(setDoc(doc(as('u3'), 'users/u3'), { role: 'user', displayName: 'New' }));
    await assertFails(setDoc(doc(as('u3'), 'users/u3'), { role: 'user', displayName: 'New', createdAt: Timestamp.now(), updatedAt: Timestamp.now() }));
  });
  test('an update must refresh updatedAt and cannot change createdAt', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'Quân N.' }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'Quân N.', createdAt: serverTimestamp(), ...touched() }));
    await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'Quân N.', ...touched() }));
  });
});

describe('users', () => {
  test('a user creates their own profile with role user: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u3'), 'users/u3'), { role: 'user', displayName: 'New', ...created() }));
  });
  test('a user creates a profile as staff or with a kiosk: denied', async () => {
    await assertFails(setDoc(doc(as('u3'), 'users/u3'), { role: 'staff', displayName: 'New', ...created() }));
    await assertFails(setDoc(doc(as('u3'), 'users/u3'), { role: 'user', displayName: 'New', kioskId: 'k1', ...created() }));
  });
  test('a user changes their own role, kiosk or email: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { role: 'admin', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'users/s1'), { kioskId: 'k2', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { email: 'other@x.vn', ...touched() }));
  });
  test('a user edits name, student ID and up to 5 FCM tokens: allowed; 6 tokens: denied', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'Quân N.', studentId: 'SE183398', fcmTokens: ['t1'], ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { fcmTokens: ['1', '2', '3', '4', '5', '6'], ...touched() }));
  });
  test('a user saves phone, default kiosk and default payment method: allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), {
      phone: '0912345678', defaultKioskId: 'k1', defaultPaymentMethod: 'cash', ...touched(),
    }));
  });
  test('a malformed student ID or phone, an unknown kiosk or payment method, a 61-character name: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { studentId: 'se1', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { phone: '912345678', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { defaultKioskId: 'nowhere', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { defaultPaymentMethod: 'bitcoin', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'users/u1'), { displayName: 'a'.repeat(61), ...touched() }));
  });
  test('a long name from Google does not block other updates such as lastLoginAt', async () => {
    await env.withSecurityRulesDisabled(async (ctx) =>
      updateDoc(doc(ctx.firestore(), 'users/u1'), { displayName: 'b'.repeat(80) }));
    await assertSucceeds(updateDoc(doc(as('u1'), 'users/u1'), { lastLoginAt: serverTimestamp(), ...touched() }));
  });
  test('users and staff read someone else\'s profile: denied; owner and admin: allowed', async () => {
    await assertFails(getDoc(doc(as('u1'), 'users/u2')));
    await assertFails(getDoc(doc(as('s1'), 'users/u1')));
    await assertSucceeds(getDoc(doc(as('u1'), 'users/u1')));
    await assertSucceeds(getDoc(doc(as('a1'), 'users/u1')));
  });
  test('an admin changes role and kiosk: allowed; staff changes someone\'s role: denied', async () => {
    await assertSucceeds(updateDoc(doc(as('a1'), 'users/u2'), { role: 'staff', kioskId: 'k2', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'users/u2'), { role: 'admin', ...touched() }));
  });
  test('an admin: a known role only, staff need a kiosk that exists, and nobody changes their own role', async () => {
    await assertSucceeds(updateDoc(doc(as('a1'), 'users/u2'), { role: 'staff', kioskId: 'k3', ...touched() }));
    await assertFails(updateDoc(doc(as('a1'), 'users/u1'), { role: 'owner', ...touched() }));
    await assertFails(updateDoc(doc(as('a1'), 'users/u1'), { role: 'staff', ...touched() }));
    await assertFails(updateDoc(doc(as('a1'), 'users/u1'), { role: 'staff', kioskId: 'nope', ...touched() }));
    await assertFails(updateDoc(doc(as('a1'), 'users/u1'), { role: 'user', kioskId: 'k1', ...touched() }));
    await assertFails(updateDoc(doc(as('a1'), 'users/a1'), { role: 'user', ...touched() }));
    await assertFails(updateDoc(doc(as('a1'), 'users/u1'), { displayName: 'Đổi tên hộ', ...touched() }));
  });
  test('favorites are keyed by dishId and notifications are owner-only', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'users/u1/favorites/tacos'), { dishId: 'tacos', name: 'Combo Tacos', ...created() }));
    await assertFails(setDoc(doc(as('u1'), 'users/u1/favorites/tacos2'), { dishId: 'tacos', name: 'Combo Tacos', ...created() }));
    await assertSucceeds(setDoc(doc(as('u1'), 'users/u1/notifications/o1_ready'), { title: 'Đơn sẵn sàng', read: false, ...created() }));
    await assertFails(setDoc(doc(as('u2'), 'users/u1/favorites/x'), { dishId: 'x', ...created() }));
    await assertFails(getDoc(doc(as('s1'), 'users/u1/notifications/o1_ready')));
  });
});

describe('K11 shift statistics', () => {
  const since = Timestamp.fromDate(new Date('2020-01-01'));
  const shift = (db, kioskId) => query(
    collection(db, 'orders'), where('kioskId', '==', kioskId), where('createdAt', '>=', since));
  test('staff count, sum and average the delivered orders of their own kiosk, and read the newest ones', async () => {
    const delivered = query(shift(as('s1'), 'k1'), where('status', '==', 'delivered'));
    await assertSucceeds(getAggregateFromServer(delivered, { n: count(), revenue: sum('totalVnd'), prep: average('prepSeconds') }));
    await assertSucceeds(getAggregateFromServer(query(shift(as('s1'), 'k1'), where('status', 'in', ['pending', 'preparing', 'ready'])), { n: count() }));
    await assertSucceeds(getDocs(query(shift(as('s1'), 'k1'), orderBy('createdAt', 'desc'), limit(500))));
  });
  test('staff cannot read the statistics of another kiosk, and users cannot read any', async () => {
    await assertFails(getAggregateFromServer(shift(as('s1'), 'k2'), { n: count() }));
    await assertFails(getDocs(query(shift(as('s1'), 'k2'), limit(500))));
    await assertFails(getAggregateFromServer(shift(as('u1'), 'k1'), { n: count() }));
  });
});

describe('kiosks and slots', () => {
  test('signed-out users cannot read kiosks; users can', async () => {
    await assertFails(getDoc(doc(as(null), 'kiosks/k1')));
    await assertSucceeds(getDoc(doc(as('u1'), 'kiosks/k1')));
  });
  test('a user edits a kiosk: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1'), { open: false, ...touched() }));
  });
  test('staff edit the operating fields of their own kiosk: allowed; another kiosk: denied', async () => {
    await assertSucceeds(updateDoc(doc(as('s1'), 'kiosks/k1'), { open: false, waitMinutes: 8, pausedUntil: future, ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'kiosks/k2'), { open: false, ...touched() }));
  });
  test('K10: staff write the shop settings as the app does, removing the fields they empty', async () => {
    const k1 = doc(as('s1'), 'kiosks/k1');
    await assertSucceeds(updateDoc(k1, {
      open: true, waitMinutes: 9, pausedUntil: future, maxOrdersPerSlot: 5, notice: 'Hết sốt',
      openTime: '06:30', closeTime: '17:00', ...touched(),
    }));
    await assertSucceeds(updateDoc(k1, {
      open: true, waitMinutes: 9, pausedUntil: deleteField(), maxOrdersPerSlot: deleteField(), notice: deleteField(),
      openTime: deleteField(), closeTime: deleteField(), ...touched(),
    }));
    await assertFails(updateDoc(k1, { open: true, waitMinutes: 121, ...touched() }));
    await assertFails(updateDoc(k1, { open: true, waitMinutes: 6, maxOrdersPerSlot: 0, ...touched() }));
  });
  test('staff rename their kiosk or set a negative wait time: denied (admin only, valid values)', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'kiosks/k1'), { name: 'Renamed', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'kiosks/k1'), { waitMinutes: -5, ...touched() }));
    await assertSucceeds(updateDoc(doc(as('a1'), 'kiosks/k1'), { name: 'Renamed', ...touched() }));
  });
  test('staff without a kiosk cannot edit any kiosk', async () => {
    await assertFails(updateDoc(doc(as('s0'), 'kiosks/k1'), { open: false, ...touched() }));
  });
  test('only admins create kiosks; nobody deletes', async () => {
    await assertSucceeds(setDoc(doc(as('a1'), 'kiosks/k9'), { name: 'New', open: true, waitMinutes: 5, ...created() }));
    await assertFails(setDoc(doc(as('s1'), 'kiosks/k8'), { name: 'New', open: true, waitMinutes: 5, ...created() }));
    await assertFails(deleteDoc(doc(as('a1'), 'kiosks/k1')));
  });
  test('a customer books a free slot with increment(1): allowed; a full slot: denied', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { booked: increment(1), ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl2'), { booked: increment(1), ...touched() }));
  });
  test('a customer moves booked by more than one or edits capacity: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { booked: 5, ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { capacity: 99, ...touched() }));
  });
  test('a customer releases a slot (increment(-1)): allowed; staff of the kiosk edit capacity: allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl2'), { booked: increment(-1), ...touched() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'kiosks/k1/slots/sl1'), { capacity: 4, ...touched() }));
  });
});

describe('menu_items', () => {
  test('signed-out users cannot read the menu; users can', async () => {
    await assertFails(getDoc(doc(as(null), 'menu_items/k1-tacos')));
    await assertSucceeds(getDoc(doc(as('u1'), 'menu_items/k1-tacos')));
  });
  test('a user edits an item: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'menu_items/k1-tacos'), { soldOut: true, ...touched() }));
  });
  test('staff add and edit items of their kiosk with id {kioskId}-{dishId}: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('s1'), 'menu_items/k1-tra-dao'), { ...menuItem(), ...created() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'menu_items/k1-tacos'), { soldOut: true, soldOutReason: 'machineBroken', availableAgainAt: future, ...touched() }));
  });
  test('an item whose id does not match {kioskId}-{dishId}: denied', async () => {
    await assertFails(setDoc(doc(as('s1'), 'menu_items/random'), { ...menuItem(), ...created() }));
  });
  test('staff edit or add items of another kiosk, or move an item: denied', async () => {
    await assertFails(updateDoc(doc(as('s2'), 'menu_items/k1-tacos'), { soldOut: true, ...touched() }));
    await assertFails(setDoc(doc(as('s2'), 'menu_items/k1-x'), { ...menuItem({ dishId: 'x' }), ...created() }));
    await assertFails(updateDoc(doc(as('s1'), 'menu_items/k1-tacos'), { kioskId: 'k2', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'menu_items/k1-tacos'), { dishId: 'other', ...touched() }));
  });
  test('missing name, non-positive price, unknown category or sold-out reason: denied (K14-ERR)', async () => {
    await assertFails(setDoc(doc(as('s1'), 'menu_items/k1-a'), { ...menuItem({ dishId: 'a', name: '' }), ...created() }));
    await assertFails(setDoc(doc(as('s1'), 'menu_items/k1-b'), { ...menuItem({ dishId: 'b', priceVnd: 0 }), ...created() }));
    await assertFails(setDoc(doc(as('s1'), 'menu_items/k1-c'), { ...menuItem({ dishId: 'c', category: 'Tacos' }), ...created() }));
    await assertFails(updateDoc(doc(as('s1'), 'menu_items/k1-tacos'), { soldOutReason: 'lazy', ...touched() }));
  });
  test('admins edit items of every kiosk: allowed; nobody deletes items', async () => {
    await assertSucceeds(updateDoc(doc(as('a1'), 'menu_items/k1-tacos'), { priceVnd: 41000, ...touched() }));
    await assertFails(deleteDoc(doc(as('s1'), 'menu_items/k1-tacos')));
  });
});

describe('vouchers', () => {
  test('users read vouchers; users and staff cannot write them', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'vouchers/BBSTUDENT')));
    await assertFails(setDoc(doc(as('u1'), 'vouchers/HACK'), { ...voucher(), ...created() }));
    await assertFails(setDoc(doc(as('s1'), 'vouchers/HACK'), { ...voucher(), ...created() }));
  });
  test('an admin creates a fixed or a percentage voucher: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('a1'), 'vouchers/FIX5K'), { ...voucher({ discount: { type: 'fixed', amountVnd: 5000 } }), ...created() }));
    await assertSucceeds(setDoc(doc(as('a1'), 'vouchers/PCT10'), {
      ...voucher({ discount: { type: 'percent', percent: 10, maxVnd: 20000 }, activeFrom: '10:15', activeTo: '10:30' }), ...created(),
    }));
  });
  test('a voucher mixing both shapes, without a cap, over 100% or with a bad code: denied (DB-20)', async () => {
    await assertFails(setDoc(doc(as('a1'), 'vouchers/MIX'), { ...voucher({ discount: { type: 'fixed', amountVnd: 5000, percent: 10 } }), ...created() }));
    await assertFails(setDoc(doc(as('a1'), 'vouchers/NOCAP'), { ...voucher({ discount: { type: 'percent', percent: 10 } }), ...created() }));
    await assertFails(setDoc(doc(as('a1'), 'vouchers/BIG'), { ...voucher({ discount: { type: 'percent', percent: 150, maxVnd: 1000 } }), ...created() }));
    await assertFails(setDoc(doc(as('a1'), 'vouchers/lower'), { ...voucher(), ...created() }));
    await assertFails(setDoc(doc(as('a1'), 'vouchers/BADTIME'), { ...voucher({ activeFrom: '25:00', activeTo: '10:30' }), ...created() }));
  });
  test('nobody deletes a voucher (switch active off instead)', async () => {
    await assertFails(deleteDoc(doc(as('a1'), 'vouchers/BBSTUDENT')));
  });
});

describe('carts', () => {
  test('a user writes their own cart: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'carts/u1'), { kioskId: 'k1', items: [], pickupSlotId: 'sl1', ...created() }));
  });
  test('a user writes or reads someone else\'s cart: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'carts/u2'), { kioskId: 'k1', items: [], ...created() }));
    await assertFails(getDoc(doc(as('u1'), 'carts/u2')));
  });
  test('a cart with more than 30 lines or without a kiosk: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'carts/u1'), { kioskId: 'k1', items: Array.from({ length: 31 }, () => item), ...created() }));
    await assertFails(setDoc(doc(as('u1'), 'carts/u1'), { items: [], ...created() }));
  });
});

describe('orders: create', () => {
  test('a customer places a valid order at an open kiosk: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/n1'), newOrder()));
  });
  test('cash must be unpaid, the other methods paid', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/n2'), newOrder({ paymentMethod: 'cash', paymentStatus: 'unpaid' })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n3'), newOrder({ paymentMethod: 'cash', paymentStatus: 'paid' })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n4'), newOrder({ paymentMethod: 'momo', paymentStatus: 'unpaid' })));
  });
  test('ordering at a closed or paused kiosk: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n5'), newOrder({ kioskId: 'k3' })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n5b'), newOrder({ kioskId: 'k4' })));
  });
  test('an order created in another status or for someone else: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n6'), newOrder({ status: 'delivered' })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n7'), newOrder({ uid: 'u2' })));
  });
  test('a total that does not match, a discount over the subtotal, or no items: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/n8'), newOrder({ totalVnd: 1000 })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n9'), newOrder({ discountVnd: 50000, totalVnd: -11000 })));
    await assertFails(setDoc(doc(as('u1'), 'orders/n10'), newOrder({ items: [] })));
  });
  test('missing pickupCode or a device createdAt: denied', async () => {
    const { pickupCode, ...noCode } = newOrder();
    await assertFails(setDoc(doc(as('u1'), 'orders/n11'), noCode));
    await assertFails(setDoc(doc(as('u1'), 'orders/n12'), newOrder({ createdAt: past })));
  });
  test('signed-out users cannot order', async () => {
    await assertFails(setDoc(doc(as(null), 'orders/n13'), newOrder()));
  });
});

describe('orders: discounts and vouchers (DB-18)', () => {
  test('a discount without a voucher (a free order): denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/v1'), newOrder({ discountVnd: 39000, totalVnd: 0 })));
  });
  test('the exact fixed discount of a valid voucher: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/v2'), newOrder({ voucherCode: 'BBSTUDENT', discountVnd: 10000, totalVnd: 29000 })));
  });
  test('the exact percentage discount, rounded down and capped: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/v3'), newOrder({ voucherCode: 'GIOVANG', discountVnd: 5850, totalVnd: 33150 })));
    await assertSucceeds(setDoc(doc(as('u1'), 'orders/v4'), newOrder({
      items: [{ ...item, quantity: 4 }], subtotalVnd: 156000, voucherCode: 'GIOVANG', discountVnd: 15000, totalVnd: 141000,
    })));
  });
  test('a discount larger than the voucher gives: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/v5'), newOrder({ voucherCode: 'BBSTUDENT', discountVnd: 20000, totalVnd: 19000 })));
  });
  test('an unknown, expired or inactive voucher, or an order under the minimum: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'orders/v6'), newOrder({ voucherCode: 'NOPE', discountVnd: 10000, totalVnd: 29000 })));
    await assertFails(setDoc(doc(as('u1'), 'orders/v7'), newOrder({ voucherCode: 'BB20', discountVnd: 20000, totalVnd: 19000 })));
    await assertFails(setDoc(doc(as('u1'), 'orders/v8'), newOrder({ voucherCode: 'OFF', discountVnd: 10000, totalVnd: 29000 })));
    await assertFails(setDoc(doc(as('u1'), 'orders/v9'), newOrder({
      items: [{ ...item, priceVnd: 20000 }], subtotalVnd: 20000, voucherCode: 'BBSTUDENT', discountVnd: 10000, totalVnd: 10000,
    })));
  });
  test('editing a pending order cannot raise the discount past the voucher (S09)', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { discountVnd: 39000, totalVnd: 0, ...touched() }));
  });
});

describe('orders: read', () => {
  test('customers read their own orders only', async () => {
    await assertSucceeds(getDoc(doc(as('u1'), 'orders/o1')));
    await assertFails(getDoc(doc(as('u1'), 'orders/o2')));
  });
  test('staff read orders of their kiosk only; admins read all', async () => {
    await assertSucceeds(getDoc(doc(as('s1'), 'orders/o2')));
    await assertFails(getDoc(doc(as('s1'), 'orders/o5')));
    await assertSucceeds(getDoc(doc(as('a1'), 'orders/o5')));
  });
});

describe('orders: customer edits and cancels', () => {
  test('a customer cancels their pending order with the server time: allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'orders/o1'), {
      status: 'cancelled', cancelledBy: 'customer', cancelReason: 'customerRequest', cancelledAt: serverTimestamp(), ...touched(),
    }));
  });
  test('cancelling as staff, without cancelledAt, or after preparing started: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'cancelled', cancelledBy: 'staff', cancelledAt: serverTimestamp(), ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'cancelled', cancelledBy: 'customer', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o3'), { status: 'cancelled', cancelledBy: 'customer', cancelledAt: serverTimestamp(), ...touched() }));
  });
  test('a customer moves their order forward: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'delivered', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { status: 'preparing', ...touched() }));
  });
  test('editing items and pickup while pending with a matching total: allowed (S09)', async () => {
    await assertSucceeds(updateDoc(doc(as('u1'), 'orders/o1'), {
      items: [{ ...item, quantity: 2 }], subtotalVnd: 78000, discountVnd: 0, totalVnd: 78000, note: 'Ít cay', ...touched(),
    }));
  });
  test('a total that does not match, or changing uid, kiosk, pickup code or payment: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { subtotalVnd: 78000, totalVnd: 1000, ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { uid: 'u2', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { kioskId: 'k2', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { pickupCode: '000000', ...touched() }));
    await assertFails(updateDoc(doc(as('u1'), 'orders/o1'), { paymentStatus: 'paid', ...touched() }));
  });
  test('editing someone else\'s order: denied', async () => {
    await assertFails(updateDoc(doc(as('u1'), 'orders/o2'), { status: 'cancelled', cancelledBy: 'customer', cancelledAt: serverTimestamp(), ...touched() }));
  });
});

describe('orders: staff handling', () => {
  test('staff follow pending → preparing → ready → delivered with each step\'s server time: allowed', async () => {
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'preparing', acceptedAt: serverTimestamp(), readyBy: future, ...touched() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'ready', readyAt: serverTimestamp(), prepSeconds: 240, ...touched() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'delivered', deliveredAt: serverTimestamp(), ...touched() }));
  });
  test('a step without its server time, or with a device time: denied (R-15)', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'preparing', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'preparing', acceptedAt: past, ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o3'), { status: 'ready', readyAt: serverTimestamp(), prepSeconds: -1, ...touched() }));
  });
  test('skipping or going back a step, or editing a delivered order: denied', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'ready', readyAt: serverTimestamp(), ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'delivered', deliveredAt: serverTimestamp(), ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o3'), { status: 'pending', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o6'), { status: 'preparing', acceptedAt: serverTimestamp(), ...touched() }));
  });
  test('handing over a cash order must record paid (K06-CASH)', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o4'), { status: 'delivered', deliveredAt: serverTimestamp(), ...touched() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o4'), { status: 'delivered', deliveredAt: serverTimestamp(), paymentStatus: 'paid', ...touched() }));
  });
  test('staff mark a non-cash order unpaid: denied', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { paymentStatus: 'unpaid', ...touched() }));
  });
  test('staff reject with a reason, cancelledBy staff and the server time (K12)', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { status: 'cancelled', cancelledAt: serverTimestamp(), ...touched() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'orders/o2'), {
      status: 'cancelled', cancelledBy: 'staff', cancelReason: 'soldOut', cancelledAt: serverTimestamp(), ...touched(),
    }));
  });
  test('staff of another kiosk: denied; admin: allowed', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o5'), { status: 'preparing', acceptedAt: serverTimestamp(), ...touched() }));
    await assertSucceeds(updateDoc(doc(as('a1'), 'orders/o5'), { status: 'preparing', acceptedAt: serverTimestamp(), ...touched() }));
  });
  test('staff edit the content of an order: denied; nobody deletes orders', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { totalVnd: 1000, ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'orders/o2'), { pickupCode: '999999', ...touched() }));
    await assertFails(deleteDoc(doc(as('u1'), 'orders/o1')));
    await assertFails(deleteDoc(doc(as('s1'), 'orders/o1')));
    await assertFails(deleteDoc(doc(as('a1'), 'orders/o1')));
  });
});

describe('reviews', () => {
  const review = (over) => ({
    uid: 'u1', orderId: 'o6', itemId: 'k1-tacos', dishId: 'tacos', kioskId: 'k1', authorName: 'Quân N.',
    rating: 5, comment: 'Ngon', tags: ['tasty'], ...created(), ...over,
  });

  test('a customer reviews an item of their delivered order: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), review()));
  });
  test('reviewing an order that is not delivered, or someone else\'s: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'reviews/o3_k1-tacos'), review({ orderId: 'o3' })));
    await assertFails(setDoc(doc(as('u2'), 'reviews/o6_k1-tacos'), review({ uid: 'u2' })));
    await assertFails(setDoc(doc(as('u2'), 'reviews/o6_k1-tacos'), review()));
  });
  test('a wrong id, a rating outside 1–5, no dishId or a long comment: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'reviews/whatever'), review()));
    await assertFails(setDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), review({ rating: 6 })));
    await assertFails(setDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), review({ rating: 0 })));
    const { dishId, ...noDish } = review();
    await assertFails(setDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), noDish));
    await assertFails(setDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), review({ comment: 'a'.repeat(501) })));
  });
  test('signed-in users read; the owner edits; others cannot; nobody deletes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'reviews/o6_k1-tacos'), review(stored())));
    await assertSucceeds(getDoc(doc(as('u2'), 'reviews/o6_k1-tacos')));
    await assertSucceeds(updateDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), { rating: 4, comment: 'Ổn', tags: ['fast'], ...touched() }));
    await assertFails(updateDoc(doc(as('u2'), 'reviews/o6_k1-tacos'), { rating: 1, ...touched() }));
    await assertFails(deleteDoc(doc(as('u1'), 'reviews/o6_k1-tacos')));
  });
});

describe('incidents', () => {
  const incident = (over) => ({
    uid: 'u1', orderId: 'o6', kioskId: 'k1', type: 'missingItem', description: 'Thiếu một ly trà',
    status: 'open', ...created(), ...over,
  });
  const seedIncident = async () => env.withSecurityRulesDisabled(async (ctx) =>
    setDoc(doc(ctx.firestore(), 'incidents/o6'), incident(stored())));

  test('a customer reports an incident on their order, id = orderId: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'incidents/o6'), incident()));
  });
  test('an id other than the order id, or a second incident for the same order: denied (DB-26)', async () => {
    await assertFails(setDoc(doc(as('u1'), 'incidents/random'), incident()));
    await seedIncident();
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ description: 'Again' })));
  });
  test('reporting on someone else\'s order, the wrong kiosk or as someone else: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'incidents/o2'), incident({ orderId: 'o2' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ kioskId: 'k2' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ uid: 'u2' })));
  });
  test('the old snake_case type, an unknown type, a long text or a resolved start: denied (DB-27)', async () => {
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ type: 'missing_item' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ type: 'hack' })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ description: 'a'.repeat(501) })));
    await assertFails(setDoc(doc(as('u1'), 'incidents/o6'), incident({ status: 'resolved' })));
  });
  test('the owner and staff of the kiosk read; others are denied', async () => {
    await seedIncident();
    await assertSucceeds(getDoc(doc(as('u1'), 'incidents/o6')));
    await assertSucceeds(getDoc(doc(as('s1'), 'incidents/o6')));
    await assertFails(getDoc(doc(as('u2'), 'incidents/o6')));
    await assertFails(getDoc(doc(as('s2'), 'incidents/o6')));
  });
  test('staff refund up to the order total: allowed; above it or without an amount: denied', async () => {
    await seedIncident();
    const resolve = (over) => ({ status: 'resolved', resolution: 'refunded', resolvedAt: serverTimestamp(), handledBy: 's1', ...touched(), ...over });
    await assertFails(updateDoc(doc(as('s1'), 'incidents/o6'), resolve({ refundVnd: 50000 })));
    await assertFails(updateDoc(doc(as('s1'), 'incidents/o6'), resolve({})));
    await assertSucceeds(updateDoc(doc(as('s1'), 'incidents/o6'), resolve({ refundVnd: 20000 })));
  });
  test('staff reject with an explanation: allowed; without one: denied', async () => {
    await seedIncident();
    const reject = (over) => ({ status: 'resolved', resolution: 'rejected', resolvedAt: serverTimestamp(), handledBy: 's1', ...touched(), ...over });
    await assertFails(updateDoc(doc(as('s1'), 'incidents/o6'), reject({})));
    await assertSucceeds(updateDoc(doc(as('s1'), 'incidents/o6'), reject({ resolutionNote: 'Đã kiểm camera, đủ món' })));
  });
  test('customers, staff of another kiosk, or editing the customer\'s text: denied', async () => {
    await seedIncident();
    await assertFails(updateDoc(doc(as('u1'), 'incidents/o6'), { status: 'inProgress', ...touched() }));
    await assertFails(updateDoc(doc(as('s2'), 'incidents/o6'), { status: 'inProgress', ...touched() }));
    await assertFails(updateDoc(doc(as('s1'), 'incidents/o6'), { description: 'Edited', ...touched() }));
    await assertSucceeds(updateDoc(doc(as('s1'), 'incidents/o6'), { status: 'inProgress', ...touched() }));
  });
});

describe('reports (R-29)', () => {
  const report = (over) => ({
    uid: 'u1', orderId: 'o6', fileName: 'bien-lai.pdf', url: 'https://res.cloudinary.com/demo/x.pdf',
    publicId: 'breakbite/reports/u1/x', sizeKb: 42, ...created(), ...over,
  });
  test('a customer saves metadata of their own receipt: allowed; reads it back: allowed', async () => {
    await assertSucceeds(setDoc(doc(as('u1'), 'reports/r1'), report()));
    await assertSucceeds(getDoc(doc(as('u1'), 'reports/r1')));
  });
  test('for someone else\'s order, as someone else, or a non-https link: denied', async () => {
    await assertFails(setDoc(doc(as('u1'), 'reports/r2'), report({ orderId: 'o2' })));
    await assertFails(setDoc(doc(as('u2'), 'reports/r3'), report()));
    await assertFails(setDoc(doc(as('u1'), 'reports/r4'), report({ url: 'http://x' })));
  });
  test('others cannot read it; nobody edits or deletes it', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'reports/r5'), report(stored())));
    await assertFails(getDoc(doc(as('u2'), 'reports/r5')));
    await assertFails(updateDoc(doc(as('u1'), 'reports/r5'), { fileName: 'x.pdf', ...touched() }));
    await assertFails(deleteDoc(doc(as('u1'), 'reports/r5')));
  });
  test('listing my own reports, newest first: allowed; listing without the uid filter or someone else\x27s: denied', async () => {
    const mine = (db, uid) => query(collection(db, 'reports'), where('uid', '==', uid), orderBy('createdAt', 'desc'), limit(10));
    await assertSucceeds(getDocs(mine(as('u1'), 'u1')));
    await assertFails(getDocs(mine(as('u2'), 'u1')));
    await assertFails(getDocs(query(collection(as('u1'), 'reports'), limit(10))));
  });
});

describe('announcements (final assignment)', () => {
  test('admins publish; users read published ones only; users cannot write', async () => {
    await assertSucceeds(setDoc(doc(as('a1'), 'announcements/a1'), { title: 'Nghỉ lễ', body: '…', status: 'published', createdBy: 'a1', ...created() }));
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'announcements/d1'), { title: 'Nháp', status: 'draft', createdBy: 'a1', ...stored() }));
    await assertSucceeds(getDoc(doc(as('u1'), 'announcements/a1')));
    await assertFails(getDoc(doc(as('u1'), 'announcements/d1')));
    await assertFails(setDoc(doc(as('u1'), 'announcements/x'), { title: 'Spam', status: 'published', createdBy: 'u1', ...created() }));
  });
});

describe('audit_logs (admin website)', () => {
  const line = (over) => ({
    actorUid: 'a1', actorName: 'Admin', action: 'kiosk.save', target: 'kiosks/k1', summary: 'Sửa kiosk', ...created(), ...over,
  });
  test('an admin writes a line under their own uid and reads the log; nobody edits or deletes', async () => {
    await assertSucceeds(setDoc(doc(as('a1'), 'audit_logs/l1'), line()));
    await assertSucceeds(getDoc(doc(as('a1'), 'audit_logs/l1')));
    await assertFails(updateDoc(doc(as('a1'), 'audit_logs/l1'), { summary: 'Đã sửa', ...touched() }));
    await assertFails(deleteDoc(doc(as('a1'), 'audit_logs/l1')));
  });
  test('a line in the name of another user, with extra fields or a device time: denied', async () => {
    await assertFails(setDoc(doc(as('a1'), 'audit_logs/l2'), line({ actorUid: 'u1' })));
    await assertFails(setDoc(doc(as('a1'), 'audit_logs/l3'), line({ extra: 1 })));
    await assertFails(setDoc(doc(as('a1'), 'audit_logs/l4'), line({ createdAt: Timestamp.now(), updatedAt: Timestamp.now() })));
  });
  test('users and staff neither read nor write the log', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'audit_logs/l5'), line()));
    await assertFails(getDoc(doc(as('u1'), 'audit_logs/l5')));
    await assertFails(getDoc(doc(as('s1'), 'audit_logs/l5')));
    await assertFails(setDoc(doc(as('s1'), 'audit_logs/l6'), line({ actorUid: 's1' })));
  });
});

describe('unknown collections', () => {
  test('a collection not declared in the rules is denied for every role', async () => {
    await assertFails(setDoc(doc(as('a1'), 'secrets/x'), { v: 1 }));
    await assertFails(getDoc(doc(as('s1'), 'secrets/x')));
  });
});

describe('Cloud Storage (fallback, not used by the app)', () => {
  const pdf = new Uint8Array([37, 80, 68, 70]);
  const png = new Uint8Array([137, 80, 78, 71]);
  const st = (uid) => (uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage());

  test('reports: the owner uploads a PDF and reads it back; others and signed-out users are denied', async () => {
    await assertSucceeds(uploadBytes(ref(st('u1'), 'reports/u1/bien-lai.pdf'), pdf, { contentType: 'application/pdf' }));
    await assertSucceeds(getBytes(ref(st('u1'), 'reports/u1/bien-lai.pdf')));
    await assertFails(uploadBytes(ref(st('u2'), 'reports/u1/x.pdf'), pdf, { contentType: 'application/pdf' }));
    await assertFails(uploadBytes(ref(st(null), 'reports/u1/z.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('reports: non-PDF or over 5 MB: denied; unknown paths: denied', async () => {
    await assertFails(uploadBytes(ref(st('u1'), 'reports/u1/a.png'), pdf, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(st('u1'), 'reports/u1/big.pdf'), new Uint8Array(5 * 1024 * 1024 + 1), { contentType: 'application/pdf' }));
    await assertFails(uploadBytes(ref(st('u1'), 'other/u1/a.pdf'), pdf, { contentType: 'application/pdf' }));
  });
  test('incidents and menu photos follow owner and kiosk rules', async () => {
    await assertSucceeds(uploadBytes(ref(st('u1'), 'incidents/u1/a.png'), png, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(st('u2'), 'incidents/u1/b.png'), png, { contentType: 'image/png' }));
    await assertSucceeds(uploadBytes(ref(st('s1'), 'menu/k1/tacos.png'), png, { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(st('s2'), 'menu/k1/x.png'), png, { contentType: 'image/png' }));
  });
});

// ---------------------------------------------------------------------------------------------------------------
// Final assignment, Appendix B: at least one allowed and one denied case per role per collection.
// u1 = user, s1 = staff of kiosk k1, a1 = admin. The IDs are the rows of docs/test-report.md section 2.
// ---------------------------------------------------------------------------------------------------------------
const seedMatrix = async () => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'menu_items/k2-banh-mi'), menuItem({ kioskId: 'k2', dishId: 'banh-mi', name: 'Bánh mì', searchName: 'banh mi', category: 'food', ...stored() }));
  await setDoc(doc(db, 'carts/u1'), { kioskId: 'k1', items: [], ...stored() });
  await setDoc(doc(db, 'incidents/o6'), { uid: 'u1', orderId: 'o6', kioskId: 'k1', type: 'late', description: 'Chờ lâu', status: 'open', ...stored() });
  await setDoc(doc(db, 'reports/r1'), { uid: 'u1', orderId: 'o6', fileName: 'a.pdf', url: 'https://x/a.pdf', publicId: 'p', sizeKb: 3, ...stored() });
  await setDoc(doc(db, 'announcements/pub'), { title: 'Nghỉ lễ', body: 'Kiosk nghỉ 2/9', status: 'published', createdBy: 'a1', ...stored() });
  await setDoc(doc(db, 'announcements/draft'), { title: 'Nháp', body: 'Chưa gửi', status: 'draft', createdBy: 'a1', ...stored() });
  await setDoc(doc(db, 'users/u1/notifications/n1'), { title: 'Đơn sẵn sàng', body: '…', read: false, ...stored() });
});

const announcement = (over) => ({ title: 'Đổi giờ mở cửa', body: 'Kiosk Q9 mở từ 6:30', status: 'published', createdBy: 'a1', ...created(), ...over });
const newKiosk = () => ({ name: 'Kiosk mới', open: false, waitMinutes: 0, ...created() });
const newMenuItem = () => menuItem({ dishId: 'cafe', name: 'Cà phê', searchName: 'ca phe', ...created() });
const reviewOf = (uid, orderId) => ({ uid, orderId, itemId: 'k1-tacos', dishId: 'tacos', kioskId: 'k1', rating: 5, ...created() });
const reportOf = (uid) => ({ uid, fileName: 'b.pdf', url: 'https://x/b.pdf', publicId: 'q', sizeKb: 4, ...created() });
const note = () => ({ title: 't', body: 'b', read: false, ...created() });

const ALLOWED = 'Allowed';
const DENIED = 'Denied';

export const MATRIX = [
  // users/{uid}
  ['R-01', 'users', 'user', 'read own profile', ALLOWED, () => getDoc(doc(as('u1'), 'users/u1'))],
  ['R-02', 'users', 'user', 'update own role to admin', DENIED, () => updateDoc(doc(as('u1'), 'users/u1'), { role: 'admin', ...touched() })],
  ['R-03', 'users', 'staff', 'update own display name', ALLOWED, () => updateDoc(doc(as('s1'), 'users/s1'), { displayName: 'Hạnh K1', ...touched() })],
  ['R-04', 'users', 'staff', 'read a customer profile', DENIED, () => getDoc(doc(as('s1'), 'users/u1'))],
  ['R-05', 'users', 'admin', 'change a user role to staff', ALLOWED, () => updateDoc(doc(as('a1'), 'users/u2'), { role: 'staff', kioskId: 'k2', ...touched() })],
  ['R-06', 'users', 'admin', 'delete a user', DENIED, () => deleteDoc(doc(as('a1'), 'users/u2'))],
  // users/{uid}/notifications (mobile inbox)
  ['R-07', 'notifications', 'user', 'read own inbox item', ALLOWED, () => getDoc(doc(as('u1'), 'users/u1/notifications/n1'))],
  ['R-08', 'notifications', 'user', 'read another user inbox', DENIED, () => getDoc(doc(as('u2'), 'users/u1/notifications/n1'))],
  ['R-09', 'notifications', 'staff', 'create own inbox item', ALLOWED, () => setDoc(doc(as('s1'), 'users/s1/notifications/x'), note())],
  ['R-10', 'notifications', 'staff', 'write into a customer inbox', DENIED, () => setDoc(doc(as('s1'), 'users/u1/notifications/x'), note())],
  ['R-11', 'notifications', 'admin', 'create own inbox item', ALLOWED, () => setDoc(doc(as('a1'), 'users/a1/notifications/x'), note())],
  ['R-12', 'notifications', 'admin', 'read a customer inbox', DENIED, () => getDoc(doc(as('a1'), 'users/u1/notifications/n1'))],
  // kiosks/{id}
  ['R-13', 'kiosks', 'user', 'read a kiosk', ALLOWED, () => getDoc(doc(as('u1'), 'kiosks/k1'))],
  ['R-14', 'kiosks', 'user', 'close a kiosk', DENIED, () => updateDoc(doc(as('u1'), 'kiosks/k1'), { open: false, ...touched() })],
  ['R-15', 'kiosks', 'staff', 'close own kiosk', ALLOWED, () => updateDoc(doc(as('s1'), 'kiosks/k1'), { open: false, ...touched() })],
  ['R-16', 'kiosks', 'staff', 'close another kiosk', DENIED, () => updateDoc(doc(as('s1'), 'kiosks/k2'), { open: false, ...touched() })],
  ['R-17', 'kiosks', 'admin', 'create a kiosk', ALLOWED, () => setDoc(doc(as('a1'), 'kiosks/k9'), newKiosk())],
  ['R-18', 'kiosks', 'admin', 'delete a kiosk', DENIED, () => deleteDoc(doc(as('a1'), 'kiosks/k3'))],
  // kiosks/{id}/slots/{slotId}
  ['R-19', 'slots', 'user', 'book a slot (+1)', ALLOWED, () => updateDoc(doc(as('u1'), 'kiosks/k1/slots/sl1'), { booked: increment(1), ...touched() })],
  ['R-20', 'slots', 'user', 'create a slot', DENIED, () => setDoc(doc(as('u1'), 'kiosks/k1/slots/x'), { capacity: 9, booked: 0, ...created() })],
  ['R-21', 'slots', 'staff', 'create a slot at own kiosk', ALLOWED, () => setDoc(doc(as('s1'), 'kiosks/k1/slots/x'), { capacity: 5, booked: 0, ...created() })],
  ['R-22', 'slots', 'staff', 'create a slot at another kiosk', DENIED, () => setDoc(doc(as('s1'), 'kiosks/k2/slots/x'), { capacity: 5, booked: 0, ...created() })],
  ['R-23', 'slots', 'admin', 'change a slot capacity', ALLOWED, () => updateDoc(doc(as('a1'), 'kiosks/k1/slots/sl1'), { capacity: 4, ...touched() })],
  ['R-24', 'slots', 'admin', 'delete a slot', DENIED, () => deleteDoc(doc(as('a1'), 'kiosks/k1/slots/sl1'))],
  // menu_items/{id} (web management screen)
  ['R-25', 'menu_items', 'user', 'read the menu', ALLOWED, () => getDocs(query(collection(as('u1'), 'menu_items'), where('kioskId', '==', 'k1')))],
  ['R-26', 'menu_items', 'user', 'change a price', DENIED, () => updateDoc(doc(as('u1'), 'menu_items/k1-tacos'), { priceVnd: 1000, ...touched() })],
  ['R-27', 'menu_items', 'staff', 'archive an item of own kiosk', ALLOWED, () => updateDoc(doc(as('s1'), 'menu_items/k1-tacos'), { archived: true, ...touched() })],
  ['R-28', 'menu_items', 'staff', 'archive an item of another kiosk', DENIED, () => updateDoc(doc(as('s1'), 'menu_items/k2-banh-mi'), { archived: true, ...touched() })],
  ['R-29', 'menu_items', 'staff', 'archive with a non-boolean value', DENIED, () => updateDoc(doc(as('s1'), 'menu_items/k1-tacos'), { archived: 'yes', ...touched() })],
  ['R-30', 'menu_items', 'admin', 'create an item', ALLOWED, () => setDoc(doc(as('a1'), 'menu_items/k1-cafe'), newMenuItem())],
  ['R-31', 'menu_items', 'admin', 'delete an item', DENIED, () => deleteDoc(doc(as('a1'), 'menu_items/k1-tacos'))],
  // vouchers/{CODE}
  ['R-32', 'vouchers', 'user', 'read a voucher', ALLOWED, () => getDoc(doc(as('u1'), 'vouchers/BBSTUDENT'))],
  ['R-33', 'vouchers', 'user', 'create a voucher', DENIED, () => setDoc(doc(as('u1'), 'vouchers/FREE'), voucher(created()))],
  ['R-34', 'vouchers', 'staff', 'read a voucher', ALLOWED, () => getDoc(doc(as('s1'), 'vouchers/BBSTUDENT'))],
  ['R-35', 'vouchers', 'staff', 'switch a voucher off', DENIED, () => updateDoc(doc(as('s1'), 'vouchers/BBSTUDENT'), { active: false, ...touched() })],
  ['R-36', 'vouchers', 'admin', 'create a voucher', ALLOWED, () => setDoc(doc(as('a1'), 'vouchers/NEW10'), voucher(created()))],
  ['R-37', 'vouchers', 'admin', 'delete a voucher', DENIED, () => deleteDoc(doc(as('a1'), 'vouchers/BBSTUDENT'))],
  // carts/{uid}
  ['R-38', 'carts', 'user', 'read own cart', ALLOWED, () => getDoc(doc(as('u1'), 'carts/u1'))],
  ['R-39', 'carts', 'user', 'read another cart', DENIED, () => getDoc(doc(as('u2'), 'carts/u1'))],
  ['R-40', 'carts', 'staff', 'write own cart', ALLOWED, () => setDoc(doc(as('s1'), 'carts/s1'), { kioskId: 'k1', items: [], ...created() })],
  ['R-41', 'carts', 'staff', 'read a customer cart', DENIED, () => getDoc(doc(as('s1'), 'carts/u1'))],
  ['R-42', 'carts', 'admin', 'write own cart', ALLOWED, () => setDoc(doc(as('a1'), 'carts/a1'), { kioskId: 'k1', items: [], ...created() })],
  ['R-43', 'carts', 'admin', 'read a customer cart', DENIED, () => getDoc(doc(as('a1'), 'carts/u1'))],
  // orders/{id} (cross-role flow: mobile places, web approves or rejects)
  ['R-44', 'orders', 'user', 'place a pending order', ALLOWED, () => setDoc(doc(as('u1'), 'orders/n1'), newOrder())],
  ['R-45', 'orders', 'user', 'place an order already preparing', DENIED, () => setDoc(doc(as('u1'), 'orders/n2'), newOrder({ status: 'preparing' }))],
  ['R-46', 'orders', 'user', 'approve own order', DENIED, () => updateDoc(doc(as('u1'), 'orders/o1'), { status: 'preparing', acceptedAt: serverTimestamp(), ...touched() })],
  ['R-47', 'orders', 'staff', 'approve pending → preparing', ALLOWED, () => updateDoc(doc(as('s1'), 'orders/o2'), { status: 'preparing', acceptedAt: serverTimestamp(), readyBy: future, ...touched() })],
  ['R-48', 'orders', 'staff', 'reject pending → cancelled with a reason', ALLOWED, () => updateDoc(doc(as('s1'), 'orders/o1'), { status: 'cancelled', cancelledBy: 'staff', cancelReason: 'Hết nguyên liệu', cancelledAt: serverTimestamp(), ...touched() })],
  ['R-49', 'orders', 'staff', 'reject without a reason', DENIED, () => updateDoc(doc(as('s1'), 'orders/o1'), { status: 'cancelled', cancelledBy: 'staff', cancelledAt: serverTimestamp(), ...touched() })],
  ['R-50', 'orders', 'staff', 'approve an order of another kiosk', DENIED, () => updateDoc(doc(as('s1'), 'orders/o5'), { status: 'preparing', acceptedAt: serverTimestamp(), readyBy: future, ...touched() })],
  ['R-51', 'orders', 'admin', 'read an order of any kiosk', ALLOWED, () => getDoc(doc(as('a1'), 'orders/o5'))],
  ['R-52', 'orders', 'admin', 'delete an order', DENIED, () => deleteDoc(doc(as('a1'), 'orders/o5'))],
  // reviews/{orderId}_{itemId}
  ['R-53', 'reviews', 'user', 'review own delivered order', ALLOWED, () => setDoc(doc(as('u1'), 'reviews/o6_k1-tacos'), reviewOf('u1', 'o6'))],
  ['R-54', 'reviews', 'user', 'review a pending order', DENIED, () => setDoc(doc(as('u1'), 'reviews/o1_k1-tacos'), reviewOf('u1', 'o1'))],
  ['R-55', 'reviews', 'staff', 'read the reviews (dashboard average)', ALLOWED, () => getDocs(query(collection(as('s1'), 'reviews'), where('kioskId', '==', 'k1')))],
  ['R-56', 'reviews', 'staff', 'write a review for a customer', DENIED, () => setDoc(doc(as('s1'), 'reviews/o6_k1-tacos'), reviewOf('u1', 'o6'))],
  ['R-57', 'reviews', 'admin', 'read the reviews', ALLOWED, () => getDocs(collection(as('a1'), 'reviews'))],
  ['R-58', 'reviews', 'admin', 'delete a review', DENIED, () => deleteDoc(doc(as('a1'), 'reviews/o6_k1-tacos'))],
  // incidents/{orderId}
  ['R-59', 'incidents', 'user', 'read own incident', ALLOWED, () => getDoc(doc(as('u1'), 'incidents/o6'))],
  ['R-60', 'incidents', 'user', 'resolve own incident', DENIED, () => updateDoc(doc(as('u1'), 'incidents/o6'), { status: 'inProgress', ...touched() })],
  ['R-61', 'incidents', 'staff', 'take an incident of own kiosk', ALLOWED, () => updateDoc(doc(as('s1'), 'incidents/o6'), { status: 'inProgress', ...touched() })],
  ['R-62', 'incidents', 'staff', 'take it from another kiosk', DENIED, () => updateDoc(doc(as('s2'), 'incidents/o6'), { status: 'inProgress', ...touched() })],
  ['R-63', 'incidents', 'admin', 'reject an incident with a note', ALLOWED, () => updateDoc(doc(as('a1'), 'incidents/o6'), { status: 'resolved', resolution: 'rejected', resolutionNote: 'Đã giao đủ', resolvedAt: serverTimestamp(), handledBy: 'a1', ...touched() })],
  ['R-64', 'incidents', 'admin', 'delete an incident', DENIED, () => deleteDoc(doc(as('a1'), 'incidents/o6'))],
  // reports/{id} (Lab 3 PDF receipt metadata)
  ['R-65', 'reports', 'user', 'read own receipt metadata', ALLOWED, () => getDoc(doc(as('u1'), 'reports/r1'))],
  ['R-66', 'reports', 'user', 'save metadata as someone else', DENIED, () => setDoc(doc(as('u2'), 'reports/r2'), reportOf('u1'))],
  ['R-67', 'reports', 'staff', 'save own receipt metadata', ALLOWED, () => setDoc(doc(as('s1'), 'reports/r3'), reportOf('s1'))],
  ['R-68', 'reports', 'staff', 'read a customer receipt', DENIED, () => getDoc(doc(as('s1'), 'reports/r1'))],
  ['R-69', 'reports', 'admin', 'save own receipt metadata', ALLOWED, () => setDoc(doc(as('a1'), 'reports/r4'), reportOf('a1'))],
  ['R-70', 'reports', 'admin', 'edit a receipt', DENIED, () => updateDoc(doc(as('a1'), 'reports/r1'), { sizeKb: 1, ...touched() })],
  // announcements/{id} (web announcement form → mobile inbox)
  ['R-71', 'announcements', 'user', 'list published announcements', ALLOWED, () => getDocs(query(collection(as('u1'), 'announcements'), where('status', '==', 'published')))],
  ['R-72', 'announcements', 'user', 'read a draft', DENIED, () => getDoc(doc(as('u1'), 'announcements/draft'))],
  ['R-73', 'announcements', 'staff', 'read a published announcement', ALLOWED, () => getDoc(doc(as('s1'), 'announcements/pub'))],
  ['R-74', 'announcements', 'staff', 'publish an announcement', DENIED, () => setDoc(doc(as('s1'), 'announcements/s'), announcement({ createdBy: 's1' }))],
  ['R-75', 'announcements', 'admin', 'publish an announcement', ALLOWED, () => setDoc(doc(as('a1'), 'announcements/new'), announcement())],
  ['R-76', 'announcements', 'admin', 'archive an announcement', ALLOWED, () => updateDoc(doc(as('a1'), 'announcements/pub'), { status: 'archived', ...touched() })],
  ['R-77', 'announcements', 'admin', 'publish a 121-character title', DENIED, () => setDoc(doc(as('a1'), 'announcements/long'), announcement({ title: 'x'.repeat(121) }))],
  ['R-78', 'announcements', 'admin', 'publish with an unknown field', DENIED, () => setDoc(doc(as('a1'), 'announcements/odd'), announcement({ pinned: true }))],
  ['R-79', 'announcements', 'admin', 'change the author', DENIED, () => updateDoc(doc(as('a1'), 'announcements/pub'), { createdBy: 'u1', ...touched() })],
  ['R-80', 'announcements', 'admin', 'delete an announcement', DENIED, () => deleteDoc(doc(as('a1'), 'announcements/pub'))],
];

describe('Appendix B matrix (final assignment)', () => {
  beforeEach(seedMatrix);
  for (const [id, coll, role, operation, expected, run] of MATRIX) {
    test(`${id} ${coll} · ${role} · ${operation} → ${expected}`, async () => {
      await (expected === ALLOWED ? assertSucceeds(run()) : assertFails(run()));
    });
  }
});
