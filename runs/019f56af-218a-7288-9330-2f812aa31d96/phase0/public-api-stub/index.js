// Red observer self-test stub: public render boundary only; not product implementation.
export function renderComponent(component) {
  const wrapper = document.createElement('div');
  wrapper.className = 'jasonette-html';
  const iframe = document.createElement('iframe');
  iframe.setAttribute('sandbox', 'allow-scripts');
  iframe.srcdoc = String(component.text ?? '');
  wrapper.appendChild(iframe);
  wrapper.setAttribute('data-jasonette-type', 'html');
  return wrapper;
}
export class JasonetteRenderer {}
