import { execFileSync } from 'node:child_process';
import { readFileSync, realpathSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Leave room below Codex's default 32 KiB for separators and host guidance.
const chainBudget = 28 * 1024;
const rootBudget = 10 * 1024;
const indexPath = '.agent/README.md';
const contractPath = 'docs/tdd/agent_orchestration.md';
const isInstruction = (name) => /(^|\/)AGENTS(?:\.override)?\.md$/.test(name);
const isGuidance = (name) => isInstruction(name)
  || (name.startsWith('.agent/') && name.endsWith('.md'))
  || name === contractPath;

function prose(markdown) {
  let fence;
  return markdown.split(/\r?\n/).map((line) => {
    const marker = /^\s{0,3}(`{3,}|~{3,})/.exec(line)?.[1];
    if (fence) {
      if (marker?.[0] === fence[0] && marker.length >= fence.length
          && line.trim() === marker) fence = undefined;
      return '';
    }
    if (marker) {
      fence = marker;
      return '';
    }
    return line;
  }).join('\n');
}

function inlineDestination(text, start) {
  let cursor = start;
  while (/[ \t]/.test(text[cursor] ?? '')) cursor++;
  let href = '';
  if (text[cursor] === '<') {
    const end = text.indexOf('>', cursor);
    if (end < 0 || text.slice(cursor, end).includes('\n')) return null;
    href = text.slice(cursor + 1, end);
    cursor = end + 1;
  } else {
    let depth = 0;
    while (cursor < text.length) {
      const character = text[cursor];
      if (/\s/.test(character) || (character === ')' && depth === 0)) break;
      if (character === '\\' && /[\\()]/.test(text[cursor + 1] ?? '')) {
        href += text[++cursor];
      } else {
        if (character === '(') depth++;
        if (character === ')') depth--;
        href += character;
      }
      cursor++;
    }
    if (depth !== 0) return null;
  }
  const tail = /^(?:[ \t]+(?:"[^"\n]*"|'[^'\n]*'|\([^\n)]*\)))?[ \t]*\)/.exec(text.slice(cursor));
  return tail ? { href, end: cursor + tail[0].length } : null;
}

function links(markdown) {
  const normalizeLabel = (label) => label.trim().replace(/\s+/g, ' ').toLowerCase();
  const definitions = new Map();
  const links = [];
  const errors = [];
  const text = prose(markdown).replace(/(`+)[^\n]*?\1/g, '')
    .replace(/<!--[\s\S]*?(?:-->|$)/g, '')
    .replace(/^ {0,3}\[([^\]\n]+)\]:[ \t]*(<[^>\n]+>|\S+)[^\n]*$/gm, (_, label, href) => {
      const id = normalizeLabel(label);
      if (!definitions.has(id)) {
        const destination = href.replace(/^<|>$/g, '');
        definitions.set(id, destination);
        links.push({ href: destination, navigable: false });
      }
      return '';
    });
  const pattern = /(!?)\[([^\[\]\n]*)\](\(|\[([^\[\]\n]*)\])?/g;
  let match;
  while ((match = pattern.exec(text))) {
    const navigable = match[1] !== '!';
    if (match[3] === '(') {
      const destination = inlineDestination(text, pattern.lastIndex);
      if (!destination) {
        errors.push(`invalid inline link destination after [${match[2]}]`);
      } else {
        links.push({ href: destination.href, navigable });
        pattern.lastIndex = destination.end;
      }
    } else {
      const label = normalizeLabel(match[4] || match[2]);
      if (definitions.has(label)) {
        links.push({ href: definitions.get(label), navigable });
      } else if (match[3]) {
        errors.push(`undefined reference: ${label}`);
      }
    }
  }
  return { links, errors };
}

function hasDescription(markdown) {
  const front = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(markdown)?.[1];
  const value = /^description:[ \t]*([^\r\n]*)/m.exec(front ?? '')?.[1].trim() ?? '';
  if (/^["']/.test(value)) {
    const quoted = /^(?:"((?:[^"\\]|\\.)*)"|'((?:[^']|'')*)')(?:[ \t]+#.*)?$/.exec(value);
    return quoted !== null && (quoted[1] ?? quoted[2]).trim().length > 0;
  }
  const plain = value.replace(/[ \t]+#.*$/, '').trim();
  const scalar = /^(?:null|true|false|~|[-+]?(?:0x[\da-f]+|0o[0-7]+|0b[01]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:e[-+]?\d+)?|\.inf|\.nan))$/i;
  return plain.length > 0 && !/^[#>|[\]{}&*!]/.test(plain)
    && !scalar.test(plain);
}

function anchors(markdown) {
  const found = new Set();
  const counts = new Map();
  const text = prose(markdown).replace(/<!--[\s\S]*?(?:-->|$)/g, '');
  for (const match of text.matchAll(/^ {0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$/gm)) {
    const base = match[1].toLowerCase()
      .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
      .replace(/[^\p{L}\p{N}_\-\s]/gu, '').replace(/\s/g, '-');
    let slug = base;
    let suffix = counts.get(base) ?? 0;
    while (found.has(slug)) slug = `${base}-${++suffix}`;
    counts.set(base, suffix);
    found.add(slug);
  }
  return found;
}

/**
 * Check repository-owned guidance without running its commands or changing files.
 * Git supplies tracked and nonignored untracked paths, including in worktrees.
 * Returns diagnostics and size evidence; host/global instructions are out of scope.
 */
export function auditRepository(root) {
  const resolvedRoot = realpathSync(root);
  const files = [...new Set(execFileSync('git', [
    '-C', root, 'ls-files', '--cached', '--others', '--exclude-standard', '-z',
  ], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).split('\0').filter(Boolean))].sort();
  const inventory = new Set(files);
  const directories = new Set(['.']);
  for (const file of files) {
    let parent = path.posix.dirname(file);
    while (parent !== '.') {
      directories.add(parent);
      parent = path.posix.dirname(parent);
    }
  }
  const errors = [];
  const contents = new Map();
  const localPath = (file) => {
    const resolved = realpathSync(path.join(root, file));
    const relative = path.relative(resolvedRoot, resolved);
    if (relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
      throw new Error('Reference resolves outside the repository');
    }
    const canonical = relative.split(path.sep).join('/') || '.';
    if (!inventory.has(canonical) && !directories.has(canonical)) {
      throw new Error('Reference resolves to an ignored or unlisted path');
    }
    return resolved;
  };
  const read = (file) => {
    if (!contents.has(file)) {
      try {
        contents.set(file, readFileSync(localPath(file), 'utf8'));
      } catch {
        errors.push(`${file}: cannot read referenced file (deleted, inaccessible, ignored or outside repository)`);
        contents.set(file, null);
      }
    }
    return contents.get(file);
  };
  for (const required of ['AGENTS.md', indexPath, contractPath]) {
    if (!inventory.has(required)) errors.push(`${required}: required guidance is missing`);
  }
  const guidance = files.filter(isGuidance);
  const instructions = guidance.filter(isInstruction);
  const indexTargets = new Set();
  const localTargets = new Map();

  for (const file of guidance) {
    const text = read(file);
    if (text === null) continue;
    if (!text.trim()) errors.push(`${file}: guidance must not be empty`);
    if (file.startsWith('.agent/workflows/') && !hasDescription(text)) {
      errors.push(`${file}: workflow needs nonempty single-line string description front matter`);
    }
    if (file.endsWith('AGENTS.override.md')) {
      const canonical = file.replace('AGENTS.override.md', 'AGENTS.md');
      if (inventory.has(canonical)) errors.push(`${file}: shadows ${canonical}; keep one instruction owner`);
    }
    const targets = new Set();
    localTargets.set(file, targets);
    const parsed = links(text);
    errors.push(...parsed.errors.map((error) => `${file}: ${error}`));
    for (const { href, navigable } of parsed.links) {
      if (/^[a-z][a-z\d+.-]*:/i.test(href) || href.startsWith('//')) continue;
      const hash = href.indexOf('#');
      let destination;
      let fragment;
      try {
        destination = decodeURIComponent(hash < 0 ? href : href.slice(0, hash));
        fragment = hash < 0 ? '' : decodeURIComponent(href.slice(hash + 1));
      } catch {
        errors.push(`${file}: invalid link encoding: ${href}`);
        continue;
      }
      if (destination.includes('\\') || destination.startsWith('/')) {
        errors.push(`${file}: use a relative forward-slash link: ${href}`);
        continue;
      }
      const target = destination
        ? path.posix.normalize(path.posix.join(path.posix.dirname(file), destination))
          .replace(/\/$/, '')
        : file;
      if (target === '..' || target.startsWith('../')) {
        errors.push(`${file}: link leaves repository: ${href}`);
        continue;
      }
      if (navigable) {
        targets.add(target);
        if (file === indexPath) indexTargets.add(target);
      }
      if (!inventory.has(target) && !directories.has(target)) {
        errors.push(`${file}: missing link target: ${href}`);
      } else if (directories.has(target)) {
        try {
          if (!statSync(localPath(target)).isDirectory()) throw new Error('Not a directory');
        } catch {
          errors.push(`${file}: missing or nonlocal directory target: ${href}`);
        }
      } else {
        const targetText = target.endsWith('.md') ? read(target) : null;
        if (!target.endsWith('.md')) {
          try {
            if (!statSync(localPath(target)).isFile()) throw new Error('Not a file');
          } catch {
            errors.push(`${file}: missing link target: ${href}`);
          }
        }
        if (fragment && targetText !== null && !anchors(targetText).has(fragment)) {
          errors.push(`${file}: missing heading anchor: ${href}`);
        }
      }
    }
  }
  for (const file of guidance) {
    if (file !== indexPath && file !== contractPath && !indexTargets.has(file)) {
      errors.push(`${indexPath}: missing index entry for ${file}`);
    }
  }
  if (!localTargets.get('AGENTS.md')?.has(indexPath)) {
    errors.push(`AGENTS.md: must link to ${indexPath}`);
  }
  if (!indexTargets.has(contractPath)) errors.push(`${indexPath}: must link to ${contractPath}`);

  const sizes = new Map(instructions.map((file) => [file, Buffer.byteLength(read(file) ?? '')]));
  if ((sizes.get('AGENTS.md') ?? 0) > rootBudget) {
    errors.push(`AGENTS.md: exceeds ${rootBudget}-byte root budget; move details to scoped references`);
  }
  const chains = instructions.map((leaf) => {
    const directory = path.posix.dirname(leaf);
    const members = instructions.filter((candidate) => {
      const ancestor = path.posix.dirname(candidate);
      return ancestor === '.' || directory === ancestor || directory.startsWith(`${ancestor}/`);
    });
    const bytes = members.reduce((sum, member) => sum + sizes.get(member), 0)
      + Math.max(0, members.length - 1) * 2;
    if (bytes > chainBudget) errors.push(`${leaf}: instruction chain is ${bytes} bytes; budget ${chainBudget}`);
    return { leaf, bytes };
  }).sort((a, b) => b.bytes - a.bytes || (a.leaf < b.leaf ? -1 : a.leaf > b.leaf ? 1 : 0));

  return { errors: [...new Set(errors)].sort(), guidanceCount: guidance.length, chains };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.length !== 2) throw new Error('Usage: node tools/agents/check.mjs (no arguments)');
    const result = auditRepository(fileURLToPath(new URL('../../', import.meta.url)));
    if (result.errors.length) {
      for (const error of result.errors) console.error(error);
      process.exitCode = 1;
    } else {
      const largest = result.chains[0];
      console.log(`Agent guidance OK: ${result.guidanceCount} files; largest instruction chain ${largest.bytes}/${chainBudget} bytes (${largest.leaf}).`);
    }
  } catch (error) {
    console.error(`Agent guidance check failed: ${error.message}`);
    process.exitCode = 1;
  }
}
