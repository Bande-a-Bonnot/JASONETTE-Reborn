import { transform } from './transformer.js';
import type { RenderContext, RenderOptions } from './types.js';

const MAX_MIXIN_DEPTH = 5;
const MAX_MIXIN_SIZE = 1_048_576; // 1MB

// In-memory cache for fetched mixins
const mixinCache = new Map<string, { value: unknown; timestamp: number }>();
const MIXIN_CACHE_TTL = 60_000; // 60 seconds

/**
 * Validate a mixin URL per AD-10 policy.
 * Only HTTPS is allowed for remote mixins.
 */
function isValidMixinUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Parse `key@url` selector notation (Form C — Tier 2 stub).
 * Returns { key, url } or null if not a selector.
 */
function parseSelectorMixin(value: string): { key: string; url: string } | null {
  const atIndex = value.indexOf('@');
  if (atIndex <= 0) return null;

  const key = value.slice(0, atIndex);
  const url = value.slice(atIndex + 1);

  if (!url.startsWith('https://')) return null;
  return { key, url };
}

/**
 * Resolve `@` (self) references within a document.
 * Example: { "$jason": { "head": { "@": "$document.head" } } }
 */
function resolveSelfReferences(
  value: unknown,
  document: Record<string, unknown>,
  depth = 0,
): unknown {
  if (depth > 10) return value;

  if (typeof value === 'string' && value.startsWith('$document.')) {
    const path = value.slice('$document.'.length).split('.');
    let result: unknown = document;
    for (const key of path) {
      if (result && typeof result === 'object' && !Array.isArray(result)) {
        result = (result as Record<string, unknown>)[key];
      } else {
        return undefined;
      }
    }
    return result;
  }

  if (Array.isArray(value)) {
    return value.map(item => resolveSelfReferences(item, document, depth + 1));
  }

  if (value && typeof value === 'object') {
    const obj = value as Record<string, unknown>;

    // Handle "@" key — inline mixin from document
    if ('@' in obj && typeof obj['@'] === 'string' && obj['@'].startsWith('$document.')) {
      const resolved = resolveSelfReferences(obj['@'], document, depth + 1);
      if (resolved && typeof resolved === 'object' && !Array.isArray(resolved)) {
        const { '@': _, ...rest } = obj;
        return { ...(resolved as Record<string, unknown>), ...rest };
      }
    }

    const result: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(obj)) {
      result[key] = resolveSelfReferences(val, document, depth + 1);
    }
    return result;
  }

  return value;
}

/**
 * Fetch a mixin with caching and size limits.
 */
async function fetchMixin(
  url: string,
  fetchFn: (url: string) => Promise<unknown>,
): Promise<unknown> {
  // Check cache
  const cached = mixinCache.get(url);
  if (cached && Date.now() - cached.timestamp < MIXIN_CACHE_TTL) {
    return cached.value;
  }

  const result = await fetchFn(url);

  // Size check — estimate via JSON stringification
  const serialized = JSON.stringify(result);
  if (serialized && serialized.length > MAX_MIXIN_SIZE) {
    return undefined;
  }

  // Cache the result
  mixinCache.set(url, { value: result, timestamp: Date.now() });

  return result;
}

/**
 * Resolve mixins — objects with `@` key pointing to a URL or local ref.
 */
async function resolveMixins(
  value: unknown,
  options: RenderOptions | undefined,
  depth = 0,
): Promise<unknown> {
  const maxDepth = options?.maxMixinDepth ?? MAX_MIXIN_DEPTH;
  if (depth > maxDepth) return value;

  if (Array.isArray(value)) {
    const results = [];
    for (const item of value) {
      results.push(await resolveMixins(item, options, depth));
    }
    return results;
  }

  if (value && typeof value === 'object') {
    const obj = value as Record<string, unknown>;

    // Check for remote mixin: { "@": "https://..." }
    if ('@' in obj && typeof obj['@'] === 'string') {
      const mixinRef = obj['@'] as string;

      // Form C: key@url selector (Tier 2 stub)
      const selector = parseSelectorMixin(mixinRef);
      if (selector) {
        if (!options?.fetch || !isValidMixinUrl(selector.url)) return obj;

        try {
          const fetched = await fetchMixin(selector.url, options.fetch);
          if (fetched && typeof fetched === 'object' && !Array.isArray(fetched)) {
            const selected = (fetched as Record<string, unknown>)[selector.key];
            if (selected && typeof selected === 'object' && !Array.isArray(selected)) {
              const { '@': _, ...rest } = obj;
              const merged = { ...(selected as Record<string, unknown>), ...rest };
              return resolveMixins(merged, options, depth + 1);
            }
            return selected;
          }
          return undefined;
        } catch {
          return undefined;
        }
      }

      // Form B: direct URL
      if (mixinRef.startsWith('http://') || mixinRef.startsWith('https://')) {
        if (!isValidMixinUrl(mixinRef)) return obj; // Reject non-HTTPS
        if (!options?.fetch) return obj;

        try {
          const fetched = await fetchMixin(mixinRef, options.fetch);
          if (fetched && typeof fetched === 'object' && !Array.isArray(fetched)) {
            const { '@': _, ...rest } = obj;
            const merged = { ...(fetched as Record<string, unknown>), ...rest };
            return resolveMixins(merged, options, depth + 1);
          }
          return fetched;
        } catch {
          return undefined;
        }
      }
    }

    // Recurse into all values
    const result: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(obj)) {
      result[key] = await resolveMixins(val, options, depth);
    }
    return result;
  }

  return value;
}

/**
 * Clear the mixin fetch cache.
 */
export function clearMixinCache(): void {
  mixinCache.clear();
}

/**
 * Render a JSON template against data.
 *
 * 1. Resolve self-references (@)
 * 2. Resolve remote mixins (@ with URLs)
 * 3. Transform template expressions and directives
 */
export async function render(
  template: unknown,
  context: RenderContext,
  options?: RenderOptions,
): Promise<unknown> {
  let processed = template;

  // Step 1: Resolve $document self-references
  if (options?.document) {
    processed = resolveSelfReferences(processed, options.document);
  }

  // Step 2: Resolve remote mixins
  if (options?.fetch) {
    processed = await resolveMixins(processed, options);
  }

  // Step 3: Transform expressions and directives
  return transform(processed, context, options);
}

/**
 * Synchronous render — skips mixin resolution (no async needed).
 */
export function renderSync(
  template: unknown,
  context: RenderContext,
  options?: RenderOptions,
): unknown {
  let processed = template;

  if (options?.document) {
    processed = resolveSelfReferences(processed, options.document);
  }

  return transform(processed, context, options);
}
