// Rollback: writes a backup from backup.mjs back exactly as it was. With --prune it also deletes
// documents that are not in the backup inside the same top-level collections (for example the
// documents a migration moved to a new id) and the `_migrations` records.
//
//   node restore.mjs --from=D:/backups/breakbite.json --project=breakbite-1315b --yes [--prune]
import { readFileSync } from 'node:fs';

import { connect } from './admin.mjs';
import { restoreAll } from './firestore-json.mjs';

const argv = process.argv.slice(2);
const from = argv.find((a) => a.startsWith('--from='))?.slice(7);
if (!from) {
  console.error('Usage: node restore.mjs --from=<backup.json> --project=<id> --yes [--prune]');
  process.exit(1);
}
const { admin, db, projectId, emulator } = connect(argv);
const backup = JSON.parse(readFileSync(from, 'utf8'));
if (backup.projectId !== projectId && !emulator) {
  console.error(`The backup is from ${backup.projectId}, not ${projectId}. Refusing to restore.`);
  process.exit(1);
}

const result = await restoreAll(db, admin, backup.documents, { prune: argv.includes('--prune') });
console.log(`Restored ${projectId} from ${from}:`, result);
