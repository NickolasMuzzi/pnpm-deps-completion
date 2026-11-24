#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const SECTIONS = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
  'peerDependencies',
];

const VERSION = '1.0.0';

const USAGE = `Uso: deps.js [--kind deps|bins] [--cwd DIR] [--describe]

Imprime uma opcao por linha para o shell completar.
`;

function compare(a, b) {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

function parseArgs(argv) {
  const opts = { kind: 'deps', cwd: process.cwd(), describe: false, help: false };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--kind') {
      const value = argv[i + 1];
      if (!value) throw new Error('--kind requer deps ou bins');
      opts.kind = value;
      i += 1;
    } else if (arg === '--cwd') {
      const value = argv[i + 1];
      if (!value) throw new Error('--cwd requer um diretorio');
      opts.cwd = value;
      i += 1;
    } else if (arg === '--describe') {
      opts.describe = true;
    } else if (arg === '--help' || arg === '-h') {
      opts.help = true;
    }
  }

  if (opts.kind !== 'deps' && opts.kind !== 'bins') {
    throw new Error(`kind invalido: ${opts.kind}`);
  }
  return opts;
}

function findUp(start, parts) {
  let dir = path.resolve(start);
  try {
    dir = fs.realpathSync(dir);
  } catch {
    // O diretorio pode nao existir quando -C aponta para um caminho novo.
  }

  for (;;) {
    const candidate = path.join(dir, ...parts);
    try {
      fs.statSync(candidate);
      return candidate;
    } catch {
      const parent = path.dirname(dir);
      if (parent === dir) return null;
      dir = parent;
    }
  }
}

function collectDeps(manifestPath) {
  if (!manifestPath) return [];

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch {
    return [];
  }
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) return [];

  const found = new Map();
  for (const section of SECTIONS) {
    const group = manifest[section];
    if (!group || typeof group !== 'object' || Array.isArray(group)) continue;
    for (const name of Object.keys(group)) {
      if (name && !found.has(name)) found.set(name, section);
    }
  }
  return [...found].sort(([a], [b]) => compare(a, b));
}

function collectBins(binDir) {
  if (!binDir) return [];

  let entries;
  try {
    entries = fs.readdirSync(binDir, { withFileTypes: true });
  } catch {
    return [];
  }
  return entries
    .map((entry) => entry.name)
    .filter((name) => !name.startsWith('.'))
    .sort(compare);
}

function run(argv) {
  let opts;
  try {
    opts = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 2;
    return;
  }

  if (opts.help) {
    process.stdout.write(USAGE);
    return;
  }

  let items = [];
  try {
    if (opts.kind === 'deps') {
      items = collectDeps(findUp(opts.cwd, ['package.json']));
    } else {
      items = collectBins(findUp(opts.cwd, ['node_modules', '.bin']));
    }
  } catch {
    items = [];
  }

  const lines = items.map((item) => {
    if (Array.isArray(item)) {
      return opts.describe ? `${item[0]}:${item[1]}` : item[0];
    }
    return opts.describe && opts.kind === 'bins' ? `${item}:bin` : item;
  });
  if (lines.length) process.stdout.write(`${lines.join('\n')}\n`);
}

if (require.main === module) run(process.argv.slice(2));

module.exports = {
  VERSION,
  SECTIONS,
  collectBins,
  collectDeps,
  findUp,
  parseArgs,
  run,
};
