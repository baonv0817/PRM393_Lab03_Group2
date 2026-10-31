// Lossless JSON for Firestore documents, shared by backup.mjs and restore.mjs. Timestamps and
// document references become tagged objects so a restore writes back exactly the same values.

export function toJson(value, admin) {
  const { Timestamp, DocumentReference, GeoPoint } = admin.firestore;
  if (value instanceof Timestamp) {
    return { __type: 'timestamp', seconds: value.seconds, nanoseconds: value.nanoseconds };
  }
  if (value instanceof DocumentReference) return { __type: 'ref', path: value.path };
  if (value instanceof GeoPoint) return { __type: 'geo', latitude: value.latitude, longitude: value.longitude };
  if (Array.isArray(value)) return value.map((v) => toJson(v, admin));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, toJson(v, admin)]));
  }
  return value;
}

export function fromJson(value, admin, db) {
  const { Timestamp, GeoPoint } = admin.firestore;
  if (Array.isArray(value)) return value.map((v) => fromJson(v, admin, db));
  if (value && typeof value === 'object') {
    if (value.__type === 'timestamp') return new Timestamp(value.seconds, value.nanoseconds);
    if (value.__type === 'ref') return db.doc(value.path);
    if (value.__type === 'geo') return new GeoPoint(value.latitude, value.longitude);
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, fromJson(v, admin, db)]));
  }
  return value;
}

/** Every document of the database, subcollections included, as { path: data }. */
export async function dumpAll(db, admin) {
  const out = {};
  async function walk(collections) {
    for (const collection of collections) {
      for (const doc of (await collection.get()).docs) {
        out[doc.ref.path] = toJson(doc.data(), admin);
        await walk(await doc.ref.listCollections());
      }
      for (const ref of await collection.listDocuments()) {
        if (!(ref.path in out)) await walk(await ref.listCollections());
      }
    }
  }
  await walk(await db.listCollections());
  return out;
}

/**
 * Writes `documents` (from dumpAll) back. With `prune`, documents that are not in the backup are deleted
 * inside the same top-level collections, plus every `_migrations` record.
 */
export async function restoreAll(db, admin, documents, { prune = false } = {}) {
  const writer = db.bulkWriter();
  let deleted = 0;
  if (prune) {
    const tops = new Set([...Object.keys(documents).map((p) => p.split('/')[0]), '_migrations']);
    for (const path of Object.keys(await dumpAll(db, admin))) {
      if (tops.has(path.split('/')[0]) && !(path in documents)) {
        writer.delete(db.doc(path));
        deleted++;
      }
    }
  }
  for (const [path, data] of Object.entries(documents)) writer.set(db.doc(path), fromJson(data, admin, db));
  await writer.close();
  return { written: Object.keys(documents).length, deleted };
}
