import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { JasonetteRenderer } from '../src/renderer.js';
import { executeAction } from '../src/actions/index.js';
import type { JasonDocument } from '../src/types.js';

function loadFixture(relativePath: string): JasonDocument {
  const fullPath = resolve(import.meta.dirname, '../../../Jasonpedia', relativePath);
  return JSON.parse(readFileSync(fullPath, 'utf-8'));
}

describe('web action/render parity', () => {
  let root: HTMLElement;
  let renderer: JasonetteRenderer;

  beforeEach(() => {
    root = document.createElement('div');
    document.body.appendChild(root);
    renderer = new JasonetteRenderer(root);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    document.body.innerHTML = '';
  });

  it('executes component action and re-renders from $get state', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{
                items: [
                  {
                    type: 'button',
                    text: 'Set message',
                    action: {
                      type: '$set',
                      options: { message: 'Hello from action' },
                      success: { type: '$render' },
                    },
                  },
                  { type: 'label', text: '{{$get.message}}' },
                ],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    expect(root.textContent).not.toContain('Hello from action');

    root.querySelector('button')?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();

    expect(root.textContent).toContain('Hello from action');
  });

  it('executes legacy component trigger via head.actions', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            send: {
              type: '$set',
              options: { message: 'Hello from trigger' },
              success: { type: '$render' },
            },
          },
          templates: {
            body: {
              sections: [{
                items: [
                  { type: 'button', text: 'Send', trigger: 'send' },
                  { type: 'label', text: '{{$get.message}}' },
                ],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    root.querySelector('button')?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();

    expect(root.textContent).toContain('Hello from trigger');
  });

  it('updates named textfield values into $get for later render actions', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{
                items: [
                  { type: 'textfield', name: 'message', placeholder: 'Message' },
                  { type: 'button', text: 'Render', action: { type: '$render' } },
                  { type: 'label', text: '{{$get.message}}' },
                ],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    const input = root.querySelector('input[name="message"]') as HTMLInputElement;
    input.value = 'Typed message';
    input.dispatchEvent(new InputEvent('input', { bubbles: true }));

    root.querySelector('button')?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();

    expect(renderer.getState().local.message).toBe('Typed message');
    expect(root.textContent).toContain('Typed message');
  });

  it('executes authored control action after updating $get state', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{
                items: [
                  { type: 'slider', name: 'gauge', value: 10, action: { type: '$render' } },
                  { type: 'label', text: 'Gauge {{$get.gauge}}' },
                ],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    const slider = root.querySelector('input[name="gauge"]') as HTMLInputElement;
    slider.value = '42';
    slider.dispatchEvent(new InputEvent('input', { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();

    expect(renderer.getState().local.gauge).toBe('42');
    expect(root.textContent).toContain('Gauge 42');
  });

  it('stores switch values as booleans before running control actions', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{
                items: [
                  { type: 'switch', name: 'enabled', action: { type: '$render' } },
                  { type: 'label', text: 'Enabled {{$get.enabled}}' },
                ],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    const checkbox = root.querySelector('input[name="enabled"]') as HTMLInputElement;
    checkbox.checked = true;
    checkbox.dispatchEvent(new Event('change', { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();

    expect(renderer.getState().local.enabled).toBe(true);
    expect(root.textContent).toContain('Enabled true');
  });

  it('exposes $network.request response to $render templates as $response', async () => {
    const response = new Response(JSON.stringify({ title: 'Network title' }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{
                items: [{ type: 'label', text: '{{$response.title}}' }],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/data.json' },
      success: { type: '$render' },
    }, renderer.getState());

    expect(root.textContent).toContain('Network title');
  });

  it('keeps component action dispatch scoped to the renderer root', async () => {
    const firstRoot = root;
    const secondRoot = document.createElement('div');
    document.body.appendChild(secondRoot);
    const secondRenderer = new JasonetteRenderer(secondRoot);

    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{
                items: [
                  {
                    type: 'button',
                    text: 'Set message',
                    action: {
                      type: '$set',
                      options: { message: 'Scoped action' },
                      success: { type: '$render' },
                    },
                  },
                  { type: 'label', text: '{{$get.message}}' },
                ],
              }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    secondRenderer.renderDocument(doc);

    firstRoot.querySelector('button')?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await Promise.resolve();
    await Promise.resolve();

    expect(firstRoot.textContent).toContain('Scoped action');
    expect(secondRoot.textContent).not.toContain('Scoped action');
  });

  it('renders the Jasonpedia network fixture from $response', async () => {
    const response = new Response(JSON.stringify([{
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      body: 'Analytical engine notes',
    }]), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc = loadFixture('action/network/eliza.json');
    renderer.renderDocument(doc);

    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/comments.json' },
      success: { type: '$render' },
    }, renderer.getState());

    expect(root.textContent).toContain('Ada Lovelace');
    expect(root.textContent).toContain('ada@example.com');
    expect(root.textContent).toContain('Analytical engine notes');
  });

  it('supports $render options.template for named templates', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Body' }] }] },
            detail: { sections: [{ items: [{ type: 'label', text: 'Detail {{$get.name}}' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$set',
      options: { name: 'Alice' },
      success: { type: '$render', options: { template: 'detail' } },
    }, renderer.getState());

    expect(root.textContent).toContain('Detail Alice');
    expect(root.textContent).not.toContain('Body');
  });
});
