// Runs the T31 data migration. A dry run by default: it prints what would change and writes nothing.
//
//   Dry run:  node migrate.mjs --project=breakbite-1315b --yes
//   Apply:    node migrate.mjs --project=breakbite-1315b --yes --apply --backup=<file from backup.mjs>
//
// --apply on a real project requires a backup of that same project taken in the last 24 hours.
import { existsSync, readFileSync } from 'node:fs';

import { connect } from './admin.mjs';
import { MIGRATION_ID, apply, plan, verify } from './migrations/t31-data-model.mjs';

const argv = process.argv.slice(2);
const doApply = argv.includes('--apply');
const { admin, db, projectId, emulator } = connect(argv);

if (doApply && !emulator) {
  const backupPath = argv.find((a) => a.startsWith('--backup='))?.slice(9);
  if (!backupPath || !existsSync(backupPath)) {
    console.error('--apply needs --backup=<file>: run backup.mjs first.');
    process.exit(1);
  }
  const backup = JSON.parse(readFileSync(backupPath, 'utf8'));
  const ageHours = (Date.now() - Date.parse(backup.takenAt)) / 3600e3;
  if (backup.projectId !== projectId || !(ageHours < 24)) {
    console.error(`The backup must be of ${projectId} and newer than 24 hours.`);
    console.error(`It is of ${backup.projectId}, taken ${ageHours.toFixed(1)} hours ago.`);
    process.exit(1);
  }
}

const result = await plan(db, admin);
const where = `${projectId}${emulator ? ' (emulator)' : ''}`;
console.log(`${MIGRATION_ID} on ${where}: ${result.ops.length} changes`, result.counts);
for (const op of result.ops.slice(0, 40)) {
  console.log(`  ${op.kind.padEnd(6)} ${op.from ? `${op.from} -> ` : ''}${op.path}`);
}
if (result.ops.length > 40) console.log(`  ... and ${result.ops.length - 40} more`);
for (const w of result.warnings) console.warn(`  WARNING ${w}`);

if (!doApply) {
  console.log('Dry run: nothing written. Add --apply to write.');
  process.exit(0);
}

await apply(db, admin, result);
const problems = await verify(db, admin);
for (const p of problems) console.error(`  PROBLEM ${p}`);
const again = await plan(db, admin);
console.log(`Applied. Verify: ${problems.length} problems. A second run would change ${again.ops.length} documents.`);
process.exit(problems.length || again.ops.length ? 1 : 0);
