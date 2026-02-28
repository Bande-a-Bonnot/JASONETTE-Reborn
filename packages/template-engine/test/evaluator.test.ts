import { describe, it, expect } from 'vitest';
import { evaluate } from '../src/evaluator.js';
import type { RenderContext } from '../src/types.js';

describe('evaluate', () => {
  const ctx = (data: unknown): RenderContext => ({ $jason: data });

  describe('literals', () => {
    it('returns number literal', () => {
      expect(evaluate('42', ctx(null))).toBe(42);
    });

    it('returns string literal', () => {
      expect(evaluate('"hello"', ctx(null))).toBe('hello');
    });

    it('returns boolean true', () => {
      expect(evaluate('true', ctx(null))).toBe(true);
    });

    it('returns boolean false', () => {
      expect(evaluate('false', ctx(null))).toBe(false);
    });

    it('returns null', () => {
      expect(evaluate('null', ctx(null))).toBeNull();
    });
  });

  describe('identifiers', () => {
    it('resolves $jason', () => {
      expect(evaluate('$jason', ctx('test'))).toBe('test');
    });

    it('resolves bare property from $jason object', () => {
      expect(evaluate('name', ctx({ name: 'Alice' }))).toBe('Alice');
    });

    it('returns undefined for missing identifier', () => {
      expect(evaluate('missing', ctx({}))).toBeUndefined();
    });

    it('resolves $get', () => {
      expect(evaluate('$get.count', { $get: { count: 5 } })).toBe(5);
    });

    it('resolves $params', () => {
      expect(evaluate('$params.id', { $params: { id: '123' } })).toBe('123');
    });

    it('resolves $env', () => {
      expect(evaluate('$env.API_URL', { $env: { API_URL: 'https://api.test' } })).toBe('https://api.test');
    });

    it('resolves $index', () => {
      expect(evaluate('$index', { $index: 3 })).toBe(3);
    });

    it('resolves $root', () => {
      expect(evaluate('$root', { $root: { items: [1, 2] } })).toEqual({ items: [1, 2] });
    });

    it('resolves $cache', () => {
      expect(evaluate('$cache.token', { $cache: { token: 'abc' } })).toBe('abc');
    });

    it('resolves $keys', () => {
      expect(evaluate('$keys.api_key', { $keys: { api_key: 'secret' } })).toBe('secret');
    });

    it('resolves this as alias for $jason', () => {
      expect(evaluate('this', ctx({ name: 'test' }))).toEqual({ name: 'test' });
    });

    it('resolves this.property', () => {
      expect(evaluate('this.name', ctx({ name: 'Alice' }))).toBe('Alice');
    });
  });

  describe('member expressions', () => {
    it('accesses dot notation', () => {
      expect(evaluate('$jason.name', ctx({ name: 'Bob' }))).toBe('Bob');
    });

    it('accesses nested properties', () => {
      expect(evaluate('$jason.user.email', ctx({ user: { email: 'a@b.com' } }))).toBe('a@b.com');
    });

    it('accesses bracket notation with number', () => {
      expect(evaluate('$jason[0]', ctx(['first', 'second']))).toBe('first');
    });

    it('accesses bracket notation with string', () => {
      expect(evaluate('$jason["key"]', ctx({ key: 'val' }))).toBe('val');
    });

    it('returns undefined for null base', () => {
      expect(evaluate('$jason.foo', ctx(null))).toBeUndefined();
    });

    it('returns string length', () => {
      expect(evaluate('$jason.length', ctx('hello'))).toBe(5);
    });

    it('returns array length', () => {
      expect(evaluate('$jason.length', ctx([1, 2, 3]))).toBe(3);
    });
  });

  describe('binary expressions', () => {
    it('adds numbers', () => {
      expect(evaluate('1 + 2', ctx(null))).toBe(3);
    });

    it('subtracts', () => {
      expect(evaluate('10 - 3', ctx(null))).toBe(7);
    });

    it('multiplies', () => {
      expect(evaluate('4 * 5', ctx(null))).toBe(20);
    });

    it('divides', () => {
      expect(evaluate('10 / 2', ctx(null))).toBe(5);
    });

    it('modulo', () => {
      expect(evaluate('7 % 3', ctx(null))).toBe(1);
    });

    it('concatenates strings with +', () => {
      expect(evaluate('"hello" + " " + "world"', ctx(null))).toBe('hello world');
    });

    it('compares with ==', () => {
      expect(evaluate('1 == 1', ctx(null))).toBe(true);
    });

    it('compares with ===', () => {
      expect(evaluate('1 === 1', ctx(null))).toBe(true);
    });

    it('compares with !=', () => {
      expect(evaluate('1 != 2', ctx(null))).toBe(true);
    });

    it('compares with !==', () => {
      expect(evaluate('1 !== "1"', ctx(null))).toBe(true);
    });

    it('less than', () => {
      expect(evaluate('1 < 2', ctx(null))).toBe(true);
    });

    it('greater than', () => {
      expect(evaluate('2 > 1', ctx(null))).toBe(true);
    });

    it('less than or equal', () => {
      expect(evaluate('2 <= 2', ctx(null))).toBe(true);
    });

    it('greater than or equal', () => {
      expect(evaluate('3 >= 2', ctx(null))).toBe(true);
    });

    it('logical AND', () => {
      expect(evaluate('true && false', ctx(null))).toBe(false);
    });

    it('logical OR', () => {
      expect(evaluate('false || true', ctx(null))).toBe(true);
    });

    it('in operator with $jason', () => {
      expect(evaluate('"name" in $jason', ctx({ name: 'test' }))).toBe(true);
    });

    it('in operator false case', () => {
      expect(evaluate('"missing" in $jason', ctx({ name: 'test' }))).toBe(false);
    });

    it('in operator with this', () => {
      expect(evaluate("'profile' in this", ctx({ profile: 'url', name: 'test' }))).toBe(true);
    });

    it('in operator with this (missing key)', () => {
      expect(evaluate("'profile' in this", ctx({ name: 'test' }))).toBe(false);
    });
  });

  describe('unary expressions', () => {
    it('logical NOT', () => {
      expect(evaluate('!false', ctx(null))).toBe(true);
    });

    it('negation', () => {
      expect(evaluate('-5', ctx(null))).toBe(-5);
    });

    it('unary plus', () => {
      expect(evaluate('+5', ctx(null))).toBe(5);
    });
  });

  describe('conditional (ternary) expressions', () => {
    it('returns consequent when true', () => {
      expect(evaluate('true ? "yes" : "no"', ctx(null))).toBe('yes');
    });

    it('returns alternate when false', () => {
      expect(evaluate('false ? "yes" : "no"', ctx(null))).toBe('no');
    });

    it('works with context values', () => {
      expect(evaluate('$jason.active ? "on" : "off"', ctx({ active: true }))).toBe('on');
    });
  });

  describe('array expressions', () => {
    it('creates array', () => {
      expect(evaluate('[1, 2, 3]', ctx(null))).toEqual([1, 2, 3]);
    });

    it('creates array with expressions', () => {
      expect(evaluate('[1 + 1, "hello"]', ctx(null))).toEqual([2, 'hello']);
    });
  });

  describe('function calls', () => {
    it('calls Math.floor', () => {
      expect(evaluate('Math.floor(3.7)', ctx(null))).toBe(3);
    });

    it('calls Math.ceil', () => {
      expect(evaluate('Math.ceil(3.2)', ctx(null))).toBe(4);
    });

    it('calls Math.round', () => {
      expect(evaluate('Math.round(3.5)', ctx(null))).toBe(4);
    });

    it('calls Math.abs', () => {
      expect(evaluate('Math.abs(-5)', ctx(null))).toBe(5);
    });

    it('calls Math.min', () => {
      expect(evaluate('Math.min(3, 1, 2)', ctx(null))).toBe(1);
    });

    it('calls Math.max', () => {
      expect(evaluate('Math.max(3, 1, 2)', ctx(null))).toBe(3);
    });

    it('calls Math.pow', () => {
      expect(evaluate('Math.pow(2, 3)', ctx(null))).toBe(8);
    });

    it('calls Math.sqrt', () => {
      expect(evaluate('Math.sqrt(9)', ctx(null))).toBe(3);
    });

    it('calls JSON.stringify', () => {
      expect(evaluate('JSON.stringify($jason)', ctx({ a: 1 }))).toBe('{"a":1}');
    });

    it('calls parseInt', () => {
      expect(evaluate('parseInt("42")', ctx(null))).toBe(42);
    });

    it('calls parseFloat', () => {
      expect(evaluate('parseFloat("3.14")', ctx(null))).toBeCloseTo(3.14);
    });

    it('calls String', () => {
      expect(evaluate('String(42)', ctx(null))).toBe('42');
    });

    it('calls Number', () => {
      expect(evaluate('Number("42")', ctx(null))).toBe(42);
    });

    it('calls encodeURIComponent', () => {
      expect(evaluate('encodeURIComponent("hello world")', ctx(null))).toBe('hello%20world');
    });

    it('calls decodeURIComponent', () => {
      expect(evaluate('decodeURIComponent("hello%20world")', ctx(null))).toBe('hello world');
    });

    it('calls isNaN', () => {
      expect(evaluate('isNaN("abc")', ctx(null))).toBe(true);
    });

    it('calls isFinite', () => {
      expect(evaluate('isFinite(42)', ctx(null))).toBe(true);
    });

    it('rejects unapproved functions', () => {
      expect(evaluate('eval("1+1")', ctx(null))).toBeUndefined();
    });
  });

  describe('security', () => {
    it('blocks __proto__ access', () => {
      expect(evaluate('$jason.__proto__', ctx({}))).toBeUndefined();
    });

    it('blocks constructor access', () => {
      expect(evaluate('$jason.constructor', ctx({}))).toBeUndefined();
    });

    it('blocks prototype access', () => {
      expect(evaluate('$jason.prototype', ctx({}))).toBeUndefined();
    });

    it('blocks __proto__ via bracket notation', () => {
      expect(evaluate('$jason["__proto__"]', ctx({}))).toBeUndefined();
    });
  });

  describe('complexity limits', () => {
    it('rejects expressions exceeding node limit', () => {
      // Build an expression with many nodes
      const expr = Array.from({ length: 60 }, (_, i) => String(i)).join(' + ');
      expect(evaluate(expr, ctx(null))).toBeUndefined();
    });

    it('respects custom node limit', () => {
      expect(evaluate('1 + 2 + 3', ctx(null), { maxExpressionNodes: 3 })).toBeUndefined();
    });

    it('allows within limits', () => {
      expect(evaluate('1 + 2', ctx(null), { maxExpressionNodes: 50 })).toBe(3);
    });
  });

  describe('error handling', () => {
    it('returns undefined for invalid expression', () => {
      expect(evaluate('!!!invalid!!!', ctx(null))).toBeUndefined();
    });

    it('returns undefined for empty expression', () => {
      expect(evaluate('', ctx(null))).toBeUndefined();
    });
  });

  describe('compound expressions', () => {
    it('evaluates compound and returns last value', () => {
      // jsep parses comma as compound
      expect(evaluate('1, 2, 3', ctx(null))).toBe(3);
    });
  });
});
