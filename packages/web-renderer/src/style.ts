import type { JasonStyle } from './types.js';

/**
 * Convert a numeric-like value to CSS px.
 */
function toPx(value: string | number | undefined): string | undefined {
  if (value === undefined || value === null) return undefined;
  const s = String(value);
  if (/^-?\d+(\.\d+)?$/.test(s)) return `${s}px`;
  return s;
}

/**
 * Convert a Jasonette style object to CSS properties.
 */
export function resolveStyle(style?: JasonStyle): Record<string, string> {
  if (!style) return {};

  const css: Record<string, string> = {};

  if (style.font) css.fontFamily = style.font;
  if (style.size != null) css.fontSize = toPx(style.size) ?? '';
  if (style.color) css.color = style.color;

  if (style.background) {
    const bg = String(style.background);
    if (/^https?:\/\//.test(bg)) {
      css.backgroundImage = `url(${bg})`;
      css.backgroundSize = 'cover';
      css.backgroundPosition = 'center';
    } else {
      css.backgroundColor = bg;
    }
  }

  if (style.padding != null) css.padding = toPx(style.padding) ?? '';
  if (style.padding_left != null) css.paddingLeft = toPx(style.padding_left) ?? '';
  if (style.padding_right != null) css.paddingRight = toPx(style.padding_right) ?? '';
  if (style.padding_top != null) css.paddingTop = toPx(style.padding_top) ?? '';
  if (style.padding_bottom != null) css.paddingBottom = toPx(style.padding_bottom) ?? '';

  if (style.width != null) css.width = toPx(style.width) ?? '';
  if (style.height != null) css.height = toPx(style.height) ?? '';

  if (style.corner_radius != null) css.borderRadius = toPx(style.corner_radius) ?? '';
  if (style.border_width != null) css.borderWidth = toPx(style.border_width) ?? '';
  if (style.border_color) {
    css.borderColor = style.border_color;
    css.borderStyle = 'solid';
  }

  if (style.opacity != null) css.opacity = String(style.opacity);

  if (style.align) {
    css.textAlign = style.align;
    if (style.align === 'center') css.alignItems = 'center';
    else if (style.align === 'right') css.alignItems = 'flex-end';
  }

  if (style.spacing != null) css.gap = toPx(style.spacing) ?? '';

  // Position properties (for layers)
  if (style.top != null) { css.top = toPx(style.top as string | number) ?? ''; css.position = 'absolute'; }
  if (style.left != null) { css.left = toPx(style.left as string | number) ?? ''; css.position = 'absolute'; }
  if (style.right != null) { css.right = toPx(style.right as string | number) ?? ''; css.position = 'absolute'; }
  if (style.bottom != null) { css.bottom = toPx(style.bottom as string | number) ?? ''; css.position = 'absolute'; }

  return css;
}

/**
 * Apply CSS properties to a DOM element.
 */
export function applyStyle(el: HTMLElement, style?: JasonStyle): void {
  const css = resolveStyle(style);
  for (const [prop, value] of Object.entries(css)) {
    (el.style as unknown as Record<string, string>)[prop] = value;
  }
}

/**
 * Apply class-based styles from head.styles.
 */
export function applyClass(
  el: HTMLElement,
  className: string | undefined,
  headStyles: Record<string, JasonStyle>,
): void {
  if (!className) return;
  const classes = className.split(/\s+/);
  for (const cls of classes) {
    if (cls in headStyles) {
      applyStyle(el, headStyles[cls]);
    }
    el.classList.add(cls);
  }
}

/**
 * Generate a <style> element from head.styles definitions.
 */
export function generateStyleSheet(
  headStyles: Record<string, JasonStyle>,
): HTMLStyleElement {
  const style = document.createElement('style');
  style.setAttribute('data-jasonette', 'true');

  let css = '';
  for (const [name, styleDef] of Object.entries(headStyles)) {
    const props = resolveStyle(styleDef);
    const rules = Object.entries(props)
      .map(([k, v]) => `  ${k.replace(/([A-Z])/g, '-$1').toLowerCase()}: ${v};`)
      .join('\n');
    css += `.jasonette .${name} {\n${rules}\n}\n`;
  }

  style.textContent = css;
  return style;
}
