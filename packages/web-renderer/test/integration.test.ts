import { describe, it, expect, beforeEach } from 'vitest';
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
