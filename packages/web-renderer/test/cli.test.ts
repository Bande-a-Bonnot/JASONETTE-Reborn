import { describe, it, expect } from 'vitest';
import { execSync } from 'node:child_process';
import { resolve } from 'node:path';

const cliPath = resolve(import.meta.dirname, '../src/cli.ts');
const fixturesBase = resolve(import.meta.dirname, '../../../Jasonpedia');

function run(args: string): { stdout: string; exitCode: number } {
  try {
    const stdout = execSync(`npx tsx ${cliPath} ${args}`, {
      encoding: 'utf-8',
      cwd: resolve(import.meta.dirname, '..'),
    });
    return { stdout, exitCode: 0 };
  } catch (err: unknown) {
    const e = err as { stdout: string; status: number };
    return { stdout: e.stdout ?? '', exitCode: e.status ?? 1 };
  }
}

describe('CLI: validate', () => {
  it('validates a correct $jason document', () => {
    const { stdout, exitCode } = run(`validate ${fixturesBase}/core/index.json`);
    expect(exitCode).toBe(0);
    expect(stdout).toContain('valid');
  });

  it('validates demo.json', () => {
    const { stdout, exitCode } = run(`validate ${fixturesBase}/demo.json`);
    expect(exitCode).toBe(0);
    expect(stdout).toContain('valid');
  });

  it('outputs JSON format', () => {
    const { stdout, exitCode } = run(`validate ${fixturesBase}/core/index.json --format json`);
    expect(exitCode).toBe(0);
    const result = JSON.parse(stdout);
    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('fails on missing file', () => {
    const { exitCode } = run('validate /nonexistent/file.json');
    expect(exitCode).not.toBe(0);
  });

  it('shows help with --help', () => {
    const { stdout, exitCode } = run('--help');
    expect(exitCode).toBe(0);
    expect(stdout).toContain('Usage');
    expect(stdout).toContain('serve');
    expect(stdout).toContain('validate');
  });
});
