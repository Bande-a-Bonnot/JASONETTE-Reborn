import type { JasonComponent, JasonStyle } from '../types.js';
import { applyStyle, applyClass } from '../style.js';

export type ComponentRenderer = (
  component: JasonComponent,
  headStyles: Record<string, JasonStyle>,
) => HTMLElement;

const renderers: Record<string, ComponentRenderer> = {};

export function registerComponent(type: string, renderer: ComponentRenderer): void {
  Object.defineProperty(renderers, type, {
    value: renderer,
    enumerable: true,
    writable: true,
    configurable: true,
  });
}

export function ownValue(source: unknown, key: string): unknown {
  if (!source || typeof source !== 'object' || Array.isArray(source) || !Object.hasOwn(source, key)) {
    return undefined;
  }
  return (source as Record<string, unknown>)[key];
}

function selectHtmlSource(component: unknown): { kind: 'inline' | 'url'; value: string } | undefined {
  const text = ownValue(component, 'text');
  if (typeof text === 'string' && text.length > 0) return { kind: 'inline', value: text };

  const url = ownValue(component, 'url');
  if (typeof url === 'string' && url.length > 0) return { kind: 'url', value: url };

  return undefined;
}

export function createHtmlIframe(component: unknown): HTMLIFrameElement | undefined {
  if (ownValue(component, 'type') !== 'html') return undefined;
  const source = selectHtmlSource(component);
  if (!source) return undefined;

  const iframe = document.createElement('iframe');
  iframe.setAttribute('sandbox', 'allow-scripts');

  if (source.kind === 'inline') {
    const css = ownValue(component, 'css');
    iframe.srcdoc = htmlSrcdoc(source.value, typeof css === 'string' && css.length > 0 ? css : undefined);
  } else {
    iframe.src = source.value;
  }

  return iframe;
}

export function renderComponent(
  component: JasonComponent,
  headStyles: Record<string, JasonStyle>,
): HTMLElement {
  const authoredType = ownValue(component, 'type');
  const type = typeof authoredType === 'string' ? authoredType : 'label';
  const renderer = Object.hasOwn(renderers, type) ? renderers[type] : undefined;

  if (typeof renderer !== 'function') {
    const el = document.createElement('div');
    el.textContent = `[Unknown: ${type}]`;
    el.setAttribute('data-jasonette-type', type);
    return el;
  }

  const el = renderer(component, headStyles);
  el.setAttribute('data-jasonette-type', type);

  // Apply inline style
  applyStyle(el, component.style);
  // Apply class-based styles
  applyClass(el, component.class, headStyles);

  return el;
}

// --- Built-in Components ---

registerComponent('label', (c) => {
  const el = document.createElement('p');
  el.textContent = c.text ?? '';
  el.className = 'jasonette-label';
  return el;
});

registerComponent('button', (c) => {
  const el = document.createElement('button');
  el.className = 'jasonette-button';
  if (c.url) {
    const img = document.createElement('img');
    img.src = c.url;
    img.alt = c.text ?? '';
    el.appendChild(img);
  } else {
    el.textContent = c.text ?? '';
  }
  return el;
});

registerComponent('image', (c) => {
  const el = document.createElement('img');
  el.className = 'jasonette-image';
  if (c.url) el.src = c.url;
  if (c.text) el.alt = c.text;
  return el;
});

registerComponent('textfield', (c) => {
  const el = document.createElement('input');
  el.className = 'jasonette-textfield';
  el.type = (c.keyboard as string) ?? 'text';
  if (c.name) el.name = c.name;
  if (c.placeholder) el.placeholder = c.placeholder;
  if (c.value != null) el.value = String(c.value);
  return el;
});

registerComponent('textarea', (c) => {
  const el = document.createElement('textarea');
  el.className = 'jasonette-textarea';
  if (c.name) el.name = c.name;
  if (c.placeholder) el.placeholder = c.placeholder;
  if (c.value != null) el.value = String(c.value);
  return el;
});

registerComponent('html', (c) => {
  const el = document.createElement('div');
  el.className = 'jasonette-html';
  const iframe = createHtmlIframe(c);
  if (iframe) {
    iframe.style.width = '100%';
    iframe.style.border = 'none';
    el.appendChild(iframe);
  }
  return el;
});

export function htmlSrcdoc(html: string, css?: string): string {
  if (typeof css !== 'string' || css.length === 0) return html;
  return `<style>${escapeStyleContent(css)}</style>${html}`;
}

function escapeStyleContent(css: string): string {
  return css.replace(/<\/style/gi, '<\\/style');
}

registerComponent('slider', (c) => {
  const el = document.createElement('input');
  el.className = 'jasonette-slider';
  el.type = 'range';
  if (c.name) el.name = c.name;
  if (c.value != null) el.value = String(c.value);
  return el;
});

registerComponent('space', (c) => {
  const el = document.createElement('div');
  el.className = 'jasonette-space';
  if (!c.style?.height) {
    el.style.flex = '1';
  }
  return el;
});

registerComponent('switch', (c) => {
  const label = document.createElement('label');
  label.className = 'jasonette-switch';
  const input = document.createElement('input');
  input.type = 'checkbox';
  if (c.name) input.name = c.name;
  if (c.value) input.checked = true;
  label.appendChild(input);
  const slider = document.createElement('span');
  slider.className = 'jasonette-switch-slider';
  label.appendChild(slider);
  return label;
});

registerComponent('map', (c) => {
  const el = document.createElement('div');
  el.className = 'jasonette-map';
  el.textContent = '[Map — Tier 2]';
  el.style.background = '#e0e0e0';
  el.style.minHeight = '200px';
  el.style.display = 'flex';
  el.style.alignItems = 'center';
  el.style.justifyContent = 'center';
  return el;
});
