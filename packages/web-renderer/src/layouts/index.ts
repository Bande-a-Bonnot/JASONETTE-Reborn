import type { JasonComponent, JasonStyle } from '../types.js';
import { renderComponent } from '../components/index.js';
import { applyStyle, applyClass } from '../style.js';

/**
 * Check if a component is a layout (has type 'vertical' or 'horizontal').
 */
export function isLayout(component: JasonComponent): boolean {
  return component.type === 'vertical' || component.type === 'horizontal';
}

/**
 * Render a layout (vertical or horizontal) with its child components.
 */
export function renderLayout(
  component: JasonComponent,
  headStyles: Record<string, JasonStyle>,
): HTMLElement {
  const el = document.createElement('div');
  el.className = `jasonette-layout jasonette-layout-${component.type}`;
  el.setAttribute('data-jasonette-type', component.type ?? 'vertical');

  el.style.display = 'flex';
  el.style.flexDirection = component.type === 'horizontal' ? 'row' : 'column';
  el.style.alignItems = 'flex-start';

  if (component.type === 'vertical') {
    // Vertical: children take full width
    el.style.width = '100%';
  }

  // Apply layout-level styles
  applyStyle(el, component.style);
  applyClass(el, component.class, headStyles);

  // Render child components
  if (component.components && Array.isArray(component.components)) {
    for (const child of component.components) {
      const childEl = renderItem(child, headStyles);
      if (component.type === 'vertical') {
        childEl.style.maxWidth = '100%';
        childEl.style.width = '100%';
      } else {
        childEl.style.maxHeight = '100%';
      }
      el.appendChild(childEl);
    }
  }

  return el;
}

/**
 * Render an item — either a layout or a single component.
 * Attaches href/action handlers.
 */
export function renderItem(
  component: JasonComponent,
  headStyles: Record<string, JasonStyle>,
): HTMLElement {
  let el: HTMLElement;

  if (isLayout(component)) {
    el = renderLayout(component, headStyles);
  } else {
    el = renderComponent(component, headStyles);
  }

  // Attach href handler
  if (component.href) {
    el.style.cursor = 'pointer';
    el.setAttribute('data-href', JSON.stringify(component.href));
    el.addEventListener('click', (e) => {
      e.stopPropagation();
      const href = component.href!;
      if (href.view === 'web' && href.url?.startsWith('http')) {
        window.open(href.url, '_blank', 'noopener,noreferrer');
      } else if (href.url) {
        // Dispatch navigation event for the renderer to handle
        el.dispatchEvent(new CustomEvent('jasonette:navigate', {
          bubbles: true,
          detail: href,
        }));
      }
    });
  } else if (component.action || component.trigger) {
    el.style.cursor = 'pointer';
    if (component.action) el.setAttribute('data-action', JSON.stringify(component.action));
    if (component.trigger) el.setAttribute('data-trigger', component.trigger);

    if (!isControlComponent(component)) {
      el.addEventListener('click', (e) => {
        e.stopPropagation();
        el.dispatchEvent(new CustomEvent('jasonette:action', {
          bubbles: true,
          detail: component.action ?? { trigger: component.trigger },
        }));
      });
    }
  }

  return el;
}

function isControlComponent(component: JasonComponent): boolean {
  return component.type === 'textfield' ||
    component.type === 'textarea' ||
    component.type === 'slider' ||
    component.type === 'switch';
}
