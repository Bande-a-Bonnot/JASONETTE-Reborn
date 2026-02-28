#!/usr/bin/env node

/**
 * Validates Jasonpedia JSON files against the $jason v2.0 JSON Schema.
 * Reads exclusion list from spec/schema/v1-exclusions.json.
 * Outputs structured JSON results to stdout.
 */

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const root = join(__dirname, '..');

// Load schema
const schema = JSON.parse(readFileSync(join(root, 'spec/schema/jason.schema.json'), 'utf-8'));

// Load exclusions
const exclusions = JSON.parse(readFileSync(join(root, 'spec/schema/v1-exclusions.json'), 'utf-8'));
const excludedFiles = new Set(exclusions.map(e => e.file));

// Setup validator
const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const validate = ajv.compile(schema);

// Collect JSON files from Jasonpedia
function collectJsonFiles(dir, base) {
  const files = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const rel = relative(base, full);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      files.push(...collectJsonFiles(full, base));
    } else if (entry.endsWith('.json')) {
      files.push(rel);
    }
  }
  return files;
}

const jasonpediaDir = join(root, 'Jasonpedia');
const allFiles = collectJsonFiles(jasonpediaDir, root);

const results = {
  total: 0,
  passed: 0,
  failed: 0,
  excluded: 0,
  errors: [],
  exclusions: []
};

for (const file of allFiles) {
  const fullPath = join(root, file);
  let doc;
  try {
    doc = JSON.parse(readFileSync(fullPath, 'utf-8'));
  } catch {
    // Skip non-JSON or malformed files
    continue;
  }

  // Only validate files with $jason root key
  if (!doc || !doc.$jason) {
    continue;
  }

  results.total++;

  if (excludedFiles.has(file)) {
    results.excluded++;
    results.exclusions.push({ file, reason: exclusions.find(e => e.file === file)?.reason });
    continue;
  }

  const valid = validate(doc);
  if (valid) {
    results.passed++;
  } else {
    results.failed++;
    results.errors.push({
      file,
      errors: validate.errors.slice(0, 5).map(e => ({
        path: e.instancePath,
        message: e.message,
        keyword: e.keyword
      }))
    });
  }
}

// Output
console.log(JSON.stringify(results, null, 2));

if (results.failed > 0) {
  console.error(`\n${results.failed} file(s) failed validation.`);
  process.exit(1);
} else {
  console.error(`\nAll ${results.passed} file(s) passed. ${results.excluded} excluded.`);
}
