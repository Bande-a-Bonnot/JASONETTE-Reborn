import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { JasonetteRenderer } from '../src/renderer.js';
import { executeAction } from '../src/actions/index.js';
import type { AppState, JasonDocument } from '../src/types.js';

function loadFixture(relativePath: string): JasonDocument {
  const fullPath = resolve(import.meta.dirname, '../../../Jasonpedia', relativePath);
  return JSON.parse(readFileSync(fullPath, 'utf-8'));
}

describe('web action/render parity', () => {
  let root: HTMLElement;
  let renderer: JasonetteRenderer;

  beforeEach(() => {
    const storage = new Map<string, string>();
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => { storage.set(key, value); },
      removeItem: (key: string) => { storage.delete(key); },
      clear: () => { storage.clear(); },
    });
    root = document.createElement('div');
    document.body.appendChild(root);
    renderer = new JasonetteRenderer(root);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
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

  it('passes trigger options as $jason payload to named actions', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'Touched', description: '{{$jason.id}}' },
            },
          },
          templates: {
            body: {
              sections: [{
                items: [{
                  type: 'button',
                  text: 'Touch',
                  action: { trigger: 'banner', options: { id: 'top' } },
                }],
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

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Touched top');
  });

  it('exposes $global to action and render contexts', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: {
              sections: [{ items: [{ type: 'label', text: '{{$global.profile.name}} {{$get.saved}}' }] }],
            },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$global.set',
      options: { token: 'abc', profile: { name: 'Ada' } },
      success: [
        { type: '$set', options: { saved: '{{$global.profile.name}}' } },
        { type: '$render' },
      ],
    }, renderer.getState());

    expect(renderer.getState().global.token).toBe('abc');
    expect(renderer.getState().local.$jason).toEqual(renderer.getState().global);
    expect(root.textContent).toContain('Ada Ada');

    const second = new JasonetteRenderer(document.createElement('div'));
    expect(second.getState().global.token).toBe('abc');
  });

  it('resets only listed $global items and aborts malformed global actions', async () => {
    await executeAction({ type: '$global.set', options: { token: 'abc', theme: 'dark' } }, renderer.getState());
    await executeAction({
      type: '$global.reset',
      options: { items: ['token'] },
      success: { type: '$set', options: { remaining: '{{$jason.theme}}' } },
    }, renderer.getState());
    await executeAction({
      type: '$global.set',
      options: ['bad'],
      success: { type: '$set', options: { malformed_success: true } },
      error: { type: '$set', options: { malformed_error: true } },
    }, renderer.getState());

    expect(renderer.getState().global.token).toBeUndefined();
    expect(renderer.getState().global.theme).toBe('dark');
    expect(renderer.getState().local.remaining).toBe('dark');
    expect(renderer.getState().local.malformed_success).toBeUndefined();
    expect(renderer.getState().local.malformed_error).toBeUndefined();
  });

  it('decorates network requests with session headers and query data', async () => {
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ ok: true }), {
      headers: { 'content-type': 'application/json' },
    }));
    vi.stubGlobal('fetch', fetchMock);

    await executeAction({
      type: '$session.set',
      options: {
        domain: 'api.example.com',
        header: { Authorization: 'Bearer session', 'X-Session': 'yes' },
        body: { api_key: 'secret' },
      },
    }, renderer.getState());
    await executeAction({
      type: '$network.request',
      options: {
        url: 'https://api.example.com/items?existing=1',
        headers: { Authorization: 'Bearer authored' },
      },
    }, renderer.getState());

    expect(fetchMock).toHaveBeenCalledWith('https://api.example.com/items?existing=1&api_key=secret', expect.objectContaining({
      headers: expect.objectContaining({ Authorization: 'Bearer session', 'X-Session': 'yes' }),
    }));
    expect(renderer.getState().response).toEqual({ ok: true });
  });

  it('uses authored network data instead of session body for form requests and reset clears session', async () => {
    const fetchMock = vi.fn(async () => new Response('{}', { headers: { 'content-type': 'application/json' } }));
    vi.stubGlobal('fetch', fetchMock);

    await executeAction({
      type: '$session.set',
      options: {
        url: 'https://api.example.com/login',
        header: { 'X-Session': 'yes' },
        body: { api_key: 'secret', locale: 'en' },
      },
    }, renderer.getState());
    await executeAction({
      type: '$network.request',
      options: {
        url: 'https://api.example.com/items',
        method: 'POST',
        header: { 'X-Session': 'authored' },
        data: { locale: 'fr', page: '1' },
      },
    }, renderer.getState());
    await executeAction({ type: '$session.reset', options: { domain: 'api.example.com' } }, renderer.getState());
    await executeAction({ type: '$network.request', options: { url: 'https://api.example.com/items' } }, renderer.getState());

    expect(fetchMock).toHaveBeenNthCalledWith(1, 'https://api.example.com/items', expect.objectContaining({
      method: 'POST',
      body: 'locale=fr&page=1',
      headers: expect.objectContaining({ 'X-Session': 'yes' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(2, 'https://api.example.com/items', expect.objectContaining({
      headers: {},
    }));
  });

  it('does not apply session body data when an explicit network body is authored', async () => {
    const fetchMock = vi.fn(async () => new Response('{}', { headers: { 'content-type': 'application/json' } }));
    vi.stubGlobal('fetch', fetchMock);

    await executeAction({
      type: '$session.set',
      options: {
        domain: 'api.example.com',
        body: { api_key: 'secret' },
      },
    }, renderer.getState());
    await executeAction({
      type: '$network.request',
      options: { url: 'https://api.example.com/items', method: 'POST', body: '' },
    }, renderer.getState());
    await executeAction({
      type: '$network.request',
      options: { url: 'https://api.example.com/delete', method: 'DELETE', body: 'ignored-by-fetch' },
    }, renderer.getState());

    expect(fetchMock).toHaveBeenNthCalledWith(1, 'https://api.example.com/items', expect.objectContaining({
      body: '',
    }));
    expect(fetchMock.mock.calls[1]?.[0]).toBe('https://api.example.com/delete');
    expect(fetchMock.mock.calls[1]?.[1]).not.toHaveProperty('body');
  });

  it('handles handcrafted action state without initialized session storage', async () => {
    const fetchMock = vi.fn(async () => new Response('{}', { headers: { 'content-type': 'application/json' } }));
    vi.stubGlobal('fetch', fetchMock);
    const state = renderer.getState();
    delete (state as Partial<typeof state>).sessions;

    await executeAction({ type: '$network.request', options: { url: 'https://api.example.com/items' } }, state);

    expect(fetchMock).toHaveBeenCalledWith('https://api.example.com/items', expect.objectContaining({ headers: {} }));
  });

  it('keeps network responses as the sequential array payload', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ title: 'from network' }), {
      headers: { 'content-type': 'application/json' },
    })));

    await executeAction([
      { type: '$network.request', options: { url: 'https://api.example.com/items' } },
      { type: '$set', options: { title: '{{$jason.title}}' } },
    ], renderer.getState(), { title: 'stale' });

    expect(renderer.getState().local.title).toBe('from network');
  });

  it('passes $lambda options as $jason payload to named actions', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: '{{$jason.title}}', description: '{{$jason.description}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Lambda' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$lambda',
      options: { name: 'banner', options: { title: 'Trigger', description: 'it worked!' } },
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Trigger it worked!');
  });

  it('templates trigger options against network response payloads before named actions run', async () => {
    const response = new Response(JSON.stringify({ cats: [{ status: 'sleepy' }] }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: '{{$jason.title}}', description: '{{$jason.description}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Network trigger options' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/cat.json' },
      success: {
        trigger: 'banner',
        options: { title: 'Cat', description: '{{$jason.cats[0].status}}' },
      },
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Cat sleepy');
  });

  it('supports whole-expression action options that render to objects', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: '{{$jason}}',
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'String options' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({ trigger: 'banner', options: { title: 'Banner2', description: 'rendered object' } }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Banner2 rendered object');
  });

  it('templates named success triggers against network response payloads', async () => {
    const response = new Response(JSON.stringify({ cats: [{ status: 'playful' }] }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'Cat', description: '{{$jason.cats[0].status}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Network' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/cat.json' },
      success: { trigger: 'banner' },
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Cat playful');
  });

  it('executes legacy success arrays in order', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: '{{$get.first}} {{$get.second}}' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$set',
      options: { first: 'one' },
      success: [
        { type: '$set', options: { second: 'two' } },
        { type: '$render' },
      ],
    }, renderer.getState());

    expect(root.textContent).toContain('one two');
  });

  it('renders conditional action arrays against the incoming payload before execution', async () => {
    const response = new Response(JSON.stringify({ cats: [{ status: 'alert' }] }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'Conditional', description: '{{$jason.cats[0].status}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Conditional array' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/cat.json' },
      success: [
        { "{{#if $jason && 'cats' in $jason}}": { trigger: 'banner' } },
        { '{{#else}}': { type: '$util.toast', options: { text: 'Error' } } },
      ],
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Conditional alert');
    expect(document.body.querySelector('.jasonette-toast')).toBeNull();
  });

  it('continues mixed conditional action arrays after consuming the matching branch', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: '{{$get.branch}} {{$get.after}}' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction([
      { "{{#if $jason.ok}}": { type: '$set', options: { branch: 'true' } } },
      { '{{#else}}': { type: '$set', options: { branch: 'false' } } },
      { type: '$set', options: { after: 'after' } },
      { type: '$render' },
    ], renderer.getState(), { ok: true });

    expect(root.textContent).toContain('true after');
    expect(root.textContent).not.toContain('false after');
  });

  it('executes adjacent independent conditional actions separately', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: '{{$get.first}} {{$get.second}}' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction([
      { '{{#if $jason.first}}': { type: '$set', options: { first: 'one' } } },
      { '{{#if $jason.second}}': { type: '$set', options: { second: 'two' } } },
      { type: '$render' },
    ], renderer.getState(), { first: true, second: true });

    expect(root.textContent).toContain('one two');
  });

  it('supports conditional branches that return nested action arrays', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'Nested', description: '{{$jason.status}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: '{{$get.branch}}' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction([
      {
        '{{#if $jason.ok}}': [
          { type: '$set', options: { branch: 'nested' } },
          { trigger: 'banner' },
        ],
      },
      { type: '$render' },
    ], renderer.getState(), { ok: true, status: 'payload' });

    expect(root.textContent).toContain('nested');
    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Nested payload');
  });

  it('continues after a false conditional branch without an else', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: '{{$get.after}}' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction([
      { '{{#if $jason.ok}}': { type: '$set', options: { after: 'wrong' } } },
      { type: '$set', options: { after: 'after' } },
      { type: '$render' },
    ], renderer.getState(), { ok: false });

    expect(root.textContent).toContain('after');
    expect(root.textContent).not.toContain('wrong');
  });

  it('preserves payload across side-effect-only actions in sequential arrays', async () => {
    const response = new Response(JSON.stringify({ cats: [{ status: 'sleeping' }] }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'After toast', description: '{{$jason.cats[0].status}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Side effect chain' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/cat.json' },
      success: [
        { type: '$util.toast', options: { text: 'Saw {{$jason.cats[0].status}}' } },
        { trigger: 'banner' },
      ],
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-toast')?.textContent).toContain('Saw sleeping');
    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('After toast sleeping');
  });

  it('preserves payload across state-mutating actions in sequential arrays', async () => {
    const response = new Response(JSON.stringify({ cats: [{ status: 'purring' }] }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'After set', description: '{{$jason.cats[0].status}} {{$get.seen}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'State chain' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/cat.json' },
      success: [
        { type: '$set', options: { seen: 'yes' } },
        { trigger: 'banner' },
      ],
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('After set purring yes');
  });

  it('passes the incoming payload through $lambda when options.options is absent', async () => {
    const response = new Response(JSON.stringify({ cats: [{ status: 'curious' }] }), {
      headers: { 'content-type': 'application/json' },
    });
    vi.stubGlobal('fetch', vi.fn(async () => response));

    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            banner: {
              type: '$util.banner',
              options: { title: 'Lambda payload', description: '{{$jason.cats[0].status}}' },
            },
          },
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: 'Lambda inherited payload' }] }] },
          },
        },
      },
    };

    renderer.renderDocument(doc);
    await executeAction({
      type: '$network.request',
      options: { url: 'https://example.com/cat.json' },
      success: { type: '$lambda', options: { name: 'banner' } },
    }, renderer.getState());

    expect(document.body.querySelector('.jasonette-banner')?.textContent).toContain('Lambda payload curious');
  });

  it('executes legacy error arrays with the error payload as $jason', async () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          templates: {
            body: { sections: [{ items: [{ type: 'label', text: '{{$get.errorMessage}}' }] }] },
          },
        },
      },
    };

    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => undefined);

    renderer.renderDocument(doc);
    await executeAction({
      type: '$href',
      options: { url: 'javascript:alert(1)' },
      error: [
        { type: '$set', options: { errorMessage: 'Blocked {{$jason.error}}' } },
        { type: '$render' },
      ],
    }, renderer.getState());

    expect(errorSpy).toHaveBeenCalledOnce();
    expect(root.textContent).toContain('Blocked Error: $href: blocked url scheme javascript:');
  });

  it('resolves relative $href URLs against the current document URL', async () => {
    const state: AppState = {
      url: 'https://example.com/app/screens/index.json',
      document: null,
      styles: {},
      actions: {},
      local: {},
      cache: {},
      params: {},
      response: undefined,
      history: [],
    };
    let detail: { url?: string } | undefined;
    document.addEventListener('jasonette:navigate', ((event: CustomEvent) => {
      event.stopImmediatePropagation();
      detail = event.detail;
    }) as EventListener, { capture: true, once: true });

    await executeAction({
      type: '$href',
      options: { url: '../detail.json' },
    }, state);

    expect(detail?.url).toBe('https://example.com/app/detail.json');
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
