import { evaluate } from './evaluator.js';
import type { RenderContext, RenderOptions } from './types.js';

const EXPR_REGEX = /\{\{([^}]+(?:\}[^}]+)*)\}\}/g;
const EACH_REGEX = /^\{\{#each\s+(.+?)\}\}$/;
const IF_REGEX = /^\{\{#if\s+(.+?)\}\}$/;
const ELSEIF_REGEX = /^\{\{#elseif\s+(.+?)\}\}$/;
const ELSE_REGEX = /^\{\{#else\}\}$/;

/**
 * Interpolate template expressions in a string.
 * "Hello {{name}}" → "Hello World"
 */
function interpolateString(str: string, context: RenderContext, options?: RenderOptions): unknown {
  // If the entire string is a single expression, return raw value (not stringified)
  const singleMatch = str.match(/^\{\{([^}]+(?:\}[^}]+)*)\}\}$/);
  if (singleMatch) {
    return evaluate(singleMatch[1].trim(), context, options);
  }

  // Otherwise interpolate inline expressions as strings
  return str.replace(EXPR_REGEX, (_, expr) => {
    const val = evaluate(expr.trim(), context, options);
    if (val === undefined || val === null) return '';
    return String(val);
  });
}

/**
 * Process an object that may contain template directives as keys.
 */
function processObject(
  obj: Record<string, unknown>,
  context: RenderContext,
  options?: RenderOptions,
): unknown {
  const keys = Object.keys(obj);

  // Check for #each directive
  for (const key of keys) {
    const eachMatch = key.match(EACH_REGEX);
    if (eachMatch) {
      const expr = eachMatch[1].trim();
      const items = evaluate(expr, context, options);
      if (!Array.isArray(items)) return [];

      const template = obj[key];
      return items.map((item, index) => {
        const childContext: RenderContext = {
          ...context,
          $jason: item,
          $root: context.$jason,
          $index: index,
        };
        return transform(template, childContext, options);
      });
    }
  }

  // Check for #if/#elseif/#else chain
  const ifKey = keys.find(k => IF_REGEX.test(k));
  if (ifKey) {
    return processConditionalChain(obj, keys, context, options);
  }

  // Regular object — transform each value
  const result: Record<string, unknown> = {};
  for (const key of keys) {
    // Keys themselves might be template expressions
    const processedKey = typeof key === 'string' && key.includes('{{') && !key.startsWith('{{#')
      ? String(interpolateString(key, context, options))
      : key;
    result[processedKey] = transform(obj[key], context, options);
  }
  return result;
}

/**
 * Process #if/#elseif/#else conditional chain.
 */
function processConditionalChain(
  obj: Record<string, unknown>,
  keys: string[],
  context: RenderContext,
  options?: RenderOptions,
): unknown {
  for (const key of keys) {
    const ifMatch = key.match(IF_REGEX) || key.match(ELSEIF_REGEX);
    if (ifMatch) {
      const expr = ifMatch[1].trim();
      const condition = evaluate(expr, context, options);
      if (condition) {
        return transform(obj[key], context, options);
      }
      continue;
    }

    if (ELSE_REGEX.test(key)) {
      return transform(obj[key], context, options);
    }
  }

  // No branch matched
  return undefined;
}

/**
 * Transform a value by evaluating template expressions and structural directives.
 */
export function transform(
  value: unknown,
  context: RenderContext,
  options?: RenderOptions,
): unknown {
  if (value === null || value === undefined) return value;

  if (typeof value === 'string') {
    return interpolateString(value, context, options);
  }

  if (Array.isArray(value)) {
    // Check if array is a pure conditional chain (template pattern for success/error chains).
    // Mixed arrays, such as a false #if followed by a #each directive, should keep rendering
    // later non-conditional entries instead of short-circuiting the whole array.
    const isConditionalObject = (item: unknown): boolean => (
      typeof item === 'object' && item !== null && !Array.isArray(item) &&
      Object.keys(item).length > 0 &&
      Object.keys(item).every(k => IF_REGEX.test(k) || ELSEIF_REGEX.test(k) || ELSE_REGEX.test(k))
    );

    if (value.length > 0 && value.every(isConditionalObject)) {
      // Process as a conditional chain across array items
      for (const item of value) {
        const itemKeys = Object.keys(item as Record<string, unknown>);
        for (const key of itemKeys) {
          const ifMatch = key.match(IF_REGEX) || key.match(ELSEIF_REGEX);
          if (ifMatch) {
            const condition = evaluate(ifMatch[1].trim(), context, options);
            if (condition) return transform((item as Record<string, unknown>)[key], context, options);
            continue;
          }
          if (ELSE_REGEX.test(key)) {
            return transform((item as Record<string, unknown>)[key], context, options);
          }
        }
      }
      return undefined;
    }

    return value
      .flatMap(item => {
        const transformed = transform(item, context, options);
        return Array.isArray(transformed) ? transformed : [transformed];
      })
      .filter(item => item !== undefined);
  }

  if (typeof value === 'object') {
    return processObject(value as Record<string, unknown>, context, options);
  }

  return value;
}
