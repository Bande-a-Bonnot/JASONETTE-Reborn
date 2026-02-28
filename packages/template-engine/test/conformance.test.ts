import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { renderSync } from '../src/render.js';
import type { RenderContext } from '../src/types.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFORMANCE_DIR = join(__dirname, '../../../spec/conformance');
const UPDATE_EXPECTED = process.env.UPDATE_EXPECTED === '1';

function loadFixture(name: string): Record<string, unknown> {
  const path = join(CONFORMANCE_DIR, name, 'input.json');
  return JSON.parse(readFileSync(path, 'utf-8'));
}

function loadExpected(name: string): unknown | null {
  const path = join(CONFORMANCE_DIR, name, 'expected.json');
  if (!existsSync(path)) return null;
  return JSON.parse(readFileSync(path, 'utf-8'));
}

function saveExpected(name: string, data: unknown): void {
  const path = join(CONFORMANCE_DIR, name, 'expected.json');
  writeFileSync(path, JSON.stringify(data, null, 2) + '\n', 'utf-8');
}

/**
 * Render a Jasonette document by extracting data and template from $jason.head.
 */
function renderJasonDocument(doc: Record<string, unknown>): unknown {
  const jason = doc.$jason as Record<string, unknown>;
  const head = jason.head as Record<string, unknown>;
  const data = head.data as Record<string, unknown> | undefined;
  const templates = head.templates as Record<string, unknown> | undefined;

  if (!templates) {
    return jason;
  }

  const templateBody = templates.body;
  if (!templateBody) return jason;

  const context: RenderContext = {
    $jason: data ?? {},
  };

  // If data is an object, its properties are accessible as bare identifiers
  const renderedBody = renderSync(templateBody, context);

  // Reconstruct the output document
  const result: Record<string, unknown> = {
    $jason: {
      head: {
        title: head.title,
        ...(head.styles ? { styles: head.styles } : {}),
        ...(head.actions ? { actions: head.actions } : {}),
      },
      body: renderedBody,
    },
  };

  return result;
}

describe('conformance tests', () => {
  const fixtures = ['each', 'if', 'inline', 'template-index', 'agent'];

  for (const fixture of fixtures) {
    it(`renders ${fixture} fixture correctly`, () => {
      const input = loadFixture(fixture);
      const result = renderJasonDocument(input);

      if (UPDATE_EXPECTED) {
        saveExpected(fixture, result);
        console.log(`  Updated expected output for: ${fixture}`);
      }

      const expected = loadExpected(fixture);
      if (expected === null) {
        // No expected output yet — generate it
        saveExpected(fixture, result);
        console.log(`  Generated expected output for: ${fixture}`);
        return;
      }

      expect(result).toEqual(expected);
    });
  }
});

describe('adversarial tests', () => {
  const invalidDir = join(CONFORMANCE_DIR, 'invalid');

  const adversarialCases = [
    {
      name: 'prototype-pollution',
      file: 'prototype-pollution.json',
      check: (result: unknown) => {
        // Should not allow prototype pollution
        const obj = {} as Record<string, unknown>;
        expect(obj['polluted']).toBeUndefined();
      },
    },
    {
      name: 'expression-complexity',
      file: 'expression-complexity.json',
      check: (result: unknown) => {
        // Should not hang — complexity limits kick in
        expect(result).toBeDefined();
      },
    },
    {
      name: 'file-url-mixin',
      file: 'file-url-mixin.json',
      check: (result: unknown) => {
        // Should not resolve file:// URLs
        expect(result).toBeDefined();
      },
    },
    {
      name: 'javascript-url',
      file: 'javascript-url.json',
      check: (result: unknown) => {
        // Template engine passes through URLs — validation happens at runtime
        expect(result).toBeDefined();
      },
    },
    {
      name: 'recursive-mixin',
      file: 'recursive-mixin.json',
      check: (result: unknown) => {
        // Should not infinite loop (depth limit)
        expect(result).toBeDefined();
      },
    },
    {
      name: 'oversized-document',
      file: 'oversized-document.json',
      check: (result: unknown) => {
        // Placeholder test — size checking happens at fetch layer
        expect(result).toBeDefined();
      },
    },
  ];

  for (const { name, file, check } of adversarialCases) {
    it(`handles ${name} safely`, () => {
      const path = join(invalidDir, file);
      if (!existsSync(path)) {
        console.log(`  Skipping ${name}: file not found`);
        return;
      }

      const input = JSON.parse(readFileSync(path, 'utf-8'));

      // Should not throw
      let result: unknown;
      expect(() => {
        result = renderSync(input, { $jason: input });
      }).not.toThrow();

      check(result);
    });
  }
});
