import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, renderSync, clearMixinCache } from '../src/render.js';
import type { RenderContext, RenderOptions } from '../src/types.js';

beforeEach(() => {
  clearMixinCache();
});

describe('renderSync', () => {
  it('transforms simple template', () => {
    const template = { text: '{{$jason.name}}' };
    const context: RenderContext = { $jason: { name: 'Alice' } };
    expect(renderSync(template, context)).toEqual({ text: 'Alice' });
  });

  it('resolves $document.path strings', () => {
    const document = {
      head: { title: 'Test' },
      body: { sections: [] },
    };
    const template = { title: '$document.head.title' };
    const result = renderSync(template, { $jason: {} }, { document });
    expect(result).toEqual({ title: 'Test' });
  });

  it('resolves @ self-reference in object', () => {
    const document = {
      head: { title: 'My App' },
      body: {},
    };
    const template = {
      '@': '$document.head',
      extra: 'added',
    };
    const result = renderSync(template, { $jason: {} }, { document });
    expect(result).toEqual({ title: 'My App', extra: 'added' });
  });

  it('handles nested $document references', () => {
    const document = {
      components: {
        label: { type: 'label', style: { color: 'black' } },
      },
    };
    const template = {
      items: [{ '@': '$document.components.label' }],
    };
    const result = renderSync(template, { $jason: {} }, { document });
    expect(result).toEqual({
      items: [{ type: 'label', style: { color: 'black' } }],
    });
  });

  it('returns undefined for invalid $document path', () => {
    const document = { head: { title: 'Test' } };
    const template = { val: '$document.missing.deep' };
    const result = renderSync(template, { $jason: {} }, { document });
    expect(result).toEqual({ val: undefined });
  });
});

describe('render (async)', () => {
  it('resolves remote mixin via fetch', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      type: 'label',
      text: 'Remote Label',
    });

    const template = {
      components: [
        { '@': 'https://example.com/component.json' },
      ],
    };

    const result = await render(template, { $jason: {} }, { fetch: mockFetch });
    expect(mockFetch).toHaveBeenCalledWith('https://example.com/component.json');
    expect(result).toEqual({
      components: [{ type: 'label', text: 'Remote Label' }],
    });
  });

  it('merges local overrides with remote mixin', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      type: 'label',
      text: 'Default Text',
      style: { color: 'black' },
    });

    const template = {
      '@': 'https://example.com/base.json',
      text: 'Overridden',
    };

    const result = await render(template, { $jason: {} }, { fetch: mockFetch });
    expect(result).toEqual({
      type: 'label',
      text: 'Overridden',
      style: { color: 'black' },
    });
  });

  it('skips mixin resolution when no fetch provided', async () => {
    const template = {
      '@': 'https://example.com/component.json',
      text: 'fallback',
    };

    const result = await render(template, { $jason: {} });
    expect(result).toEqual({
      '@': 'https://example.com/component.json',
      text: 'fallback',
    });
  });

  it('handles fetch error gracefully', async () => {
    const mockFetch = vi.fn().mockRejectedValue(new Error('Network error'));

    const template = {
      '@': 'https://example.com/fail.json',
    };

    const result = await render(template, { $jason: {} }, { fetch: mockFetch });
    expect(result).toBeUndefined();
  });

  it('limits mixin recursion depth', async () => {
    let callCount = 0;
    const mockFetch = vi.fn().mockImplementation(async () => {
      callCount++;
      return { '@': 'https://example.com/recursive.json', depth: callCount };
    });

    const template = { '@': 'https://example.com/recursive.json' };

    await render(template, { $jason: {} }, { fetch: mockFetch, maxMixinDepth: 3 });
    expect(callCount).toBeLessThanOrEqual(4);
  });

  it('transforms after mixin resolution', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      text: '{{$jason.name}}',
    });

    const template = {
      '@': 'https://example.com/template.json',
    };

    const result = await render(template, { $jason: { name: 'Dynamic' } }, { fetch: mockFetch });
    expect(result).toEqual({ text: 'Dynamic' });
  });

  it('handles non-URL @ values without fetch', async () => {
    const template = {
      '@': 'local-ref',
      text: 'test',
    };

    const result = await render(template, { $jason: {} });
    expect(result).toEqual({ '@': 'local-ref', text: 'test' });
  });

  it('rejects HTTP (non-HTTPS) URLs', async () => {
    const mockFetch = vi.fn().mockResolvedValue({ type: 'label' });

    const template = {
      '@': 'http://insecure.example.com/mixin.json',
    };

    const result = await render(template, { $jason: {} }, { fetch: mockFetch });
    // Should not call fetch for non-HTTPS
    expect(mockFetch).not.toHaveBeenCalled();
    expect(result).toEqual({
      '@': 'http://insecure.example.com/mixin.json',
    });
  });

  it('caches fetched mixins', async () => {
    const mockFetch = vi.fn().mockResolvedValue({ type: 'label', text: 'Cached' });

    const template = {
      a: { '@': 'https://example.com/cached.json' },
      b: { '@': 'https://example.com/cached.json' },
    };

    await render(template, { $jason: {} }, { fetch: mockFetch });
    // Should only fetch once due to caching
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('handles key@url selector (Form C)', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      header: { type: 'label', text: 'Header' },
      footer: { type: 'label', text: 'Footer' },
    });

    const template = {
      '@': 'header@https://example.com/parts.json',
    };

    const result = await render(template, { $jason: {} }, { fetch: mockFetch });
    expect(result).toEqual({ type: 'label', text: 'Header' });
  });

  it('rejects oversized mixin responses', async () => {
    const largeData: Record<string, string> = {};
    for (let i = 0; i < 50000; i++) {
      largeData[`key${i}`] = 'x'.repeat(30);
    }
    const mockFetch = vi.fn().mockResolvedValue(largeData);

    const template = { '@': 'https://example.com/huge.json' };
    const result = await render(template, { $jason: {} }, { fetch: mockFetch });
    expect(result).toBeUndefined();
  });
});
