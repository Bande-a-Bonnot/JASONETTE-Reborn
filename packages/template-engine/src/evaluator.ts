import jsep from 'jsep';
import type { RenderContext, RenderOptions } from './types.js';

// Register 'in' as a binary operator (precedence 11, same as relational <, >, etc.)
jsep.addBinaryOp('in', 11);

const BLOCKED_PROPERTIES = new Set(['__proto__', 'constructor', 'prototype']);

const ALLOWED_FUNCTIONS: Record<string, Record<string, Function>> = {
  Math: {
    floor: Math.floor, ceil: Math.ceil, round: Math.round,
    random: Math.random, abs: Math.abs, min: Math.min, max: Math.max,
    pow: Math.pow, sqrt: Math.sqrt,
  },
  JSON: {
    stringify: JSON.stringify, parse: JSON.parse,
  },
};

const ALLOWED_GLOBALS: Record<string, Function> = {
  parseInt, parseFloat, String, Number,
  encodeURIComponent, decodeURIComponent,
  isNaN, isFinite,
};

// LRU cache for parsed expressions
const expressionCache = new Map<string, jsep.Expression>();
const MAX_CACHE = 1000;

function getCachedExpression(expr: string): jsep.Expression {
  if (expressionCache.has(expr)) {
    const ast = expressionCache.get(expr)!;
    // Move to end (LRU)
    expressionCache.delete(expr);
    expressionCache.set(expr, ast);
    return ast;
  }
  const ast = jsep(expr);
  if (expressionCache.size >= MAX_CACHE) {
    const firstKey = expressionCache.keys().next().value;
    if (firstKey !== undefined) expressionCache.delete(firstKey);
  }
  expressionCache.set(expr, ast);
  return ast;
}

function countNodes(node: jsep.Expression): number {
  let count = 1;
  if ('left' in node && node.left) count += countNodes(node.left as jsep.Expression);
  if ('right' in node && node.right) count += countNodes(node.right as jsep.Expression);
  if ('test' in node && node.test) count += countNodes(node.test as jsep.Expression);
  if ('consequent' in node && node.consequent) count += countNodes(node.consequent as jsep.Expression);
  if ('alternate' in node && node.alternate) count += countNodes(node.alternate as jsep.Expression);
  if ('argument' in node && node.argument) count += countNodes(node.argument as jsep.Expression);
  if ('object' in node && node.object) count += countNodes(node.object as jsep.Expression);
  if ('property' in node && node.property) count += countNodes(node.property as jsep.Expression);
  if ('callee' in node && node.callee) count += countNodes(node.callee as jsep.Expression);
  if ('arguments' in node && Array.isArray(node.arguments)) {
    for (const arg of node.arguments) count += countNodes(arg as jsep.Expression);
  }
  return count;
}

function measureDepth(node: jsep.Expression, current = 0): number {
  let max = current;
  const children: (jsep.Expression | undefined)[] = [];
  if ('left' in node) children.push(node.left as jsep.Expression);
  if ('right' in node) children.push(node.right as jsep.Expression);
  if ('test' in node) children.push(node.test as jsep.Expression);
  if ('consequent' in node) children.push(node.consequent as jsep.Expression);
  if ('alternate' in node) children.push(node.alternate as jsep.Expression);
  if ('argument' in node) children.push(node.argument as jsep.Expression);
  if ('object' in node) children.push(node.object as jsep.Expression);
  if ('callee' in node) children.push(node.callee as jsep.Expression);
  if ('arguments' in node && Array.isArray(node.arguments)) {
    for (const arg of node.arguments) children.push(arg as jsep.Expression);
  }
  for (const child of children) {
    if (child) max = Math.max(max, measureDepth(child, current + 1));
  }
  return max;
}

function walkAst(node: jsep.Expression, context: Record<string, unknown>): unknown {
  switch (node.type) {
    case 'Literal':
      return (node as jsep.Literal).value;

    case 'Identifier': {
      const name = (node as jsep.Identifier).name;
      if (name in context) return context[name];
      // Check allowed globals
      if (name in ALLOWED_GLOBALS) return ALLOWED_GLOBALS[name];
      return undefined;
    }

    case 'ThisExpression':
      return context['this'];

    case 'MemberExpression': {
      const memberNode = node as jsep.MemberExpression;
      const obj = walkAst(memberNode.object, context);
      if (obj == null) return undefined;

      let prop: unknown;
      if (memberNode.computed) {
        prop = walkAst(memberNode.property, context);
      } else {
        prop = (memberNode.property as jsep.Identifier).name;
      }

      if (typeof prop === 'string' && BLOCKED_PROPERTIES.has(prop)) {
        return undefined;
      }

      // Handle allowed function namespaces (Math, JSON)
      if (typeof obj === 'string' && obj in ALLOWED_FUNCTIONS && typeof prop === 'string') {
        return ALLOWED_FUNCTIONS[obj]?.[prop];
      }

      if (obj && typeof obj === 'object' && prop !== undefined) {
        return (obj as Record<string, unknown>)[String(prop)];
      }
      if (typeof obj === 'string' && prop === 'length') return obj.length;
      if (Array.isArray(obj) && prop === 'length') return obj.length;
      return undefined;
    }

    case 'CallExpression': {
      const callNode = node as jsep.CallExpression;
      const callee = walkAst(callNode.callee, context);
      if (typeof callee !== 'function') return undefined;

      const args = callNode.arguments.map(arg => walkAst(arg as jsep.Expression, context));

      // Verify function is in allowlist
      const calleeName = getCalleeName(callNode.callee);
      if (!isAllowedFunction(calleeName)) return undefined;

      return callee(...args);
    }

    case 'BinaryExpression': {
      const binNode = node as jsep.BinaryExpression;
      const left = walkAst(binNode.left, context);
      const right = walkAst(binNode.right, context);
      return evalBinaryOp(binNode.operator, left, right);
    }

    case 'UnaryExpression': {
      const unaryNode = node as jsep.UnaryExpression;
      const arg = walkAst(unaryNode.argument, context);
      switch (unaryNode.operator) {
        case '!': return !arg;
        case '-': return -(arg as number);
        case '+': return +(arg as number);
        default: return undefined;
      }
    }

    case 'ConditionalExpression': {
      const condNode = node as jsep.ConditionalExpression;
      const test = walkAst(condNode.test, context);
      return test
        ? walkAst(condNode.consequent, context)
        : walkAst(condNode.alternate, context);
    }

    case 'ArrayExpression': {
      const arrNode = node as jsep.ArrayExpression;
      return arrNode.elements.map(el =>
        el ? walkAst(el as jsep.Expression, context) : undefined
      );
    }

    case 'Compound': {
      // Multiple expressions — evaluate each, return last
      const compound = node as jsep.Compound;
      let result: unknown;
      for (const expr of compound.body) {
        result = walkAst(expr as jsep.Expression, context);
      }
      return result;
    }

    default:
      // Reject unsupported node types (assignment, etc.)
      return undefined;
  }
}

function getCalleeName(node: jsep.Expression): string {
  if (node.type === 'Identifier') return (node as jsep.Identifier).name;
  if (node.type === 'MemberExpression') {
    const member = node as jsep.MemberExpression;
    const obj = member.object.type === 'Identifier'
      ? (member.object as jsep.Identifier).name
      : '';
    const prop = member.property.type === 'Identifier'
      ? (member.property as jsep.Identifier).name
      : '';
    return `${obj}.${prop}`;
  }
  return '';
}

function isAllowedFunction(name: string): boolean {
  if (name in ALLOWED_GLOBALS) return true;
  const parts = name.split('.');
  if (parts.length === 2) {
    return parts[0] in ALLOWED_FUNCTIONS && parts[1] in (ALLOWED_FUNCTIONS[parts[0]] ?? {});
  }
  return false;
}

function defineLazyValue(
  target: Record<string, unknown>,
  name: string,
  read: () => unknown,
): void {
  let hasRead = false;
  let cachedValue: unknown;
  Object.defineProperty(target, name, {
    enumerable: true,
    configurable: true,
    get: () => {
      if (!hasRead) {
        cachedValue = read();
        hasRead = true;
      }
      return cachedValue;
    },
  });
}

function collectIdentifiers(node: jsep.Expression, identifiers: Set<string>): void {
  switch (node.type) {
    case 'Identifier':
      identifiers.add((node as jsep.Identifier).name);
      return;
    case 'ThisExpression':
      identifiers.add('this');
      return;
    case 'MemberExpression': {
      const member = node as jsep.MemberExpression;
      collectIdentifiers(member.object, identifiers);
      if (member.computed) {
        collectIdentifiers(member.property, identifiers);
      }
      return;
    }
    case 'CallExpression': {
      const call = node as jsep.CallExpression;
      collectIdentifiers(call.callee, identifiers);
      for (const arg of call.arguments) {
        collectIdentifiers(arg as jsep.Expression, identifiers);
      }
      return;
    }
    case 'BinaryExpression': {
      const binary = node as jsep.BinaryExpression;
      collectIdentifiers(binary.left, identifiers);
      collectIdentifiers(binary.right, identifiers);
      return;
    }
    case 'UnaryExpression':
      collectIdentifiers((node as jsep.UnaryExpression).argument, identifiers);
      return;
    case 'ConditionalExpression': {
      const conditional = node as jsep.ConditionalExpression;
      collectIdentifiers(conditional.test, identifiers);
      collectIdentifiers(conditional.consequent, identifiers);
      collectIdentifiers(conditional.alternate, identifiers);
      return;
    }
    case 'ArrayExpression':
      for (const item of (node as jsep.ArrayExpression).elements) {
        if (item) {
          collectIdentifiers(item as jsep.Expression, identifiers);
        }
      }
      return;
    case 'Compound':
      for (const expression of (node as jsep.Compound).body) {
        collectIdentifiers(expression as jsep.Expression, identifiers);
      }
  }
}

function buildFlatContext(context: RenderContext): Record<string, unknown> {
  const flatContext: Record<string, unknown> = {};
  const sourceContext = context as Record<string, unknown>;

  // Object spread used to read every context getter for every expression.
  // Install lazy accessors with the same precedence so only identifiers used
  // by this expression are observed, in AST evaluation order.
  for (const name of Object.keys(sourceContext)) {
    defineLazyValue(flatContext, name, () => sourceContext[name]);
  }

  for (const name of ['$jason', '$get', '$params', '$env', '$root', '$index', '$cache', '$response', '$keys']) {
    defineLazyValue(flatContext, name, () => sourceContext[name]);
  }
  defineLazyValue(flatContext, 'this', () => sourceContext.$jason);

  Object.defineProperty(flatContext, 'Math', { value: 'Math', enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'JSON', { value: 'JSON', enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'true', { value: true, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'false', { value: false, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'null', { value: null, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'undefined', { value: undefined, enumerable: true, configurable: true, writable: true });

  const jason = context.$jason;
  if (jason && typeof jason === 'object' && !Array.isArray(jason)) {
    const sourceJason = jason as Record<string, unknown>;
    for (const name of Object.keys(sourceJason)) {
      defineLazyValue(flatContext, name, () => sourceJason[name]);
    }
  }

  return flatContext;
}

function buildBodyKeyContext(
  context: RenderContext,
  expression: jsep.Expression,
  readJason: () => unknown,
): Record<string, unknown> {
  const flatContext: Record<string, unknown> = {};
  const sourceContext = context as Record<string, unknown>;

  const sourceNames = Object.keys(sourceContext);
  for (const name of sourceNames) {
    defineLazyValue(flatContext, name, () => sourceContext[name]);
  }

  for (const name of ['$jason', '$get', '$params', '$env', '$root', '$index', '$cache', '$response', '$keys']) {
    defineLazyValue(flatContext, name, name === '$jason' ? readJason : () => sourceContext[name]);
  }
  defineLazyValue(flatContext, 'this', readJason);

  Object.defineProperty(flatContext, 'Math', { value: 'Math', enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'JSON', { value: 'JSON', enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'true', { value: true, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'false', { value: false, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'null', { value: null, enumerable: true, configurable: true, writable: true });
  Object.defineProperty(flatContext, 'undefined', { value: undefined, enumerable: true, configurable: true, writable: true });

  const identifiers = new Set<string>();
  collectIdentifiers(expression, identifiers);

  // A bare name may come from either the render context or a flattened
  // $jason property. Resolve that collision when the identifier is actually
  // evaluated, preserving $jason's precedence and expression getter order.
  for (const name of identifiers) {
    const baseDescriptor = Object.getOwnPropertyDescriptor(flatContext, name);
    const jasonPosition = sourceNames.indexOf('$jason');
    const namePosition = sourceNames.indexOf(name);
    const readJasonFirst = jasonPosition !== -1 && (
      namePosition === -1 || jasonPosition < namePosition
    );
    const hasInheritedBaseValue = !baseDescriptor && name in flatContext;
    const inheritedBaseValue = hasInheritedBaseValue ? flatContext[name] : undefined;
    const readBaseValue = (): unknown => {
      if (!baseDescriptor) {
        return hasInheritedBaseValue ? inheritedBaseValue : ALLOWED_GLOBALS[name];
      }
      if (baseDescriptor.get) return baseDescriptor.get.call(flatContext);
      return baseDescriptor.value;
    };

    defineLazyValue(flatContext, name, () => {
      let baseValue: unknown;
      let jason: unknown;
      if (readJasonFirst) {
        jason = readJason();
        baseValue = readBaseValue();
      } else {
        baseValue = readBaseValue();
        jason = readJason();
      }
      if (jason && typeof jason === 'object' && !Array.isArray(jason)) {
        const sourceJason = jason as Record<string, unknown>;
        if (Object.prototype.propertyIsEnumerable.call(sourceJason, name)) {
          return sourceJason[name];
        }
      }
      return baseValue;
    });
  }

  return flatContext;
}

function parseExpression(expression: string, options?: RenderOptions): jsep.Expression | undefined {
  let ast: jsep.Expression;
  try {
    ast = getCachedExpression(expression);
  } catch {
    return undefined;
  }

  const maxDepth = options?.maxExpressionDepth ?? 20;
  const maxNodes = options?.maxExpressionNodes ?? 50;
  if (countNodes(ast) > maxNodes || measureDepth(ast) > maxDepth) return undefined;
  return ast;
}

function evalBinaryOp(op: string, left: unknown, right: unknown): unknown {
  switch (op) {
    case '+': return (left as number) + (right as number);
    case '-': return (left as number) - (right as number);
    case '*': return (left as number) * (right as number);
    case '/': return (left as number) / (right as number);
    case '%': return (left as number) % (right as number);
    case '==': return left == right;
    case '!=': return left != right;
    case '===': return left === right;
    case '!==': return left !== right;
    case '<': return (left as number) < (right as number);
    case '>': return (left as number) > (right as number);
    case '<=': return (left as number) <= (right as number);
    case '>=': return (left as number) >= (right as number);
    case '&&': return left && right;
    case '||': return left || right;
    case 'in': return typeof right === 'object' && right !== null && (left as string) in (right as Record<string, unknown>);
    default: return undefined;
  }
}

/**
 * Evaluate a template expression string against a context.
 */
export function evaluate(
  expression: string,
  context: RenderContext,
  options?: RenderOptions,
): unknown {
  const ast = parseExpression(expression, options);
  return ast ? walkAst(ast, buildFlatContext(context)) : undefined;
}

/**
 * Create a body-key evaluator that shares the lazy $jason read across keys in
 * one regular-object frame, while keeping each expression's direct getters
 * lazy and ordered by expression evaluation.
 */
export function createBodyKeyEvaluator(
  context: RenderContext,
  options?: RenderOptions,
): (expression: string) => unknown {
  let hasReadJason = false;
  let cachedJason: unknown;
  const readJason = (): unknown => {
    if (!hasReadJason) {
      cachedJason = context.$jason;
      hasReadJason = true;
    }
    return cachedJason;
  };

  return (expression: string): unknown => {
    const ast = parseExpression(expression, options);
    return ast ? walkAst(ast, buildBodyKeyContext(context, ast, readJason)) : undefined;
  };
}
