import { describe, it, expect } from 'vitest';
import { resolveStyle } from '../src/style.js';

describe('resolveStyle', () => {
  it('returns empty for undefined style', () => {
    expect(resolveStyle(undefined)).toEqual({});
  });

  it('resolves font properties', () => {
    const css = resolveStyle({ font: 'Helvetica', size: 14, color: '#ff0000' });
    expect(css.fontFamily).toBe('Helvetica');
    expect(css.fontSize).toBe('14px');
    expect(css.color).toBe('#ff0000');
  });

  it('resolves background color', () => {
    const css = resolveStyle({ background: '#ffffff' });
    expect(css.backgroundColor).toBe('#ffffff');
  });

  it('resolves background URL as image', () => {
    const css = resolveStyle({ background: 'https://example.com/bg.jpg' });
    expect(css.backgroundImage).toBe('url(https://example.com/bg.jpg)');
    expect(css.backgroundSize).toBe('cover');
  });

  it('resolves padding', () => {
    const css = resolveStyle({ padding: 10, padding_left: 5 });
    expect(css.padding).toBe('10px');
    expect(css.paddingLeft).toBe('5px');
  });

  it('resolves dimensions', () => {
    const css = resolveStyle({ width: 100, height: '50' });
    expect(css.width).toBe('100px');
    expect(css.height).toBe('50px');
  });

  it('resolves corner_radius', () => {
    const css = resolveStyle({ corner_radius: 5 });
    expect(css.borderRadius).toBe('5px');
  });

  it('resolves border', () => {
    const css = resolveStyle({ border_width: 1, border_color: '#000' });
    expect(css.borderWidth).toBe('1px');
    expect(css.borderColor).toBe('#000');
    expect(css.borderStyle).toBe('solid');
  });

  it('resolves text align', () => {
    const css = resolveStyle({ align: 'center' });
    expect(css.textAlign).toBe('center');
    expect(css.alignItems).toBe('center');
  });

  it('resolves spacing as gap', () => {
    const css = resolveStyle({ spacing: 10 });
    expect(css.gap).toBe('10px');
  });

  it('resolves position properties', () => {
    const css = resolveStyle({ top: 10, left: 20 });
    expect(css.top).toBe('10px');
    expect(css.left).toBe('20px');
    expect(css.position).toBe('absolute');
  });
});
