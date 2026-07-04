export interface RenderContext {
  /** Current data context ($jason) */
  $jason?: unknown;
  /** Local state ($get) */
  $get?: Record<string, unknown>;
  /** Navigation parameters ($params) */
  $params?: Record<string, unknown>;
  /** Environment variables ($env) */
  $env?: Record<string, unknown>;
  /** Cache data ($cache) */
  $cache?: Record<string, unknown>;
  /** Last network/action response ($response) */
  $response?: unknown;
  /** Config keys ($keys) */
  $keys?: Record<string, unknown>;
  /** Parent context in nested loops ($root) */
  $root?: unknown;
  /** Loop iteration index ($index) */
  $index?: number;
}

export interface RenderOptions {
  /** Maximum mixin recursion depth (default: 5) */
  maxMixinDepth?: number;
  /** Maximum expression AST depth (default: 20) */
  maxExpressionDepth?: number;
  /** Maximum expression AST nodes (default: 50) */
  maxExpressionNodes?: number;
  /** Expression evaluation timeout in ms (default: 10) */
  expressionTimeout?: number;
  /** Fetch function for remote mixins */
  fetch?: (url: string) => Promise<unknown>;
  /** The full document (for $document references) */
  document?: Record<string, unknown>;
}
