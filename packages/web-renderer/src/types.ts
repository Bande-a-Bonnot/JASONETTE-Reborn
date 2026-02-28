export interface JasonDocument {
  $jason: {
    head?: JasonHead;
    body?: JasonBody;
  };
}

export interface JasonHead {
  title?: string;
  data?: Record<string, unknown>;
  templates?: { body?: unknown };
  styles?: Record<string, JasonStyle>;
  actions?: Record<string, JasonAction>;
}

export interface JasonBody {
  background?: string | { type: string; url: string };
  header?: JasonHeader;
  sections?: JasonSection[];
  layers?: JasonComponent[];
  footer?: JasonFooter;
}

export interface JasonHeader {
  title?: string;
  style?: JasonStyle;
  menu?: {
    text?: string;
    image?: string;
    href?: JasonHref;
    action?: JasonAction;
  };
}

export interface JasonSection {
  type?: string;
  header?: JasonComponent;
  items?: JasonComponent[] | Record<string, unknown>;
  footer?: JasonComponent;
  style?: JasonStyle;
}

export interface JasonComponent {
  type?: string;
  text?: string;
  url?: string;
  name?: string;
  value?: unknown;
  placeholder?: string;
  class?: string;
  style?: JasonStyle;
  components?: JasonComponent[];
  href?: JasonHref;
  action?: JasonAction;
  [key: string]: unknown;
}

export interface JasonHref {
  url?: string;
  view?: 'web' | 'app' | 'jason';
  transition?: 'push' | 'modal' | 'replace';
  options?: Record<string, unknown>;
  preload?: Record<string, unknown>;
}

export interface JasonAction {
  type?: string;
  options?: Record<string, unknown>;
  success?: JasonAction;
  error?: JasonAction;
  [key: string]: unknown;
}

export interface JasonFooter {
  tabs?: {
    items?: JasonComponent[];
    style?: JasonStyle;
  };
  input?: {
    left?: JasonComponent;
    right?: JasonComponent;
    textfield?: JasonComponent;
  };
}

export interface JasonStyle {
  font?: string;
  size?: string | number;
  color?: string;
  background?: string;
  padding?: string | number;
  padding_left?: string | number;
  padding_right?: string | number;
  padding_top?: string | number;
  padding_bottom?: string | number;
  width?: string | number;
  height?: string | number;
  corner_radius?: string | number;
  border_width?: string | number;
  border_color?: string;
  opacity?: string | number;
  align?: string;
  spacing?: string | number;
  [key: string]: unknown;
}

export interface AppState {
  /** Current document URL */
  url: string | null;
  /** Current parsed document */
  document: JasonDocument | null;
  /** Head styles */
  styles: Record<string, JasonStyle>;
  /** Head actions */
  actions: Record<string, JasonAction>;
  /** Local state ($get/$set) */
  local: Record<string, unknown>;
  /** Cache state ($cache) */
  cache: Record<string, unknown>;
  /** Navigation history */
  history: Array<{ url: string; document: JasonDocument }>;
}
