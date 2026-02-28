import { describe, it, expect } from 'vitest';
import { transform } from '../src/transformer.js';
import type { RenderContext } from '../src/types.js';

describe('transform', () => {
  const ctx = (data: unknown, extra?: Partial<RenderContext>): RenderContext => ({
    $jason: data,
    ...extra,
  });

  describe('passthrough', () => {
    it('returns null as-is', () => {
      expect(transform(null, ctx(null))).toBeNull();
    });

    it('returns undefined as-is', () => {
      expect(transform(undefined, ctx(null))).toBeUndefined();
    });

    it('returns number as-is', () => {
      expect(transform(42, ctx(null))).toBe(42);
    });

    it('returns boolean as-is', () => {
      expect(transform(true, ctx(null))).toBe(true);
    });
  });

  describe('string interpolation', () => {
    it('interpolates single expression returning raw value', () => {
      expect(transform('{{$jason}}', ctx(42))).toBe(42);
    });

    it('interpolates single expression returning object', () => {
      const data = { name: 'Alice' };
      expect(transform('{{$jason}}', ctx(data))).toEqual(data);
    });

    it('interpolates inline expressions as string', () => {
      expect(transform('Hello {{$jason.name}}!', ctx({ name: 'Bob' }))).toBe('Hello Bob!');
    });

    it('handles multiple inline expressions', () => {
      expect(transform('{{$jason.first}} {{$jason.last}}', ctx({ first: 'A', last: 'B' }))).toBe('A B');
    });

    it('replaces undefined with empty string in inline', () => {
      expect(transform('Hi {{$jason.missing}}!', ctx({}))).toBe('Hi !');
    });

    it('replaces null with empty string in inline', () => {
      expect(transform('Hi {{$jason.val}}!', ctx({ val: null }))).toBe('Hi !');
    });

    it('does not interpolate plain strings', () => {
      expect(transform('hello world', ctx(null))).toBe('hello world');
    });

    it('resolves $get in expressions', () => {
      expect(transform('{{$get.name}}', ctx(null, { $get: { name: 'Carol' } }))).toBe('Carol');
    });
  });

  describe('#each directive', () => {
    it('iterates over array', () => {
      const template = {
        '{{#each $jason.items}}': {
          label: '{{$jason}}',
        },
      };
      const result = transform(template, ctx({ items: ['a', 'b', 'c'] }));
      expect(result).toEqual([
        { label: 'a' },
        { label: 'b' },
        { label: 'c' },
      ]);
    });

    it('provides $index in each loop', () => {
      const template = {
        '{{#each $jason}}': '{{$index}}',
      };
      expect(transform(template, ctx([10, 20, 30]))).toEqual([0, 1, 2]);
    });

    it('provides $root in each loop', () => {
      const template = {
        '{{#each $jason.items}}': '{{$root.title}}',
      };
      const data = { title: 'Test', items: [1, 2] };
      expect(transform(template, ctx(data))).toEqual(['Test', 'Test']);
    });

    it('returns empty array for non-array', () => {
      const template = {
        '{{#each $jason.items}}': '{{$jason}}',
      };
      expect(transform(template, ctx({ items: 'not-array' }))).toEqual([]);
    });

    it('returns empty array for undefined', () => {
      const template = {
        '{{#each $jason.missing}}': '{{$jason}}',
      };
      expect(transform(template, ctx({}))).toEqual([]);
    });

    it('handles nested objects in each', () => {
      const template = {
        '{{#each $jason}}': {
          text: '{{$jason.name}}',
          idx: '{{$index}}',
        },
      };
      const data = [{ name: 'A' }, { name: 'B' }];
      expect(transform(template, ctx(data))).toEqual([
        { text: 'A', idx: 0 },
        { text: 'B', idx: 1 },
      ]);
    });
  });

  describe('#if/#elseif/#else directives', () => {
    it('returns #if branch when true', () => {
      const template = {
        '{{#if $jason.show}}': { visible: true },
      };
      expect(transform(template, ctx({ show: true }))).toEqual({ visible: true });
    });

    it('returns undefined when #if false and no else', () => {
      const template = {
        '{{#if $jason.show}}': { visible: true },
      };
      expect(transform(template, ctx({ show: false }))).toBeUndefined();
    });

    it('returns #else when #if false', () => {
      const template = {
        '{{#if $jason.show}}': { visible: true },
        '{{#else}}': { visible: false },
      };
      expect(transform(template, ctx({ show: false }))).toEqual({ visible: false });
    });

    it('handles #elseif chain', () => {
      const template = {
        '{{#if $jason.type === "a"}}': 'type-a',
        '{{#elseif $jason.type === "b"}}': 'type-b',
        '{{#else}}': 'other',
      };
      expect(transform(template, ctx({ type: 'b' }))).toBe('type-b');
    });

    it('#elseif falls through to #else', () => {
      const template = {
        '{{#if $jason.type === "a"}}': 'type-a',
        '{{#elseif $jason.type === "b"}}': 'type-b',
        '{{#else}}': 'other',
      };
      expect(transform(template, ctx({ type: 'c' }))).toBe('other');
    });

    it('transforms branch value', () => {
      const template = {
        '{{#if true}}': '{{$jason.name}}',
      };
      expect(transform(template, ctx({ name: 'Alice' }))).toBe('Alice');
    });
  });

  describe('array conditional chains', () => {
    it('handles if/else across array items', () => {
      const template = [
        { '{{#if $jason.success}}': { result: '{{$jason.data}}' } },
        { '{{#else}}': { error: 'failed' } },
      ];
      expect(transform(template, ctx({ success: true, data: 'ok' }))).toEqual({ result: 'ok' });
    });

    it('falls through to else in array', () => {
      const template = [
        { '{{#if $jason.success}}': { result: 'ok' } },
        { '{{#else}}': { error: 'failed' } },
      ];
      expect(transform(template, ctx({ success: false }))).toEqual({ error: 'failed' });
    });

    it('returns undefined when no branch matches in array', () => {
      const template = [
        { '{{#if $jason.a}}': 'a' },
        { '{{#elseif $jason.b}}': 'b' },
      ];
      expect(transform(template, ctx({ a: false, b: false }))).toBeUndefined();
    });
  });

  describe('object processing', () => {
    it('transforms nested objects', () => {
      const template = {
        user: {
          name: '{{$jason.name}}',
          age: '{{$jason.age}}',
        },
      };
      expect(transform(template, ctx({ name: 'Bob', age: 30 }))).toEqual({
        user: { name: 'Bob', age: 30 },
      });
    });

    it('transforms template keys', () => {
      const template = {
        '{{$jason.key}}': '{{$jason.value}}',
      };
      expect(transform(template, ctx({ key: 'name', value: 'Alice' }))).toEqual({
        name: 'Alice',
      });
    });

    it('does not process directive-like keys as template keys', () => {
      // Keys starting with {{# should not be interpolated as string templates
      const template = {
        '{{#if true}}': 'yes',
      };
      // Should be treated as a conditional, not key interpolation
      expect(transform(template, ctx(null))).toBe('yes');
    });
  });

  describe('array processing', () => {
    it('transforms array items', () => {
      const template = ['{{$jason.a}}', '{{$jason.b}}'];
      expect(transform(template, ctx({ a: 1, b: 2 }))).toEqual([1, 2]);
    });

    it('filters out undefined items', () => {
      // Plain arrays (without conditionals) filter undefined
      const template = ['{{$jason.a}}', '{{$jason.missing}}', '{{$jason.b}}'];
      const result = transform(template, ctx({ a: 1, b: 2 }));
      expect(result).toEqual([1, 2]);
    });
  });

  describe('nested directives', () => {
    it('handles #each with nested #if', () => {
      const template = {
        '{{#each $jason}}': {
          '{{#if $jason.active}}': { name: '{{$jason.name}}' },
        },
      };
      const data = [
        { name: 'A', active: true },
        { name: 'B', active: false },
        { name: 'C', active: true },
      ];
      const result = transform(template, ctx(data));
      expect(result).toEqual([
        { name: 'A' },
        undefined,
        { name: 'C' },
      ]);
    });
  });
});
