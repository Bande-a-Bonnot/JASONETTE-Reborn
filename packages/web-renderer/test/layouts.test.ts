import { describe, it, expect } from 'vitest';
import { renderLayout, renderItem, isLayout } from '../src/layouts/index.js';

describe('isLayout', () => {
  it('returns true for vertical', () => {
    expect(isLayout({ type: 'vertical' })).toBe(true);
  });

  it('returns true for horizontal', () => {
    expect(isLayout({ type: 'horizontal' })).toBe(true);
  });

  it('returns false for label', () => {
    expect(isLayout({ type: 'label' })).toBe(false);
  });
});

describe('renderLayout', () => {
  it('renders vertical layout', () => {
    const el = renderLayout({
      type: 'vertical',
      components: [
        { type: 'label', text: 'A' },
        { type: 'label', text: 'B' },
      ],
    }, {});
    expect(el.style.flexDirection).toBe('column');
    expect(el.children.length).toBe(2);
  });

  it('renders horizontal layout', () => {
    const el = renderLayout({
      type: 'horizontal',
      components: [
        { type: 'label', text: 'A' },
        { type: 'label', text: 'B' },
      ],
    }, {});
    expect(el.style.flexDirection).toBe('row');
    expect(el.children.length).toBe(2);
  });

  it('applies spacing via gap', () => {
    const el = renderLayout({
      type: 'vertical',
      style: { spacing: 10 },
      components: [
        { type: 'label', text: 'A' },
      ],
    }, {});
    expect(el.style.gap).toBe('10px');
  });

  it('handles nested layouts', () => {
    const el = renderLayout({
      type: 'vertical',
      components: [
        {
          type: 'horizontal',
          components: [
            { type: 'label', text: 'A' },
            { type: 'label', text: 'B' },
          ],
        },
        { type: 'label', text: 'C' },
      ],
    }, {});
    expect(el.children.length).toBe(2);
    const nested = el.children[0] as HTMLElement;
    expect(nested.style.flexDirection).toBe('row');
    expect(nested.children.length).toBe(2);
  });
});

describe('renderItem', () => {
  it('renders component for non-layout types', () => {
    const el = renderItem({ type: 'label', text: 'Hello' }, {});
    expect(el.tagName).toBe('P');
  });

  it('renders layout for layout types', () => {
    const el = renderItem({
      type: 'vertical',
      components: [{ type: 'label', text: 'A' }],
    }, {});
    expect(el.style.flexDirection).toBe('column');
  });

  it('attaches href handler', () => {
    const el = renderItem({
      type: 'label',
      text: 'Link',
      href: { url: 'https://example.com', view: 'web' },
    }, {});
    expect(el.style.cursor).toBe('pointer');
    expect(el.getAttribute('data-href')).toBeTruthy();
  });
});
