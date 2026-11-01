import { existsSync, readFileSync } from 'node:fs';

import { connect } from './admin.mjs';
import { MIGRATIONS } from './migrations/index.mjs';

const argv = process.argv.slice(2);
const doApply = argv.includes('--apply');
const showStatus = argv.includes('--status');
const onlyId = argv.find((a) => a.startsWith('--only='))?.slice(7);
const { admin, db, projectId, emulator } = connect(argv);
const where = `${projectId}${emulator ? ' (emulator)' : ''}`;

const appliedAt = async (id) => {
  const marker = await db.doc(`_migrations/${id}`).get();
  return marker.exists ? (marker.get('appliedAt')?.toDate()?.toISOString() ?? 'yes') : null;
};

if (showStatus) {
  console.log(`Migrations on ${where}:`);
  for (const migration of MIGRATIONS) {
    const at = await appliedAt(migration.MIGRATION_ID);
    console.log(`  ${at ? 'applied' : 'PENDING'}  ${migration.MIGRATION_ID}${at ? `  ${at}` : ''}`);
  }
  process.exit(0);
}

let selected;
if (onlyId) {
  selected = MIGRATIONS.filter((m) => m.MIGRATION_ID === onlyId);
  if (selected.length === 0) {
    console.error(`Unknown migration ${onlyId}. Known: ${MIGRATIONS.map((m) => m.MIGRATION_ID).join(', ')}`);
    process.exit(1);
  }
} else {
  selected = [];
  for (const migration of MIGRATIONS) {
    if (!(await appliedAt(migration.MIGRATION_ID))) selected.push(migration);
  }
}

if (selected.length === 0) {
  console.log(`Up to date: all ${MIGRATIONS.length} migrations are applied on ${where}.`);
  process.exit(0);
}

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

if (!doApply && selected.length > 1) {
  console.log(`${selected.length} pending migrations. Each dry run reads today's data, before the earlier ones apply.`);
}

for (const migration of selected) {
  const { MIGRATION_ID, apply, plan, verify } = migration;
  const result = await plan(db, admin);
  console.log(`${MIGRATION_ID} on ${where}: ${result.ops.length} changes`, result.counts);
  for (const op of result.ops.slice(0, 40)) {
    console.log(`  ${op.kind.padEnd(6)} ${op.from ? `${op.from} -> ` : ''}${op.path}`);
  }
  if (result.ops.length > 40) console.log(`  ... and ${result.ops.length - 40} more`);
  for (const w of result.warnings) console.warn(`  WARNING ${w}`);
  if (!doApply) continue;

  await apply(db, admin, result);
  const problems = await verify(db, admin);
  for (const p of problems) console.error(`  PROBLEM ${p}`);
  const again = await plan(db, admin);
  console.log(`Applied. Verify: ${problems.length} problems. A second run would change ${again.ops.length} documents.`);
  if (problems.length || again.ops.length) process.exit(1);
}

if (!doApply) console.log('Dry run: nothing written. Add --apply to write.');
process.exit(0);
