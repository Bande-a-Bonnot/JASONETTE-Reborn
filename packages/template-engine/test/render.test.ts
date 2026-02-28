import { describe, it, expect, vi } from 'vitest';
import { render, renderSync } from '../src/render.js';
import type { RenderContext, RenderOptions } from '../src/types.js';

describe('renderSync', () => {
  it('transforms simple template', () => {
    const template = { text: '{{$jason.name}}' };
    const context: RenderContext = { $jason: { name: 'Alice' } };
    expect(renderSync(template, context)).toEqual({ text: 'Alice' });
  });

  it('resolves $document self-references', () => {
    const document = {
      head: { title: 'Test' },
      body: { sections: [] },
    };
    const template = { title: '$document.head.title' };
    // Self-references need the @ key pattern, not bare strings
    const result = renderSync(template, { $jason: {} }, { document });
    // resolveSelfReferences resolves bare $document. strings too
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
    // Without fetch, the @ key stays as-is and gets transformed
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
    expect(callCount).toBeLessThanOrEqual(4); // 3 depth + initial
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
});
