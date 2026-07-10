import { transform } from '@jasonette/template-engine';
import type { RenderContext } from '@jasonette/template-engine';
import type { JasonAction, AppState } from '../types.js';

export type ActionHandler = (
  action: JasonAction,
  state: AppState,
  dispatch: ActionDispatch,
  data?: unknown,
) => Promise<unknown>;

export type ActionDispatch = (action: JasonAction | JasonAction[], data?: unknown) => Promise<unknown>;

const handlers: Record<string, ActionHandler> = {};

export function registerAction(type: string, handler: ActionHandler): void {
  handlers[type] = handler;
}

/**
 * Execute an action and chain success/error handlers.
 */
export async function executeAction(
  action: JasonAction | JasonAction[],
  state: AppState,
  data?: unknown,
): Promise<unknown> {
  if (Array.isArray(action)) {
    let result: unknown = data;
    for (let index = 0; index < action.length; index += 1) {
      const next = action[index];
      const chain = isConditionalStartObject(next) ? collectConditionalChain(action, index) : undefined;
      if (!chain && isConditionalActionObject(next)) continue;

      const rendered = chain
        ? transform(chain, actionContext(state, result))
        : next;
      if (chain) index += chain.length - 1;
      if (rendered === undefined || rendered === null) continue;

      const nextResult = await executeAction(rendered as JasonAction | JasonAction[], state, result);
      if (shouldReplaceArrayPayload(rendered, nextResult)) result = nextResult;
    }
    return result;
  }

  const normalizedAction = normalizeAction(action, state, data);

  if (!normalizedAction.type) {
    if (normalizedAction.trigger && state.actions[normalizedAction.trigger]) {
      return executeAction(state.actions[normalizedAction.trigger], state, normalizedAction.options ?? data);
    }
    return undefined;
  }
  const handler = handlers[normalizedAction.type!];
  if (!handler) {
    console.warn(`[jasonette] Unknown action: ${action.type}`);
    return undefined;
  }

  const dispatch: ActionDispatch = async (next, nextData) => {
    return executeAction(next, state, nextData);
  };

  try {
    const result = await handler(normalizedAction, state, dispatch, data);

    // Chain success handler
    if (normalizedAction.success) {
      return executeAction(normalizedAction.success, state, result);
    }

    return result;
  } catch (err) {
    if (err instanceof AbortAction) return data;
    console.error(`[jasonette] Action error (${normalizedAction.type}):`, err);

    // Chain error handler
    if (normalizedAction.error) {
      return executeAction(normalizedAction.error, state, { error: String(err) });
    }

    return undefined;
  }
}

function isConditionalActionObject(action: JasonAction): boolean {
  const keys = Object.keys(action);
  return keys.length > 0 && keys.every((key) =>
    /^\{\{#(?:if|elseif)\s+.+\}\}$/.test(key) || key === '{{#else}}',
  );
}

function isConditionalStartObject(action: JasonAction): boolean {
  return Object.keys(action).some((key) => /^\{\{#if\s+.+\}\}$/.test(key));
}

function isConditionalContinuationObject(action: JasonAction): boolean {
  const keys = Object.keys(action);
  return keys.length > 0 && keys.every((key) =>
    /^\{\{#elseif\s+.+\}\}$/.test(key) || key === '{{#else}}',
  );
}

function collectConditionalChain(action: JasonAction[], start: number): JasonAction[] {
  const chain: JasonAction[] = [action[start]];
  for (let index = start + 1; index < action.length; index += 1) {
    const next = action[index];
    if (!isConditionalContinuationObject(next)) break;
    chain.push(next);
    if (Object.keys(next).some((key) => key === '{{#else}}')) break;
  }
  return chain;
}

const arraySideEffectActionTypes = new Set([
  '$set', '$cache.set', '$cache.reset', '$flush', '$global.set', '$global.reset', '$session.set', '$session.reset',
  '$render', '$reload', '$href', '$back', '$close',
  '$util.alert', '$util.toast', '$util.banner', '$timer.start', '$timer.stop', '$log',
]);

function shouldReplaceArrayPayload(action: unknown, result: unknown): boolean {
  if (result === undefined) return false;
  if (Array.isArray(action)) return true;
  if (!action || typeof action !== 'object') return true;

  const type = (action as JasonAction).type;
  return !type || !arraySideEffectActionTypes.has(type);
}

function normalizeAction(action: JasonAction, state: AppState, data?: unknown): JasonAction {
  if (action.options === undefined) return action;

  return {
    ...action,
    options: transform(action.options, actionContext(state, data)),
  };
}

function optionsObject(options: unknown): Record<string, unknown> {
  return options && typeof options === 'object' && !Array.isArray(options)
    ? options as Record<string, unknown>
    : {};
}

function actionContext(state: AppState, data?: unknown): RenderContext {
  return {
    $jason: data ?? {},
    $get: state.local,
    $cache: state.cache,
    $global: state.global,
    $params: state.params,
    $response: state.response,
  };
}

class AbortAction extends Error {}

function requireObject(options: unknown): Record<string, unknown> {
  if (!options || typeof options !== 'object' || Array.isArray(options)) throw new AbortAction();
  return options as Record<string, unknown>;
}

function stringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([key, raw]) => [key, String(raw ?? '')]),
  );
}

function persistGlobal(state: AppState): void {
  try { localStorage.setItem('jasonette:global', JSON.stringify(state.global)); } catch { /* ignore */ }
}

function persistSessions(state: AppState): void {
  try { localStorage.setItem('jasonette:session', JSON.stringify(state.sessions)); } catch { /* ignore */ }
}

function sessionDomain(options: Record<string, unknown>): string | undefined {
  const raw = typeof options.domain === 'string'
    ? options.domain
    : (typeof options.url === 'string' ? options.url : undefined);
  if (!raw) return undefined;
  try {
    return new URL(raw.includes('://') ? raw : `https://${raw}`).hostname.toLowerCase();
  } catch {
    return undefined;
  }
}

function requestSession(state: AppState, url: URL): Record<string, unknown> {
  return state.sessions?.[url.hostname.toLowerCase()] ?? {};
}

function formEncode(data: Record<string, string>): string {
  return new URLSearchParams(data).toString();
}

// --- Built-in Actions ---

registerAction('$render', async (action, state, _dispatch, data) => {
  const opts = optionsObject(action.options);
  const renderData = opts.data ?? data ?? state.response;
  const template = opts.template;
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
  const opts = optionsObject(action.options);
  const rawUrl = opts.url;
  if (typeof rawUrl !== 'string' || !rawUrl) throw new Error('$network.request: missing or invalid url');

  const parsed = new URL(rawUrl, state.url ?? document.baseURI);
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error(`$network.request: blocked url scheme ${parsed.protocol}`);
  }
  const method = (opts.method as string)?.toUpperCase() ?? 'GET';
  const session = requestSession(state, parsed);
  const sessionHeaders = stringMap(session.header);
  const authoredHeaders = stringMap(opts.header ?? opts.headers);
  const headers = { ...authoredHeaders, ...sessionHeaders };
  const fetchOpts: RequestInit = { method, headers };

  const hasAuthoredBody = Object.prototype.hasOwnProperty.call(opts, 'body');
  const data = opts.data !== undefined ? stringMap(opts.data) : (hasAuthoredBody ? {} : stringMap(session.body));
  if (['GET', 'HEAD', 'DELETE'].includes(method)) {
    for (const [key, value] of Object.entries(data)) parsed.searchParams.append(key, value);
  }

  if (hasAuthoredBody && !['GET', 'HEAD', 'DELETE'].includes(method)) {
    if (opts.body !== null && typeof opts.body === 'object') {
      fetchOpts.body = JSON.stringify(opts.body);
      headers['Content-Type'] ??= 'application/json';
    } else {
      fetchOpts.body = String(opts.body ?? '');
    }
  } else if (!['GET', 'HEAD', 'DELETE'].includes(method) && Object.keys(data).length > 0) {
    fetchOpts.body = formEncode(data);
    headers['Content-Type'] ??= 'application/x-www-form-urlencoded';
  }

  const response = await fetch(parsed.href, fetchOpts);
  if (!response.ok) throw new Error(`$network.request: HTTP ${response.status}`);
  const contentType = response.headers.get('content-type') ?? '';

  const result = contentType.includes('json')
    ? await response.json()
    : await response.text();
  state.response = result;
  return result;
});

registerAction('$href', async (action, state) => {
  const opts = optionsObject(action.options);
  const url = opts.url;
  if (typeof url !== 'string' || !url) throw new Error('$href: missing or invalid url');
  const parsed = new URL(url, state.url ?? document.baseURI);
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
  const opts = optionsObject(action.options);
  if (Object.keys(opts).length > 0) {
    Object.assign(state.local, opts);
  }
  return state.local;
});

registerAction('$global.set', async (action, state) => {
  const opts = requireObject(action.options);
  Object.assign(state.global, opts);
  persistGlobal(state);
  state.local.$jason = state.global;
  return state.global;
});

registerAction('$global.reset', async (action, state) => {
  const opts = requireObject(action.options);
  if (opts.items !== undefined && !Array.isArray(opts.items)) throw new AbortAction();
  for (const item of (opts.items as unknown[] | undefined) ?? []) {
    if (typeof item === 'string') delete state.global[item];
  }
  persistGlobal(state);
  state.local.$jason = state.global;
  return state.global;
});

registerAction('$session.set', async (action, state) => {
  const opts = requireObject(action.options);
  const domain = sessionDomain(opts);
  if (!domain) throw new AbortAction();
  state.sessions[domain] = { ...opts };
  persistSessions(state);
  state.local.$jason = {};
  return {};
});

registerAction('$session.reset', async (action, state) => {
  const opts = requireObject(action.options);
  const domain = sessionDomain(opts);
  if (!domain) throw new AbortAction();
  delete state.sessions[domain];
  persistSessions(state);
  state.local.$jason = {};
  return {};
});

registerAction('$get', async (_action, state) => {
  return state.local;
});

registerAction('$cache.set', async (action, state) => {
  const opts = optionsObject(action.options);
  if (Object.keys(opts).length > 0) {
    Object.assign(state.cache, opts);
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
  const opts = optionsObject(action.options);
  const title = (opts.title as string) ?? '';
  const description = (opts.description as string) ?? '';
  alert(`${title}\n${description}`.trim());
  return undefined;
});

registerAction('$util.toast', async (action) => {
  const opts = optionsObject(action.options);
  const text = (opts.text as string) ?? (opts.title as string) ?? '';

  const toast = document.createElement('div');
  toast.className = 'jasonette-toast';
  toast.textContent = text;
  document.body.appendChild(toast);

  setTimeout(() => toast.remove(), 3000);
  return undefined;
});

registerAction('$util.banner', async (action) => {
  const opts = optionsObject(action.options);
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
  const opts = optionsObject(action.options);
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
  const opts = optionsObject(action.options);
  const name = (opts.name as string) ?? 'default';
  if (timers[name]) {
    clearInterval(timers[name]);
    delete timers[name];
  }
  return undefined;
});

registerAction('$log', async (action) => {
  console.log('[jasonette:$log]', optionsObject(action.options));
  return undefined;
});

registerAction('$lambda', async (action, state, dispatch, data) => {
  // $lambda calls a named action from head.actions and passes options.options as payload.
  const opts = optionsObject(action.options);
  const name = opts.name as string;
  if (name && state.actions[name]) {
    return dispatch(state.actions[name], opts.options ?? data);
  }
  return undefined;
});
