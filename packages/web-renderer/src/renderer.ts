import { renderSync } from '@jasonette/template-engine';
import type { RenderContext } from '@jasonette/template-engine';
import type {
  JasonDocument, JasonBody, JasonSection,
  JasonComponent, JasonStyle, AppState,
} from './types.js';
import { renderItem } from './layouts/index.js';
import { applyStyle, generateStyleSheet } from './style.js';
import { executeAction } from './actions/index.js';

function controlValue(target: HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement): unknown {
  if (target instanceof HTMLInputElement && target.type === 'checkbox') {
    return target.checked;
  }
  return target.value;
}

function cloneParams(params: Record<string, unknown>): Record<string, unknown> {
  return { ...params };
}

function paramsFromNavigationOptions(options?: Record<string, unknown>): Record<string, unknown> {
  const params = options?.options;
  return params && typeof params === 'object' && !Array.isArray(params)
    ? cloneParams(params as Record<string, unknown>)
    : {};
}

function resolveNavigationUrl(url: string, baseUrl: string | null): string {
  const parsed = new URL(url, baseUrl ?? document.baseURI);
  if (parsed.protocol === 'file:' || parsed.protocol === 'javascript:') {
    throw new Error(`navigation: blocked url scheme ${parsed.protocol}`);
  }
  return parsed.href;
}

function cloneJson<T>(value: T): T {
  if (value === undefined) return value;
  return JSON.parse(JSON.stringify(value)) as T;
}

function resolveDocumentPath(root: unknown, ref: string): unknown {
  if (!ref.startsWith('$document')) return undefined;
  const path = ref === '$document' ? [] : ref.slice('$document.'.length).split('.');
  let current: unknown = root;
  for (const part of path) {
    if (!part) continue;
    if (current && typeof current === 'object' && !Array.isArray(current)) {
      current = (current as Record<string, unknown>)[part];
    } else {
      return undefined;
    }
  }
  return current;
}

function selectorInclude(ref: string): { selector?: string; url: string } {
  const at = ref.indexOf('@');
  if (at > 0) {
    return { selector: ref.slice(0, at), url: ref.slice(at + 1) };
  }
  return { url: ref };
}

function includeUrl(ref: string, baseUrl: string): string | undefined {
  const resolved = new URL(ref, baseUrl);
  if (resolved.protocol !== 'http:' && resolved.protocol !== 'https:') {
    return undefined;
  }
  return resolved.href;
}

/**
 * Jasonette Web Renderer.
 * Fetches a $jason document, applies templates, and renders to DOM.
 */
export class JasonetteRenderer {
  private root: HTMLElement;
  private state: AppState;

  constructor(root: HTMLElement) {
    this.root = root;
    this.root.classList.add('jasonette');
    this.state = {
      url: null,
      document: null,
      styles: {},
      actions: {},
      local: {},
      cache: this.loadCache(),
      global: this.loadGlobal(),
      sessions: this.loadSessions(),
      params: {},
      response: undefined,
      history: [],
    };

    this.setupEventListeners();
  }

  private loadCache(): Record<string, unknown> {
    return this.loadObject('jasonette:cache');
  }

  private loadGlobal(): Record<string, unknown> {
    return this.loadObject('jasonette:global');
  }

  private loadSessions(): Record<string, Record<string, unknown>> {
    const sessions = this.loadObject('jasonette:session');
    return Object.fromEntries(
      Object.entries(sessions).filter((entry): entry is [string, Record<string, unknown>] => (
        !!entry[1] && typeof entry[1] === 'object' && !Array.isArray(entry[1])
      )).map(([domain, session]) => [domain.toLowerCase(), session]),
    );
  }

  private loadObject(key: string): Record<string, unknown> {
    try {
      const cached = localStorage.getItem(key);
      const parsed = cached ? JSON.parse(cached) : {};
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as Record<string, unknown> : {};
    } catch {
      return {};
    }
  }

  private setupEventListeners(): void {
    // Navigation events from components inside this renderer root.
    this.root.addEventListener('jasonette:navigate', ((e: CustomEvent) => {
      e.stopPropagation();
      const href = e.detail;
      if (href.url) {
        this.navigate(href.url, href).catch((err) =>
          console.error('[jasonette] navigation error:', err),
        );
      }
    }) as EventListener);

    // Navigation events emitted by actions such as $href.
    document.addEventListener('jasonette:navigate', ((e: CustomEvent) => {
      const href = e.detail;
      if (href.url) {
        this.navigate(href.url, href).catch((err) =>
          console.error('[jasonette] navigation error:', err),
        );
      }
    }) as EventListener);

    // Render events from actions
    document.addEventListener('jasonette:render', ((e: CustomEvent) => {
      if (this.state.document) {
        const data = e.detail?.data;
        const template = e.detail?.template;
        this.renderBody(this.state.document, data, typeof template === 'string' ? template : undefined);
      }
    }) as EventListener);

    // Reload events
    document.addEventListener('jasonette:reload', () => {
      if (this.state.url) {
        this.load(this.state.url, { params: this.state.params }).catch((err) =>
          console.error('[jasonette] reload error:', err),
        );
      }
    });

    document.addEventListener('jasonette:back', () => this.back());

    document.addEventListener('jasonette:close', () => {
      const dialog = this.root.closest('dialog') as HTMLDialogElement | null;
      if (dialog) dialog.close();
    });

    // Control components update local state ($get) as their DOM values change.
    this.root.addEventListener('input', (e) => this.handleControlValueEvent(e));
    this.root.addEventListener('change', (e) => this.handleControlValueEvent(e));

    // Action events from components inside this renderer root.
    this.root.addEventListener('jasonette:action', ((e: CustomEvent) => {
      e.stopPropagation();
      executeAction(e.detail, this.state);
    }) as EventListener);

    // Global action events (from timers, etc.)
    document.addEventListener('jasonette:action', ((e: CustomEvent) => {
      executeAction(e.detail, this.state);
    }) as EventListener);

    // Browser back button
    window.addEventListener('popstate', (e) => {
      if (e.state?.jasonetteUrl) {
        this.load(e.state.jasonetteUrl, {
          pushHistory: false,
          params: cloneParams(e.state.jasonetteParams ?? {}),
        });
      }
    });

    // $show — fires each time the document becomes visible
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        this.triggerLifecycle('$show');
        this.triggerLifecycle('$foreground');
      }
    });
  }

  private triggerLifecycle(name: string): void {
    const action = this.state.actions[name];
    if (action) {
      executeAction(action, this.state).catch((err) =>
        console.error(`[jasonette] ${name} error:`, err),
      );
    }
  }

  private handleControlValueEvent(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement)) {
      return;
    }
    if (!target.name) return;

    this.state.local[target.name] = controlValue(target);

    const actionEl = target.closest('[data-action], [data-trigger]');
    if (!(actionEl instanceof HTMLElement)) return;

    const actionJson = actionEl.getAttribute('data-action');
    const trigger = actionEl.getAttribute('data-trigger');
    const action = actionJson ? JSON.parse(actionJson) : (trigger ? { trigger } : undefined);
    if (action) {
      executeAction(action, this.state).catch((err) =>
        console.error('[jasonette] control action error:', err),
      );
    }
  }

  /**
   * Load and render a $jason document from a URL.
   */
  async load(url: string, options?: { pushHistory?: boolean; params?: Record<string, unknown> }): Promise<void> {
    this.state.url = url;
    this.state.params = cloneParams(options?.params ?? {});

    try {
      const response = await fetch(url);
      const loadedUrl = response.url || url;
      const rawDoc = await response.json() as JasonDocument;
      const doc = await this.resolveLegacyIncludes(rawDoc, rawDoc, loadedUrl) as JasonDocument;
      this.state.url = loadedUrl;
      this.state.document = doc;

      if (options?.pushHistory !== false) {
        history.pushState({ jasonetteUrl: loadedUrl, jasonetteParams: cloneParams(this.state.params) }, '', `#${loadedUrl}`);
      }

      this.renderDocument(doc);

      // Trigger $load action
      const loadAction = doc.$jason?.head?.actions?.['$load'];
      if (loadAction) {
        await executeAction(loadAction, this.state);
      }

      // Trigger $show on first render
      this.triggerLifecycle('$show');
    } catch (err) {
      console.error('[jasonette] Failed to load:', url, err);
      this.root.textContent = `Failed to load: ${url}`;
    }
  }

  private async fetchInclude(ref: string, baseUrl: string): Promise<{ value: unknown; url: string; key: string } | undefined> {
    const { selector, url } = selectorInclude(ref);
    const resolvedUrl = includeUrl(url, baseUrl);
    if (!resolvedUrl) return undefined;

    const response = await fetch(resolvedUrl);
    const finalUrl = response.url || resolvedUrl;
    const fetched = await response.json() as unknown;
    const key = `${selector ?? ''}@${finalUrl}`;
    if (!selector) return { value: fetched, url: finalUrl, key };

    if (fetched && typeof fetched === 'object' && !Array.isArray(fetched)) {
      return { value: (fetched as Record<string, unknown>)[selector], url: finalUrl, key };
    }
    return { value: undefined, url: finalUrl, key };
  }

  private async resolveLegacyIncludes(
    value: unknown,
    root: unknown,
    baseUrl: string,
    includeDepth = 0,
    includeStack = new Set<string>(),
  ): Promise<unknown> {
    if (Array.isArray(value)) {
      const resolved = [];
      for (const item of value) {
        resolved.push(await this.resolveLegacyIncludes(item, root, baseUrl, includeDepth, new Set(includeStack)));
      }
      return resolved;
    }

    if (!value || typeof value !== 'object') return value;

    const object = value as Record<string, unknown>;
    if (typeof object['+'] === 'string') {
      const includeRef = object['+'];
      const { '+': _, ...rest } = object;

      let included: unknown;
      let includeBaseUrl = baseUrl;
      if (includeRef.startsWith('$document')) {
        included = resolveDocumentPath(root, includeRef);
      } else if (includeDepth < 8) {
        const fetched = await this.fetchInclude(includeRef, baseUrl);
        if (fetched && !includeStack.has(fetched.key)) {
          includeStack.add(fetched.key);
          included = fetched.value;
          includeBaseUrl = fetched.url;
        }
      }

      const merged = included && typeof included === 'object' && !Array.isArray(included)
        ? { ...(cloneJson(included) as Record<string, unknown>), ...rest }
        : (Object.keys(rest).length > 0 ? { value: cloneJson(included), ...rest } : cloneJson(included));
      const nextRoot = value === root ? merged : root;
      const nextDepth = includeRef.startsWith('$document') ? includeDepth : includeDepth + 1;
      return this.resolveLegacyIncludes(merged, nextRoot, includeBaseUrl, nextDepth, includeStack);
    }

    const result: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(object)) {
      result[key] = await this.resolveLegacyIncludes(child, root, baseUrl, includeDepth, new Set(includeStack));
    }
    return result;
  }

  /**
   * Render a $jason document directly (no fetch).
   */
  private renderContext(data?: unknown): RenderContext {
    return {
      $jason: data ?? this.state.document?.$jason?.head?.data ?? {},
      $get: this.state.local,
      $cache: this.state.cache,
      $global: this.state.global,
      $params: this.state.params,
      $response: this.state.response,
    };
  }

  renderDocument(doc: JasonDocument): void {
    this.state.document = doc;
    const head = doc.$jason?.head;

    // Store head-level styles and actions
    this.state.styles = head?.styles ?? {};
    this.state.actions = head?.actions ?? {};

    // Reset local state for new document
    this.state.local = {};

    // Clear root
    this.root.innerHTML = '';

    // Generate stylesheet from head.styles
    if (Object.keys(this.state.styles).length > 0) {
      this.root.appendChild(generateStyleSheet(this.state.styles));
    }

    // Apply template if present
    let body: JasonBody | undefined;
    if (head?.templates?.body) {
      body = renderSync(head.templates.body, this.renderContext(head.data)) as JasonBody;
    } else {
      body = doc.$jason?.body;
    }

    if (body) {
      this.renderBodyToDOM(body);
    }
  }

  /**
   * Re-render body with new data (for $render action).
   */
  private renderBody(doc: JasonDocument, data?: unknown, templateName = 'body'): void {
    const head = doc.$jason?.head;

    // Remove everything except the stylesheet
    const styleEl = this.root.querySelector('style[data-jasonette]');
    this.root.innerHTML = '';
    if (styleEl) this.root.appendChild(styleEl);

    let body: JasonBody | undefined;
    const template = head?.templates?.[templateName] ?? head?.templates?.body;
    if (template) {
      body = renderSync(template, this.renderContext(data ?? head?.data)) as JasonBody;
    } else {
      body = doc.$jason?.body;
    }

    if (body) {
      this.renderBodyToDOM(body);
    }
  }

  private renderBodyToDOM(body: JasonBody): void {
    this.renderBodyBackground(body);

    // Header
    if (body.header) {
      const header = this.renderHeader(body.header as unknown as Record<string, unknown>);
      this.root.appendChild(header);
    }

    // Sections
    if (body.sections && Array.isArray(body.sections)) {
      const sectionsEl = document.createElement('div');
      sectionsEl.className = 'jasonette-sections';
      sectionsEl.style.flex = '1';
      sectionsEl.style.overflowY = 'auto';

      for (const section of body.sections) {
        sectionsEl.appendChild(this.renderSection(section));
      }
      this.root.appendChild(sectionsEl);

      // Pull-to-refresh ($pull)
      if (this.state.actions['$pull']) {
        this.setupPullToRefresh(sectionsEl);
      }
    }

    // Layers
    if (body.layers && Array.isArray(body.layers)) {
      const layersEl = document.createElement('div');
      layersEl.className = 'jasonette-layers';
      layersEl.style.position = 'relative';

      for (const layer of body.layers) {
        const el = renderItem(layer, this.state.styles);
        el.style.position = 'absolute';
        layersEl.appendChild(el);
      }
      this.root.appendChild(layersEl);
    }

    // Footer
    if (body.footer) {
      const footer = this.renderFooter(body.footer as unknown as Record<string, unknown>);
      this.root.appendChild(footer);
    }
  }

  private renderBodyBackground(body: JasonBody): void {
    this.root.style.backgroundImage = '';
    this.root.style.backgroundSize = '';
    this.root.style.backgroundColor = '';

    const styleBackground = (body as JasonBody & { style?: JasonStyle }).style?.background;
    const background = body.background ?? styleBackground;

    if (typeof background === 'string') {
      if (/^https?:\/\//.test(background)) {
        this.root.style.backgroundImage = `url(${background})`;
        this.root.style.backgroundSize = 'cover';
      } else if (background) {
        this.root.style.backgroundColor = background;
      }
      return;
    }

    if (background && typeof background === 'object') {
      const webBackground = background as { type?: unknown; text?: unknown; url?: unknown };
      if (webBackground.type === 'html' && (typeof webBackground.text === 'string' || typeof webBackground.url === 'string')) {
        const iframe = document.createElement('iframe');
        iframe.className = 'jasonette-background-web';
        iframe.setAttribute('aria-hidden', 'true');
        if (typeof webBackground.text === 'string') {
          iframe.srcdoc = webBackground.text;
        } else if (typeof webBackground.url === 'string') {
          iframe.src = webBackground.url;
        }
        this.root.appendChild(iframe);
      }
    }
  }

  private renderHeader(header: Record<string, unknown>): HTMLElement {
    const el = document.createElement('header');
    el.className = 'jasonette-header';

    if (header.title) {
      const title = document.createElement('h1');
      title.className = 'jasonette-header-title';
      title.textContent = String(header.title);
      el.appendChild(title);
    }

    if (header.menu && typeof header.menu === 'object') {
      const menu = header.menu as Record<string, unknown>;
      const menuEl = document.createElement('button');
      menuEl.className = 'jasonette-header-menu';
      menuEl.textContent = (menu.text as string) ?? '...';

      if (menu.href) {
        menuEl.addEventListener('click', () => {
          const href = menu.href as Record<string, unknown>;
          if ((href.view as string) === 'web' && (href.url as string)?.startsWith('http')) {
            window.open(href.url as string, '_blank', 'noopener,noreferrer');
          } else if (href.url) {
            this.navigate(href.url as string, href).catch((err) =>
              console.error('[jasonette] navigation error:', err),
            );
          }
        });
      }

      el.appendChild(menuEl);
    }

    applyStyle(el, header.style as JasonStyle);
    return el;
  }

  private renderSection(section: JasonSection): HTMLElement {
    const el = document.createElement('section');
    el.className = 'jasonette-section';

    // Section header
    if (section.header) {
      const headerEl = document.createElement('div');
      headerEl.className = 'jasonette-section-header';
      const rendered = renderItem(section.header, this.state.styles);
      headerEl.appendChild(rendered);
      el.appendChild(headerEl);
    }

    // Section items
    if (section.items) {
      const items = Array.isArray(section.items) ? section.items : [];
      const itemsEl = document.createElement('div');
      itemsEl.className = 'jasonette-section-items';

      for (const item of items) {
        const itemEl = renderItem(item as JasonComponent, this.state.styles);
        itemsEl.appendChild(itemEl);
      }
      el.appendChild(itemsEl);
    }

    applyStyle(el, section.style);
    return el;
  }

  private renderFooter(footer: Record<string, unknown>): HTMLElement {
    const el = document.createElement('footer');
    el.className = 'jasonette-footer';

    if (footer.tabs && typeof footer.tabs === 'object') {
      const tabs = footer.tabs as { items?: JasonComponent[]; style?: JasonStyle };
      if (tabs.items) {
        const tabsEl = document.createElement('nav');
        tabsEl.className = 'jasonette-tabs';
        for (const tab of tabs.items) {
          const tabEl = renderItem(tab, this.state.styles);
          tabEl.classList.add('jasonette-tab');
          tabsEl.appendChild(tabEl);
        }
        applyStyle(tabsEl, tabs.style);
        el.appendChild(tabsEl);
      }
    }

    if (footer.input && typeof footer.input === 'object') {
      const input = footer.input as Record<string, JasonComponent>;
      const inputEl = document.createElement('div');
      inputEl.className = 'jasonette-footer-input';
      inputEl.style.display = 'flex';

      if (input.left) inputEl.appendChild(renderItem(input.left, this.state.styles));
      if (input.textfield) inputEl.appendChild(renderItem(input.textfield, this.state.styles));
      if (input.right) inputEl.appendChild(renderItem(input.right, this.state.styles));

      el.appendChild(inputEl);
    }

    return el;
  }

  private setupPullToRefresh(scrollTarget: HTMLElement): void {
    let startY = 0;
    let pulling = false;

    scrollTarget.addEventListener('touchstart', (e: TouchEvent) => {
      if (scrollTarget.scrollTop === 0) {
        startY = e.touches[0].clientY;
        pulling = true;
      }
    }, { passive: true });

    scrollTarget.addEventListener('touchend', (e: TouchEvent) => {
      if (pulling) {
        const dist = e.changedTouches[0].clientY - startY;
        pulling = false;
        if (dist > 80) {
          this.triggerLifecycle('$pull');
        }
      }
    }, { passive: true });
  }

  /**
   * Navigate to a new $jason document.
   */
  async navigate(
    url: string,
    options?: Record<string, unknown>,
  ): Promise<void> {
    const transition = (options?.transition as string) ?? 'push';
    const resolvedUrl = resolveNavigationUrl(url, this.state.url);
    const params = paramsFromNavigationOptions(options);

    if (transition === 'replace') {
      await this.load(resolvedUrl, { params });
    } else if (transition === 'modal') {
      // Open as modal overlay
      const modal = document.createElement('dialog');
      modal.className = 'jasonette-modal';
      modal.style.width = '100%';
      modal.style.height = '100%';
      modal.style.maxWidth = '100%';
      modal.style.maxHeight = '100%';
      modal.style.padding = '0';
      modal.style.border = 'none';

      const innerRoot = document.createElement('div');
      innerRoot.className = 'jasonette';
      innerRoot.style.width = '100%';
      innerRoot.style.height = '100%';
      modal.appendChild(innerRoot);

      document.body.appendChild(modal);
      modal.showModal();

      const childRenderer = new JasonetteRenderer(innerRoot);
      await childRenderer.load(resolvedUrl, { params });

      modal.addEventListener('close', () => modal.remove());
    } else {
      // Push navigation
      if (this.state.document && this.state.url) {
        this.state.history.push({
          url: this.state.url,
          document: this.state.document,
          params: cloneParams(this.state.params),
        });
      }
      await this.load(resolvedUrl, { params });
    }
  }

  /**
   * Go back in navigation history.
   */
  back(): void {
    const prev = this.state.history.pop();
    if (prev) {
      this.state.url = prev.url;
      this.state.params = cloneParams(prev.params);
      this.renderDocument(prev.document);
    } else {
      history.back();
    }
  }

  /**
   * Get current state (for testing/debugging).
   */
  getState(): AppState {
    return this.state;
  }
}
