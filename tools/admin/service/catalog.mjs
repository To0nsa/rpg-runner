import { writeFile, readFile } from 'node:fs/promises';
import { inboxGiftCatalog, inboxGiftCatalogHash } from '../../../functions/lib/inbox/gifts.js';
import { knownCharacterIds } from '../../../functions/lib/ownership/defaults.js';
// Offline export only: activation remains an authorized environment release operation.
const catalog = { enabled: true, catalogHash: inboxGiftCatalogHash, entries: inboxGiftCatalog, characters: knownCharacterIds };
const output = `${JSON.stringify(catalog, null, 2)}\n`;
const fixture = new URL('../test/fixtures/catalog.json', import.meta.url);
if (process.argv[2] === '--write-fixture') await writeFile(fixture, output);
else if (process.argv[2] === '--check-fixture') {
  if (await readFile(fixture, 'utf8') !== output) throw new Error('Admin catalog fixture is stale. Build functions and run catalog.mjs --write-fixture.');
} else if (process.argv[2] === '--activation-record') {
  console.log(JSON.stringify({ schemaVersion: 1, enabled: true, catalogHash: inboxGiftCatalogHash }, null, 2));
} else throw new Error('Use --write-fixture, --check-fixture or --activation-record. No cloud writes are performed.');
