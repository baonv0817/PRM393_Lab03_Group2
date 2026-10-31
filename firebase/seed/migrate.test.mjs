// Runs the T31 migration against documents in the old structure on the Emulator:
//   npm run test:migrate
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { connect } from './admin.mjs';
import { dumpAll, restoreAll } from './firestore-json.mjs';
import { MIGRATION_ID, apply, categoryOf, dishIdOf, plan, verify } from './migrations/t31-data-model.mjs';

const { admin, db } = connect([]);
const { Timestamp } = admin.firestore;
const at = (iso) => Timestamp.fromDate(new Date(iso));
const FAR = at('2100-01-01T00:00:00Z');

const OLD = {
  'kiosks/q9-t2': { name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 6 },
  'kiosks/q9-t4': { name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 10 },
  'kiosks/q9-t2/slots/20261102-0845': {
    startAt: at('2026-11-02T01:45:00Z'), endAt: at('2026-11-02T02:00:00Z'), capacity: 15, booked: 1,
  },
  'menu_items/q9-t2-tacos-bo': {
    kioskId: 'q9-t2', name: 'Tacos Bò', searchName: 'tacos bo', category: 'Tacos', priceVnd: 39000, prepMinutes: 4,
    soldOut: false,
  },
  'menu_items/q9-t2-tra-dao': {
    kioskId: 'q9-t2', name: 'Trà Đào', searchName: 'tra dao', category: 'Đồ uống', priceVnd: 20000, prepMinutes: 2,
    soldOut: false,
  },
  'menu_items/q9-t4-tra-dao': {
    kioskId: 'q9-t4', name: 'Trà Đào', searchName: 'tra dao', category: 'Đồ uống', priceVnd: 20000, prepMinutes: 2,
    soldOut: true,
  },
  'menu_items/q9-t4-flan': {
    kioskId: 'q9-t4', name: 'Bánh Flan', searchName: 'banh flan', category: 'Tráng miệng', priceVnd: 15000,
    prepMinutes: 1, soldOut: false,
  },
  'vouchers/BBSTUDENT': { title: 'Giảm 10K', discountVnd: 10000, minOrderVnd: 40000, expiresAt: FAR, active: true },
  'vouchers/GIOVANG': {
    title: 'Giờ Vàng', discountVnd: 0, percent: 15, maxDiscountVnd: 15000, minOrderVnd: 30000, expiresAt: FAR,
    active: true,
  },
  'users/u1': { role: 'user', displayName: 'Nguyễn Minh Quân', email: 'u1@example.com' },
  'users/u1/favorites/q9-t2-tra-dao': {
    itemId: 'q9-t2-tra-dao', kioskId: 'q9-t2', name: 'Trà Đào', priceVnd: 20000, addedAt: at('2026-10-30T03:00:00Z'),
  },
  'users/u1/favorites/q9-t4-tra-dao': {
    itemId: 'q9-t4-tra-dao', kioskId: 'q9-t4', name: 'Trà Đào', priceVnd: 20000, addedAt: at('2026-10-30T04:00:00Z'),
  },
  'users/u1/favorites/q9-t2-tacos-bo': {
    itemId: 'q9-t2-tacos-bo', kioskId: 'q9-t2', name: 'Tacos Bò', priceVnd: 39000, addedAt: at('2026-10-30T05:00:00Z'),
  },
  'users/u1/notifications/n1': {
    title: 'Đơn đã sẵn sàng', body: 'Mời bạn tới quầy', orderId: 'o1', read: false,
    createdAt: at('2026-10-30T06:00:00Z'),
  },
  'carts/u1': {
    kioskId: 'q9-t2', items: [{ itemId: 'q9-t2-tacos-bo', name: 'Tacos Bò', priceVnd: 39000, quantity: 1, note: '' }],
  },
  'orders/o1': {
    uid: 'u1', kioskId: 'q9-t2', status: 'delivered', items: [], subtotalVnd: 39000, discountVnd: 0, totalVnd: 39000,
    paymentMethod: 'cash', paymentStatus: 'paid', pickupCode: '482915', createdAt: at('2026-10-30T02:00:00Z'),
  },
  'reviews/o1_q9-t2-tacos-bo': {
    orderId: 'o1', itemId: 'q9-t2-tacos-bo', kioskId: 'q9-t2', uid: 'u1', rating: 5,
    createdAt: at('2026-10-30T07:00:00Z'),
  },
  'incidents/auto123': {
    orderId: 'o1', kioskId: 'q9-t2', uid: 'u1', type: 'missing_item', status: 'in_progress', description: 'Thiếu nước',
    resolution: 'Đã gọi khách', createdAt: at('2026-10-30T08:00:00Z'),
  },
};

async function clear() {
  for (const collection of await db.listCollections()) await db.recursiveDelete(collection);
}

test('category labels and dish ids', () => {
  assert.equal(categoryOf('Tacos'), 'food');
  assert.equal(categoryOf(' Đồ uống '), 'drink');
  assert.equal(categoryOf('Tráng miệng'), 'other');
  assert.equal(categoryOf('drink'), 'drink');
  assert.equal(dishIdOf('q9-t2-tacos-bo', { kioskId: 'q9-t2' }), 'tacos-bo');
  assert.equal(dishIdOf('x', { kioskId: 'q9-t2', dishId: 'kept' }), 'kept');
});

test('T31 migration on old-structure data', async (t) => {
  await clear();
  const writer = db.bulkWriter();
  for (const [path, data] of Object.entries(OLD)) writer.set(db.doc(path), data);
  await writer.close();
  const before = await dumpAll(db, admin);
  const get = async (path) => (await db.doc(path).get()).data();

  await t.test('a dry run plans changes and writes nothing', async () => {
    const result = await plan(db, admin);
    assert.ok(result.ops.length > 0);
    assert.deepEqual(await dumpAll(db, admin), before);
  });

  await t.test('apply moves every document to the new structure', async () => {
    const result = await plan(db, admin);
    assert.ok(result.warnings.some((w) => w.includes('resolutionNote')));
    await apply(db, admin, result);
    assert.deepEqual(await verify(db, admin), []);

    const tacos = await get('menu_items/q9-t2-tacos-bo');
    assert.equal(tacos.dishId, 'tacos-bo');
    assert.equal(tacos.category, 'food');
    assert.equal((await get('menu_items/q9-t4-tra-dao')).category, 'drink');
    assert.equal((await get('menu_items/q9-t4-tra-dao')).soldOut, true);
    assert.equal((await get('menu_items/q9-t4-flan')).category, 'other');

    const student = await get('vouchers/BBSTUDENT');
    assert.deepEqual(student.discount, { type: 'fixed', amountVnd: 10000 });
    assert.equal('discountVnd' in student, false);
    assert.deepEqual((await get('vouchers/GIOVANG')).discount, { type: 'percent', percent: 15, maxVnd: 15000 });

    const favorites = (await db.collection('users/u1/favorites').get()).docs.map((d) => d.id).sort();
    assert.deepEqual(favorites, ['tacos-bo', 'tra-dao']);
    const tea = await get('users/u1/favorites/tra-dao');
    assert.equal(tea.dishId, 'tra-dao');
    assert.equal(tea.category, 'drink');
    assert.equal('itemId' in tea || 'kioskId' in tea || 'addedAt' in tea, false);

    assert.equal((await get('reviews/o1_q9-t2-tacos-bo')).dishId, 'tacos-bo');

    assert.equal((await db.doc('incidents/auto123').get()).exists, false);
    const incident = await get('incidents/o1');
    assert.equal(incident.type, 'missingItem');
    assert.equal(incident.status, 'inProgress');
    assert.equal(incident.resolutionNote, 'Đã gọi khách');
    assert.equal('resolution' in incident, false);
    assert.ok(incident.createdAt.isEqual(at('2026-10-30T08:00:00Z')));

    const slot = await get('kiosks/q9-t2/slots/20261102-0845');
    assert.ok(slot.createdAt instanceof Timestamp && slot.updatedAt instanceof Timestamp);
    assert.equal(slot.booked, 1);
    assert.ok((await get('orders/o1')).createdAt.isEqual(at('2026-10-30T02:00:00Z')));
    assert.ok((await get(`_migrations/${MIGRATION_ID}`)).changes > 0);
  });

  await t.test('a second run changes nothing', async () => {
    assert.deepEqual((await plan(db, admin)).ops, []);
  });

  await t.test('restore with prune brings back exactly the old data', async () => {
    await restoreAll(db, admin, before, { prune: true });
    assert.deepEqual(await dumpAll(db, admin), before);
  });
});
