// Saves every document of the project (subcollections included) to one JSON file, outside the repo.
// Spark cannot use `gcloud firestore export` (it needs a Cloud Storage bucket, i.e. Blaze), so this
// is the backup to take before any migration. Read-only.
//
//   node backup.mjs --project=breakbite-1315b --yes [--out=D:/backups/breakbite.json]
import { mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

import { connect } from './admin.mjs';
import { dumpAll } from './firestore-json.mjs';

const argv = process.argv.slice(2);
const { admin, db, projectId } = connect(argv);

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const out = argv.find((a) => a.startsWith('--out='))?.slice(6)
  ?? join(homedir(), 'breakbite-backups', `${projectId}-${stamp}.json`);

const documents = await dumpAll(db, admin);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ projectId, takenAt: new Date().toISOString(), documents }, null, 1));

const perCollection = {};
for (const path of Object.keys(documents)) {
  const top = path.split('/')[0];
  perCollection[top] = (perCollection[top] ?? 0) + 1;
}
console.log(`Backup of ${projectId}: ${Object.keys(documents).length} documents`, perCollection);
console.log(`Saved to ${out} (keep it outside the repo; it contains personal data).`);
