// Run after `corepack pnpm --dir functions build`; consumed by TypeScript and Dart tests.
import { writeFileSync } from 'node:fs';
import { starterCanonicalState } from '../../lib/ownership/defaults.js';
const state = starterCanonicalState('default', 'catalogue-test');
writeFileSync(new URL('./town_catalogue.json', import.meta.url),
  `${JSON.stringify(state.progression.store, null, 2)}\n`);
