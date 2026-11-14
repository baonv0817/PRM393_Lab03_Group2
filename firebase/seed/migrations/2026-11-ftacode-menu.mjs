import { menuItemsFor } from '../data.mjs';

export const MIGRATION_ID = '2026-11-t32-ftacode-menu';

export function planMenu(kiosks, existing) {
  const desired = new Map(kiosks.flatMap(k => menuItemsFor({ ...k, open: true }))
    .map(({ id, ...data }) => [id, { ...data, archived: false, optionGroups: data.optionGroups ?? [] }]));
  const ops = [];
  for (const [id, data] of desired) {
    const old = existing.get(id);
    if (!old || Object.keys(data).some(k => JSON.stringify(old[k]) !== JSON.stringify(data[k]))) {
      ops.push({ kind: 'set', path: `menu_items/${id}`, data, create: !old });
    }
  }
  for (const [id, data] of existing) {
    if (kiosks.some(k => k.id === data.kioskId) && !desired.has(id) && data.archived !== true) {
      ops.push({ kind: 'set', path: `menu_items/${id}`, data: { archived: true }, create: false });
    }
  }
  return { ops, warnings: [], counts: { upsert: ops.filter(x => 'name' in x.data).length, archive: ops.filter(x => !('name' in x.data)).length } };
}

export async function plan(db) {
  const [kiosks, menu] = await Promise.all([db.collection('kiosks').get(), db.collection('menu_items').get()]);
  if (kiosks.empty) throw new Error('No existing kiosks; seed kiosk setup before applying this menu migration.');
  return planMenu(kiosks.docs.map(d => ({ ...d.data(), id: d.id })), new Map(menu.docs.map(d => [d.id, d.data()])));
}

export async function apply(db, admin, result) {
  for (let offset = 0; offset < result.ops.length; offset += 400) {
    const batch = db.batch();
    for (const op of result.ops.slice(offset, offset + 400)) {
      const stamp = admin.firestore.FieldValue.serverTimestamp();
      batch.set(db.doc(op.path), { ...op.data, updatedAt: stamp, ...(op.create ? { createdAt: stamp } : {}) }, { merge: true });
    }
    await batch.commit();
  }
  await db.doc(`_migrations/${MIGRATION_ID}`).set({ appliedAt: admin.firestore.FieldValue.serverTimestamp(), changes: result.ops.length, counts: result.counts });
}

export async function verify(db) {
  return (await plan(db)).ops.map(op => `${op.path}: does not match FtaCode menu`);
}
