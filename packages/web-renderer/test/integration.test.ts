import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { JasonetteRenderer } from '../src/renderer.js';
import type { JasonDocument } from '../src/types.js';

function loadFixture(relativePath: string): JasonDocument {
  const fullPath = resolve(import.meta.dirname, '../../../Jasonpedia', relativePath);
  return JSON.parse(readFileSync(fullPath, 'utf-8'));
}

describe('Integration: Jasonpedia fixtures', () => {
  let root: HTMLElement;
  let renderer: JasonetteRenderer;

  beforeEach(() => {
    root = document.createElement('div');
    document.body.appendChild(root);
    renderer = new JasonetteRenderer(root);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    document.body.innerHTML = '';
  });

  it('resolves legacy webcontainer + includes and local $document references on load', async () => {
    const entry = loadFixture('webcontainer/pdf.json');
    const template = loadFixture('webcontainer/template.json');
    const responses: Record<string, JasonDocument> = {
      'https://example.com/webcontainer/pdf.json': entry,
      'https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/template.json': template,
    };
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
      url,
      json: async () => responses[url],
    } as Response)));

    await renderer.load('https://example.com/webcontainer/pdf.json');

    expect(root.querySelector('.jasonette-header-title')?.textContent).toBe('PDF.json');
    const iframe = root.querySelector('.jasonette-background-web') as HTMLIFrameElement;
    expect(iframe).not.toBeNull();
    expect(iframe.srcdoc).toContain('mozilla.github.io/pdf.js');
  });

  it('resolves legacy + selector includes inside Jasonpedia feed templates', async () => {
    const entry = loadFixture('webcontainer/feed/index.json');
    const db = loadFixture('webcontainer/feed/db.json');
    const item = loadFixture('webcontainer/feed/item.json');
    const special = loadFixture('webcontainer/feed/special_item.json');
    const animated = loadFixture('webcontainer/feed/animated_item.json');
    const responses: Record<string, unknown> = {
      'https://example.com/webcontainer/feed/index.json': entry,
      'https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/db.json': db,
      'https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/item.json': item,
      'https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/special_item.json': special,
      'https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/animated_item.json': animated,
    };
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
      url,
      json: async () => responses[url],
    } as Response)));

    await renderer.load('https://example.com/webcontainer/feed/index.json');

    expect(root.querySelector('.jasonette-header-title')?.textContent).toBe('the feed');
    expect(root.textContent).toContain('ethan');
    expect(root.textContent).toContain('Check out this animation');
    expect(root.querySelectorAll('.jasonette-html iframe').length).toBeGreaterThan(2);
    expect(vi.mocked(fetch)).toHaveBeenCalledWith('https://bande-a-bonnot.github.io/JASONETTE-Reborn/Jasonpedia/webcontainer/feed/item.json');
  });

  it('resolves duplicate same-URL selector includes independently', async () => {
    const entry: JasonDocument = {
      $jason: {
        head: {
          data: {
            first: { '+': 'first@https://example.com/parts.json' },
            second: { '+': 'second@https://example.com/parts.json' },
          },
          templates: {
            body: {
              sections: [{ items: [{ type: 'label', text: '{{first.text}} {{second.text}}' }] }],
            },
          },
        },
      },
    };
    const parts = { first: { text: 'one' }, second: { text: 'two' } };
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
      url,
      json: async () => url.endsWith('parts.json') ? parts : entry,
    } as Response)));

    await renderer.load('https://example.com/selector-entry.json');

    expect(root.textContent).toContain('one two');
    expect(vi.mocked(fetch)).toHaveBeenCalledWith('https://example.com/parts.json');
  });

  it('blocks unsafe legacy + include URL schemes', async () => {
    const entry: JasonDocument = {
      $jason: {
        head: {
          data: { unsafe: { '+': 'file:///tmp/secret.json' } },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Safe include handling' }] }] },
          },
        },
      },
    };
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
      url,
      json: async () => entry,
    } as Response)));

    await renderer.load('https://example.com/unsafe.json');

    expect(root.textContent).toContain('Safe include handling');
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(1);
    expect(vi.mocked(fetch)).not.toHaveBeenCalledWith('file:///tmp/secret.json');
  });

  it('renders core/index.json — navigation hub', () => {
    const doc = loadFixture('core/index.json');
    renderer.renderDocument(doc);

    // Header with menu
    const menu = root.querySelector('.jasonette-header-menu');
    expect(menu).not.toBeNull();
    expect(menu?.textContent).toBe('View JSON');

    // Three sections with vertical layouts
    const sections = root.querySelectorAll('.jasonette-section');
    expect(sections.length).toBe(3);

    // Labels with class-based styles
    const boldLabels = root.querySelectorAll('.bold');
    expect(boldLabels.length).toBe(3);
    expect(boldLabels[0].textContent).toBe('$href');
    expect(boldLabels[1].textContent).toBe('$render');
    expect(boldLabels[2].textContent).toBe('$snapshot');
  });

  it('renders core/render/index.json — render demos', () => {
    const doc = loadFixture('core/render/index.json');
    renderer.renderDocument(doc);

    const headerTitle = root.querySelector('.jasonette-header-title');
    expect(headerTitle?.textContent).toBe('$render');

    // Has $foreground action stored
    const state = renderer.getState();
    expect(state.actions['$foreground']).toBeDefined();
    expect(state.actions['$foreground'].type).toBe('$reload');
  });

  it('renders core/href/index.json — href navigation', () => {
    const doc = loadFixture('core/href/index.json');
    renderer.renderDocument(doc);

    const sections = root.querySelectorAll('.jasonette-section');
    expect(sections.length).toBeGreaterThan(0);
  });

  it('renders demo.json — main demo page', () => {
    const doc = loadFixture('demo.json');
    renderer.renderDocument(doc);

    const sections = root.querySelectorAll('.jasonette-section');
    expect(sections.length).toBeGreaterThan(0);
  });

  it('renders template/each.json — template with #each', () => {
    const doc = loadFixture('template/each.json');
    renderer.renderDocument(doc);

    // This fixture uses templates, so it should render via template engine
    const state = renderer.getState();
    expect(state.document).not.toBeNull();
  });

  it('renders view/component/html/index.json with component css in iframe srcdoc', () => {
    const doc = loadFixture('view/component/html/index.json');
    renderer.renderDocument(doc);

    const iframe = root.querySelector('.jasonette-html iframe') as HTMLIFrameElement;
    expect(iframe).not.toBeNull();
    expect(iframe.srcdoc).toContain('<style>img{width: 100%;} p{font-family: Helvetica; font-size: 14px;}</style>');
    expect(iframe.srcdoc).toContain('Nexus devices');
  });

  it('head styles generate a stylesheet', () => {
    const doc = loadFixture('core/index.json');
    renderer.renderDocument(doc);

    const styleEl = root.querySelector('style[data-jasonette]');
    expect(styleEl).not.toBeNull();
    expect(styleEl?.textContent).toContain('.bold');
    expect(styleEl?.textContent).toContain('.normal');
    expect(styleEl?.textContent).toContain('HelveticaNeue-CondensedBold');
  });

  it('href items have cursor pointer and data attribute', () => {
    const doc = loadFixture('core/index.json');
    renderer.renderDocument(doc);

    const hrefItems = root.querySelectorAll('[data-href]');
    expect(hrefItems.length).toBeGreaterThan(0);

    for (const item of hrefItems) {
      expect((item as HTMLElement).style.cursor).toBe('pointer');
    }
  });
});
