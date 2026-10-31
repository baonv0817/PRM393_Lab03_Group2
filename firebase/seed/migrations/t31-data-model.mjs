// T31 data model hardening: moves documents written with the old structure to the one in
// docs/data-model.md. Idempotent: every document is rewritten to its target shape, and a document already
// in that shape produces no change, so a second run plans nothing.
//
// What changes:
//  - every document: createdAt/updatedAt, taken from the document's own create/update time when missing;
//  - menu_items: dishId (from the id {kioskId}-{dishId}), category Vietnamese label -> food/drink/other;
//  - vouchers: discountVnd/percent/maxDiscountVnd -> discount {type: fixed|percent, ...};
//  - users/{uid}/favorites: re-keyed from the menu item id to the dishId (duplicates of a dish merge),
//    addedAt -> createdAt, itemId/kioskId dropped;
//  - reviews: dishId;
//  - incidents: re-keyed to the order id, snake_case type/status -> camelCase, a free-text resolution
//    moves to resolutionNote.
import { dumpAll, toJson } from '../firestore-json.mjs';

export const MIGRATION_ID = '2026-11-t31-data-model';

const FOOD_LABELS = new Set(['tacos', 'mì trộn', 'cơm', 'bánh mì', 'ăn vặt']);
const DRINK_LABELS = new Set(['đồ uống']);
const CATEGORIES = ['food', 'drink', 'other'];
const CAMEL = { wrong_item: 'wrongItem', missing_item: 'missingItem', in_progress: 'inProgress' };
const RESOLUTIONS = ['refunded', 'rejected'];

export function categoryOf(label) {
  if (CATEGORIES.includes(label)) return label;
  const key = String(label ?? '').trim().toLowerCase();
  if (DRINK_LABELS.has(key)) return 'drink';
  if (FOOD_LABELS.has(key)) return 'food';
  return 'other';
}

export function dishIdOf(menuItemId, data) {
  if (data?.dishId) return data.dishId;
  const prefix = `${data?.kioskId}-`;
  return data?.kioskId && menuItemId.startsWith(prefix) ? menuItemId.slice(prefix.length) : menuItemId;
}

function without(data, ...keys) {
  const copy = { ...data };
  for (const key of keys) delete copy[key];
  return copy;
}

function sortedJson(value, admin) {
  const sort = (v) =>
    Array.isArray(v) ? v.map(sort)
    : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sort(v[k])]))
    : v;
  return JSON.stringify(sort(toJson(value, admin)));
}

async function allSnapshots(db) {
  const out = [];
  async function walk(collections) {
    for (const collection of collections) {
      if (collection.id === '_migrations') continue;
      for (const snap of (await collection.get()).docs) {
        out.push(snap);
        await walk(await snap.ref.listCollections());
      }
    }
  }
  await walk(await db.listCollections());
  return out;
}

/** Plans the migration. Returns { ops, warnings, counts }; nothing is written. */
export async function plan(db, admin) {
  const { Timestamp } = admin.firestore;
  const snaps = await allSnapshots(db);
  const existing = new Set(snaps.map((s) => s.ref.path));
  const warnings = [];

  const menuById = new Map(snaps.filter((s) => s.ref.parent.path === 'menu_items').map((s) => [s.id, s.data()]));
  const kioskIds = snaps.filter((s) => s.ref.parent.path === 'kiosks').map((s) => s.id);
  const dishOfItem = (itemId, kioskId) => {
    const menu = menuById.get(itemId);
    if (menu) return dishIdOf(itemId, menu);
    const kiosk = kioskId ?? kioskIds.find((k) => itemId.startsWith(`${k}-`));
    return dishIdOf(itemId, { kioskId: kiosk });
  };

  const stamped = (snap, data, createdAt) => ({
    ...data,
    createdAt: data.createdAt instanceof Timestamp ? data.createdAt : createdAt ?? snap.createTime,
    updatedAt: data.updatedAt instanceof Timestamp ? data.updatedAt : snap.updateTime,
  });

  function target(snap) {
    const data = snap.data();
    const collection = snap.ref.parent.id;
    const underUser = snap.ref.parent.parent?.parent.id === 'users';

    if (collection === 'menu_items' && snap.ref.parent.path === 'menu_items') {
      return { path: snap.ref.path, data: stamped(snap, {
        ...data, dishId: dishIdOf(snap.id, data), category: categoryOf(data.category),
      }) };
    }

    if (collection === 'vouchers' && snap.ref.parent.path === 'vouchers') {
      if (!/^[A-Z0-9]{3,20}$/.test(snap.id)) warnings.push(`${snap.ref.path}: id is not an upper-case code`);
      let discount = data.discount;
      if (!discount) {
        if (data.percent > 0 && data.maxDiscountVnd > 0) {
          discount = { type: 'percent', percent: data.percent, maxVnd: data.maxDiscountVnd };
        } else if (data.discountVnd > 0) {
          discount = { type: 'fixed', amountVnd: data.discountVnd };
        } else {
          warnings.push(`${snap.ref.path}: no usable discountVnd/percent+maxDiscountVnd, left unchanged`);
          return { path: snap.ref.path, data: stamped(snap, data) };
        }
      }
      return { path: snap.ref.path, data: stamped(snap, {
        ...without(data, 'discountVnd', 'percent', 'maxDiscountVnd'), discount,
      }) };
    }

    if (collection === 'favorites' && underUser) {
      const dishId = data.dishId ?? dishOfItem(data.itemId ?? snap.id, data.kioskId);
      const menu = menuById.get(data.itemId ?? snap.id);
      const next = without(data, 'itemId', 'kioskId', 'addedAt');
      next.dishId = dishId;
      if (next.category == null && menu?.category != null) next.category = categoryOf(menu.category);
      else if (next.category != null) next.category = categoryOf(next.category);
      return { path: `${snap.ref.parent.path}/${dishId}`, data: stamped(snap, next, data.addedAt), merge: true };
    }

    if (collection === 'reviews' && snap.ref.parent.path === 'reviews') {
      return { path: snap.ref.path, data: stamped(snap, {
        ...data, dishId: data.dishId ?? dishOfItem(data.itemId, data.kioskId),
      }) };
    }

    if (collection === 'incidents' && snap.ref.parent.path === 'incidents') {
      const next = { ...data, type: CAMEL[data.type] ?? data.type, status: CAMEL[data.status] ?? data.status };
      if (next.resolution != null && !RESOLUTIONS.includes(next.resolution)) {
        next.resolutionNote = next.resolutionNote ?? String(next.resolution);
        delete next.resolution;
        warnings.push(`${snap.ref.path}: free-text resolution moved to resolutionNote; set refunded/rejected by hand`);
      }
      if (!data.orderId) {
        warnings.push(`${snap.ref.path}: no orderId, kept under its old id`);
        return { path: snap.ref.path, data: stamped(snap, next) };
      }
      return { path: `incidents/${data.orderId}`, data: stamped(snap, next) };
    }

    return { path: snap.ref.path, data: stamped(snap, data) };
  }

  const ops = [];
  const claimed = new Map();
  for (const snap of snaps) {
    const { path, data, merge } = target(snap);
    const moved = path !== snap.ref.path;
    if (moved) {
      const owner = claimed.get(path) ?? (existing.has(path) ? path : null);
      if (owner) {
        if (merge) {
          ops.push({ kind: 'delete', path: snap.ref.path, reason: `duplicate of ${path}` });
        } else {
          warnings.push(`${snap.ref.path}: ${path} already exists, left in place (resolve by hand)`);
        }
        continue;
      }
      claimed.set(path, snap.ref.path);
      ops.push({ kind: 'move', from: snap.ref.path, path, data });
    } else if (sortedJson(data, admin) !== sortedJson(snap.data(), admin)) {
      claimed.set(path, path);
      ops.push({ kind: 'set', path, data });
    } else {
      claimed.set(path, path);
    }
  }

  const counts = {};
  for (const op of ops) {
    const collection = (op.from ?? op.path).split('/').at(-2);
    counts[collection] = (counts[collection] ?? 0) + 1;
  }
  return { ops, warnings, counts };
}

/** Applies a plan and records it in `_migrations` (client rules deny that collection). */
export async function apply(db, admin, { ops, warnings, counts }) {
  const writer = db.bulkWriter();
  for (const op of ops) {
    if (op.kind === 'delete') writer.delete(db.doc(op.path));
    if (op.kind === 'set') writer.set(db.doc(op.path), op.data);
    if (op.kind === 'move') {
      writer.set(db.doc(op.path), op.data);
      writer.delete(db.doc(op.from));
    }
  }
  await writer.close();
  await db.doc(`_migrations/${MIGRATION_ID}`).set({
    appliedAt: admin.firestore.FieldValue.serverTimestamp(),
    changes: ops.length,
    counts,
    warnings,
  });
}

/** Checks the migrated database against the shapes the new rules require. Returns a list of problems. */
export async function verify(db, admin) {
  const problems = [];
  const documents = await dumpAll(db, admin);
  for (const [path, data] of Object.entries(documents)) {
    if (path.startsWith('_migrations/')) continue;
    const parts = path.split('/');
    const collection = parts.at(-2);
    const id = parts.at(-1);
    const isTs = (v) => v?.__type === 'timestamp';
    if (!isTs(data.createdAt) || !isTs(data.updatedAt)) problems.push(`${path}: missing createdAt/updatedAt`);

    if (parts.length === 2 && collection === 'menu_items') {
      if (!CATEGORIES.includes(data.category)) problems.push(`${path}: category ${data.category}`);
      if (!data.dishId || id !== `${data.kioskId}-${data.dishId}`) {
        problems.push(`${path}: id is not {kioskId}-{dishId}`);
      }
    }
    if (parts.length === 2 && collection === 'vouchers') {
      const x = data.discount;
      const keys = x && Object.keys(x).sort().join();
      const fixed = x?.type === 'fixed' && keys === 'amountVnd,type' && x.amountVnd > 0;
      const percent = x?.type === 'percent' && keys === 'maxVnd,percent,type' && x.percent >= 1 && x.percent <= 100
        && x.maxVnd > 0;
      if (!fixed && !percent) problems.push(`${path}: discount is not fixed/percent`);
      for (const legacy of ['discountVnd', 'percent', 'maxDiscountVnd']) {
        if (legacy in data) problems.push(`${path}: legacy field ${legacy}`);
      }
    }
    if (parts.length === 4 && parts[0] === 'users' && collection === 'favorites' && data.dishId !== id) {
      problems.push(`${path}: favorite id is not its dishId`);
    }
    if (parts.length === 2 && collection === 'reviews' && !data.dishId) problems.push(`${path}: missing dishId`);
    if (parts.length === 2 && collection === 'incidents') {
      if (id !== data.orderId) problems.push(`${path}: id is not the orderId`);
      if (!['missingItem', 'wrongItem', 'quality', 'late', 'other'].includes(data.type)) {
        problems.push(`${path}: type ${data.type}`);
      }
      if (!['open', 'inProgress', 'resolved'].includes(data.status)) problems.push(`${path}: status ${data.status}`);
    }
  }
  return problems;
}
