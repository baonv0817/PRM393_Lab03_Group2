import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SOURCE, MENU, OPTIONS } from './ftacode-catalog.mjs';
import { planMenu } from './migrations/2026-11-ftacode-menu.mjs';

test('catalog retains source prices and pictures without inventing unavailable products', () => {
  assert.equal(MENU.length, 20);
  assert.equal(new Set(MENU.map(x => x.slug)).size, 20);
  MENU.forEach((m, i) => {
    assert.equal(m.priceVnd, SOURCE.items[i].priceVnd);
    assert.equal(m.imageUrl, SOURCE.items[i].imageUrl);
    assert.ok(m.priceVnd > 0);
  });
  assert.equal(MENU.filter(x => !x.imageUrl).length, 2);
  assert.deepEqual(OPTIONS['ftacode-mi-1'][0].choices.map(x => x.extraVnd), [7000, 10000, 3000, 7000]);
});

test('migration archives old menu without deleting history and is idempotent', () => {
  const old = { kioskId: 'k1', dishId: 'com-ga', name: 'Old rice', createdAt: 'keep' };
  const data = new Map([['k1-com-ga', old], ['unrelated', { kioskId: 'other' }]]);
  const first = planMenu([{ id: 'k1' }], data);
  assert.deepEqual(first.counts, { upsert: 20, archive: 1 });
  assert.ok(first.ops.every(x => x.kind === 'set' && x.path.startsWith('menu_items/')));
  first.ops.forEach(op => { const id = op.path.split('/')[1]; data.set(id, { ...data.get(id), ...op.data }); });
  assert.equal(data.get('k1-com-ga').createdAt, 'keep');
  assert.equal(data.get('k1-com-ga').archived, true);
  assert.equal(data.get('unrelated').archived, undefined);
  assert.equal(planMenu([{ id: 'k1' }], data).ops.length, 0);
});
