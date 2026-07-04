import { describe, it, expect, beforeEach } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { JasonetteRenderer } from '../src/renderer.js';
import type { JasonDocument } from '../src/types.js';

describe('JasonetteRenderer', () => {
  let root: HTMLElement;
  let renderer: JasonetteRenderer;

  beforeEach(() => {
    root = document.createElement('div');
    document.body.appendChild(root);
    renderer = new JasonetteRenderer(root);
  });

  it('adds jasonette class to root', () => {
    expect(root.classList.contains('jasonette')).toBe(true);
  });

  it('renders static body', () => {
    const doc: JasonDocument = {
      $jason: {
        head: { title: 'Test' },
        body: {
          sections: [{
            items: [
              { type: 'label', text: 'Hello World' },
            ],
          }],
        },
      },
    };

    renderer.renderDocument(doc);
    expect(root.querySelector('.jasonette-sections')).not.toBeNull();
    expect(root.textContent).toContain('Hello World');
  });

  it('renders templated body', () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          title: 'Templated',
          data: { name: 'Alice' },
          templates: {
            body: {
              sections: [{
                items: [{
                  type: 'label',
                  text: '{{name}}',
                }],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    expect(root.textContent).toContain('Alice');
  });

  it('renders #each template', () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          title: 'Each',
          data: {
            items: ['one', 'two', 'three'],
          },
          templates: {
            body: {
              sections: [{
                items: {
                  '{{#each items}}': {
                    type: 'label',
                    text: '{{$jason}}',
                  },
                },
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    const labels = root.querySelectorAll('[data-jasonette-type="label"]');
    expect(labels.length).toBe(3);
    expect(labels[0].textContent).toBe('one');
    expect(labels[1].textContent).toBe('two');
    expect(labels[2].textContent).toBe('three');
  });

  it('renders header', () => {
    const doc: JasonDocument = {
      $jason: {
        body: {
          header: { title: 'My App' },
          sections: [],
        },
      },
    };

    renderer.renderDocument(doc);
    const header = root.querySelector('.jasonette-header');
    expect(header).not.toBeNull();
    expect(header?.textContent).toContain('My App');
  });

  it('renders with head styles', () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          styles: {
            red: { color: '#ff0000' },
          },
        },
        body: {
          sections: [{
            items: [
              { type: 'label', text: 'Red', class: 'red' },
            ],
          }],
        },
      },
    };

    renderer.renderDocument(doc);
    const styleEl = root.querySelector('style[data-jasonette]');
    expect(styleEl).not.toBeNull();
    expect(styleEl?.textContent).toContain('.red');
    expect(styleEl?.textContent).toContain('#ff0000');
  });

  it('renders html body background as web container iframe', () => {
    const doc: JasonDocument = {
      $jason: {
        body: {
          background: {
            type: 'html',
            url: 'https://example.com/background.html',
          },
          sections: [{ items: [{ type: 'label', text: 'Foreground' }] }],
        },
      },
    };

    renderer.renderDocument(doc);
    const iframe = root.querySelector('.jasonette-background-web') as HTMLIFrameElement;
    const sections = root.querySelector('.jasonette-sections');
    expect(iframe).not.toBeNull();
    expect(iframe.src).toContain('https://example.com/background.html');
    expect(sections).not.toBeNull();
    expect(Array.from(root.children).indexOf(iframe)).toBeLessThan(Array.from(root.children).indexOf(sections!));
    expect(root.textContent).toContain('Foreground');
  });

  it('renders legacy body.style.background html text as web container iframe', () => {
    const doc = {
      $jason: {
        head: {
          templates: {
            body: {
              style: {
                background: {
                  type: 'html',
                  text: '<html><body>Backdrop</body></html>',
                },
              },
              sections: [{ items: [{ type: 'label', text: 'Foreground' }] }],
            },
          },
        },
      },
    } as JasonDocument;

    renderer.renderDocument(doc);
    const iframe = root.querySelector('.jasonette-background-web') as HTMLIFrameElement;
    expect(iframe).not.toBeNull();
    expect(iframe.srcdoc).toContain('Backdrop');
    expect(root.textContent).toContain('Foreground');
  });

  it('stylesheet anchors web backgrounds to the renderer root behind content', () => {
    const css = readFileSync(resolve(import.meta.dirname, '../src/jasonette.css'), 'utf-8');
    expect(css).toContain('.jasonette {');
    expect(css).toContain('position: relative;');
    expect(css).toContain('overflow: hidden;');
    expect(css).toContain('.jasonette-background-web');
    expect(css).toContain('position: absolute;');
    expect(css).toContain('z-index: 0;');
    expect(css).toContain('.jasonette > :not(.jasonette-background-web)');
    expect(css).toContain('z-index: 1;');
  });

  it('renders layout with components', () => {
    const doc: JasonDocument = {
      $jason: {
        body: {
          sections: [{
            items: [{
              type: 'horizontal',
              style: { spacing: 10 },
              components: [
                { type: 'image', url: 'https://img.png', style: { width: 50 } },
                { type: 'label', text: 'Username' },
              ],
            }],
          }],
        },
      },
    };

    renderer.renderDocument(doc);
    const layout = root.querySelector('.jasonette-layout-horizontal');
    expect(layout).not.toBeNull();
    expect(layout?.children.length).toBe(2);
  });

  it('exposes state', () => {
    const state = renderer.getState();
    expect(state.local).toEqual({});
    expect(state.history).toEqual([]);
  });
});
