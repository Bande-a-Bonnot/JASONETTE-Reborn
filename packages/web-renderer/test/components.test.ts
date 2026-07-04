import { describe, it, expect } from 'vitest';
import { renderComponent } from '../src/components/index.js';

describe('renderComponent', () => {
  it('renders label', () => {
    const el = renderComponent({ type: 'label', text: 'Hello' }, {});
    expect(el.tagName).toBe('P');
    expect(el.textContent).toBe('Hello');
    expect(el.getAttribute('data-jasonette-type')).toBe('label');
  });

  it('renders button with text', () => {
    const el = renderComponent({ type: 'button', text: 'Click' }, {});
    expect(el.tagName).toBe('BUTTON');
    expect(el.textContent).toBe('Click');
  });

  it('renders button with image', () => {
    const el = renderComponent({ type: 'button', url: 'https://img.png', text: 'alt' }, {});
    const img = el.querySelector('img');
    expect(img).not.toBeNull();
    expect(img?.src).toContain('https://img.png');
  });

  it('renders image', () => {
    const el = renderComponent({ type: 'image', url: 'https://img.png' }, {});
    expect(el.tagName).toBe('IMG');
    expect((el as HTMLImageElement).src).toContain('https://img.png');
  });

  it('renders textfield', () => {
    const el = renderComponent({
      type: 'textfield',
      name: 'email',
      placeholder: 'Enter email',
    }, {}) as HTMLInputElement;
    expect(el.tagName).toBe('INPUT');
    expect(el.name).toBe('email');
    expect(el.placeholder).toBe('Enter email');
  });

  it('renders textarea', () => {
    const el = renderComponent({
      type: 'textarea',
      name: 'bio',
      placeholder: 'About you',
    }, {}) as HTMLTextAreaElement;
    expect(el.tagName).toBe('TEXTAREA');
    expect(el.name).toBe('bio');
  });

  it('renders slider', () => {
    const el = renderComponent({ type: 'slider', name: 'volume', value: 50 }, {}) as HTMLInputElement;
    expect(el.type).toBe('range');
    expect(el.value).toBe('50');
  });

  it('renders space', () => {
    const el = renderComponent({ type: 'space' }, {});
    expect(el.className).toContain('jasonette-space');
    expect(el.style.flex).toContain('1');
  });

  it('renders space with height', () => {
    const el = renderComponent({ type: 'space', style: { height: 20 } }, {});
    expect(el.style.height).toBe('20px');
  });

  it('renders switch', () => {
    const el = renderComponent({ type: 'switch', name: 'notifications' }, {});
    const input = el.querySelector('input[type="checkbox"]') as HTMLInputElement;
    expect(input).not.toBeNull();
    expect(input.name).toBe('notifications');
  });

  it('renders html text with authored css in srcdoc', () => {
    const el = renderComponent({
      type: 'html',
      css: 'p{color:red;}',
      text: '<p>Hello</p>',
    }, {});
    const iframe = el.querySelector('iframe') as HTMLIFrameElement;
    expect(iframe).not.toBeNull();
    expect(iframe.srcdoc).toContain('<style>p{color:red;}</style>');
    expect(iframe.srcdoc).toContain('<p>Hello</p>');
  });

  it('renders html url as iframe src without inline css injection', () => {
    const el = renderComponent({
      type: 'html',
      css: 'p{color:red;}',
      url: 'https://example.com/article.html',
    }, {});
    const iframe = el.querySelector('iframe') as HTMLIFrameElement;
    expect(iframe).not.toBeNull();
    expect(iframe.src).toContain('https://example.com/article.html');
    expect(iframe.srcdoc).toBe('');
  });

  it('renders unknown type', () => {
    const el = renderComponent({ type: 'unknown-widget' }, {});
    expect(el.textContent).toContain('Unknown');
  });

  it('applies inline style', () => {
    const el = renderComponent({
      type: 'label',
      text: 'Styled',
      style: { color: 'red', size: 16 },
    }, {});
    expect(el.style.color).toBe('red');
    expect(el.style.fontSize).toBe('16px');
  });

  it('applies class-based style', () => {
    const headStyles = {
      bold: { font: 'HelveticaNeue-Bold' },
    };
    const el = renderComponent({
      type: 'label',
      text: 'Bold',
      class: 'bold',
    }, headStyles);
    expect(el.style.fontFamily).toBe('HelveticaNeue-Bold');
    expect(el.classList.contains('bold')).toBe(true);
  });
});
