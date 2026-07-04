import type { JasonAction, AppState } from '../types.js';

export type ActionHandler = (
  action: JasonAction,
  state: AppState,
  dispatch: ActionDispatch,
  data?: unknown,
) => Promise<unknown>;

export type ActionDispatch = (action: JasonAction, data?: unknown) => Promise<unknown>;

const handlers: Record<string, ActionHandler> = {};

export function registerAction(type: string, handler: ActionHandler): void {
  handlers[type] = handler;
}

/**
 * Execute an action and chain success/error handlers.
 */
export async function executeAction(
  action: JasonAction,
  state: AppState,
  data?: unknown,
): Promise<unknown> {
  if (!action.type) {
    if (action.trigger && state.actions[action.trigger]) {
      return executeAction(state.actions[action.trigger], state, data);
    }
    return undefined;
  }

  const handler = handlers[action.type];
  if (!handler) {
    console.warn(`[jasonette] Unknown action: ${action.type}`);
    return undefined;
  }

  const dispatch: ActionDispatch = async (next, nextData) => {
    return executeAction(next, state, nextData);
  };

  try {
    const result = await handler(action, state, dispatch, data);

    // Chain success handler
    if (action.success) {
      return executeAction(action.success, state, result);
    }

    return result;
  } catch (err) {
    console.error(`[jasonette] Action error (${action.type}):`, err);

    // Chain error handler
    if (action.error) {
      return executeAction(action.error, state, { error: String(err) });
    }

    return undefined;
  }
}

// --- Built-in Actions ---

registerAction('$render', async (action, state, _dispatch, data) => {
  const renderData = action.options?.data ?? data ?? state.response;
  const template = action.options?.template;
  document.dispatchEvent(new CustomEvent('jasonette:render', {
    detail: { data: renderData, template },
  }));
  return renderData;
});

registerAction('$reload', async (action, state) => {
  document.dispatchEvent(new CustomEvent('jasonette:reload'));
  return undefined;
});

registerAction('$network.request', async (action, state) => {
  const opts = action.options ?? {};
  const url = opts.url;
  if (typeof url !== 'string' || !url) throw new Error('$network.request: missing or invalid url');

  const headers = { ...((opts.headers as Record<string, string> | undefined) ?? {}) };
  const fetchOpts: RequestInit = {
    method: (opts.method as string)?.toUpperCase() ?? 'GET',
    headers,
  };

  if (opts.body && fetchOpts.method !== 'GET') {
    if (typeof opts.body === 'object') {
      fetchOpts.body = JSON.stringify(opts.body);
      headers['Content-Type'] ??= 'application/json';
    } else {
      fetchOpts.body = String(opts.body);
    }
  }

  const response = await fetch(url, fetchOpts);
  const contentType = response.headers.get('content-type') ?? '';

  const result = contentType.includes('json')
    ? await response.json()
    : await response.text();
  state.response = result;
  return result;
});

registerAction('$href', async (action) => {
  const opts = action.options ?? {};
  const url = opts.url;
  if (typeof url !== 'string' || !url) throw new Error('$href: missing or invalid url');
  const parsed = new URL(url, document.baseURI);
  if (parsed.protocol === 'file:' || parsed.protocol === 'javascript:') {
    throw new Error(`$href: blocked url scheme ${parsed.protocol}`);
  }

  document.dispatchEvent(new CustomEvent('jasonette:navigate', {
    detail: { ...opts, url: parsed.href },
  }));
  return opts;
});

registerAction('$back', async () => {
  document.dispatchEvent(new CustomEvent('jasonette:back'));
  return undefined;
});

registerAction('$close', async () => {
  document.dispatchEvent(new CustomEvent('jasonette:close'));
  return undefined;
});

registerAction('$set', async (action, state) => {
  if (action.options && typeof action.options === 'object') {
    Object.assign(state.local, action.options);
  }
  return state.local;
});

registerAction('$get', async (_action, state) => {
  return state.local;
});

registerAction('$cache.set', async (action, state) => {
  if (action.options && typeof action.options === 'object') {
    Object.assign(state.cache, action.options);
    try {
      localStorage.setItem('jasonette:cache', JSON.stringify(state.cache));
    } catch { /* quota exceeded, ignore */ }
  }
  return state.cache;
});

registerAction('$cache.get', async (_action, state) => {
  return state.cache;
});

registerAction('$cache.reset', async (_action, state) => {
  state.cache = {};
  try {
    localStorage.removeItem('jasonette:cache');
  } catch { /* ignore */ }
  return {};
});

registerAction('$flush', async (_action, state) => {
  state.local = {};
  state.cache = {};
  try {
    localStorage.removeItem('jasonette:cache');
  } catch { /* ignore */ }
  return undefined;
});

registerAction('$util.alert', async (action) => {
  const opts = action.options ?? {};
  const title = (opts.title as string) ?? '';
  const description = (opts.description as string) ?? '';
  alert(`${title}\n${description}`.trim());
  return undefined;
});

registerAction('$util.toast', async (action) => {
  const opts = action.options ?? {};
  const text = (opts.text as string) ?? (opts.title as string) ?? '';

  const toast = document.createElement('div');
  toast.className = 'jasonette-toast';
  toast.textContent = text;
  document.body.appendChild(toast);

  setTimeout(() => toast.remove(), 3000);
  return undefined;
});

registerAction('$util.banner', async (action) => {
  const opts = action.options ?? {};
  const title = (opts.title as string) ?? '';
  const description = (opts.description as string) ?? '';

  const banner = document.createElement('div');
  banner.className = 'jasonette-banner';
  const strong = document.createElement('strong');
  strong.textContent = title;
  banner.appendChild(strong);
  banner.append(` ${description}`);
  document.body.prepend(banner);

  setTimeout(() => banner.remove(), 5000);
  return undefined;
});

const timers: Record<string, number> = {};

registerAction('$timer.start', async (action) => {
  const opts = action.options ?? {};
  const interval = Number(opts.interval ?? 1000);
  const name = (opts.name as string) ?? 'default';
  const timerAction = opts.action as JasonAction | undefined;

  if (timers[name]) clearInterval(timers[name]);

  if (timerAction) {
    timers[name] = window.setInterval(() => {
      document.dispatchEvent(new CustomEvent('jasonette:action', {
        detail: timerAction,
      }));
    }, interval);
  }
  return undefined;
});

registerAction('$timer.stop', async (action) => {
  const opts = action.options ?? {};
  const name = (opts.name as string) ?? 'default';
  if (timers[name]) {
    clearInterval(timers[name]);
    delete timers[name];
  }
  return undefined;
});

registerAction('$log', async (action) => {
  console.log('[jasonette:$log]', action.options);
  return undefined;
});

registerAction('$lambda', async (action, state, dispatch) => {
  // $lambda calls a named action from head.actions
  const name = action.options?.name as string;
  if (name && state.actions[name]) {
    return dispatch(state.actions[name]);
  }
  return undefined;
});
