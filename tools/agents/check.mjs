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

function links(markdown) {
  const text = prose(markdown).replace(/(`+)[^\n]*?\1/g, '');
  const inline = [...text.matchAll(/\[[^\]\n]*\]\(\s*(<[^>\n]+>|[^\s)]+)(?:\s+"[^"\n]*")?\s*\)/g)]
    .map((match) => match[1].replace(/^<|>$/g, ''));
  const references = [...text.matchAll(/^\s{0,3}\[[^\]\n]+\]:\s*(<[^>\n]+>|\S+)/gm)]
    .map((match) => match[1].replace(/^<|>$/g, ''));
  return [...inline, ...references];
}

function anchors(markdown) {
  const found = new Set();
  const counts = new Map();
  for (const match of prose(markdown).matchAll(/^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$/gm)) {
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
    return resolved;
  };
  const read = (file) => {
    if (!contents.has(file)) {
      try {
        contents.set(file, readFileSync(localPath(file), 'utf8'));
      } catch {
        errors.push(`${file}: cannot read referenced file (deleted, inaccessible or outside repository)`);
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
    if (file.startsWith('.agent/workflows/')) {
      const front = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(text)?.[1];
      if (!front || !/^description:[ \t]*\S[^\r\n]*$/m.test(front)) {
        errors.push(`${file}: workflow needs description front matter`);
      }
    }
    if (file.endsWith('AGENTS.override.md')) {
      const canonical = file.replace('AGENTS.override.md', 'AGENTS.md');
      if (inventory.has(canonical)) errors.push(`${file}: shadows ${canonical}; keep one instruction owner`);
    }
    const targets = new Set();
    localTargets.set(file, targets);
    for (const href of links(text)) {
      if (/^[a-z][a-z\d+.-]*:/i.test(href) || href.startsWith('//')) continue;
      let decoded;
      try { decoded = decodeURIComponent(href); } catch {
        errors.push(`${file}: invalid link encoding: ${href}`);
        continue;
      }
      const hash = decoded.indexOf('#');
      const destination = hash < 0 ? decoded : decoded.slice(0, hash);
      const fragment = hash < 0 ? '' : decoded.slice(hash + 1);
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
      targets.add(target);
      if (file === indexPath) indexTargets.add(target);
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
  }).sort((a, b) => b.bytes - a.bytes || a.leaf.localeCompare(b.leaf));

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
