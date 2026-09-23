import json
from pathlib import Path
from shutil import copyfile

repo = Path(__file__).resolve().parents[3]
out = Path('/private/tmp/jasonette-browser-fixture')
out.mkdir(exist_ok=True)
copyfile(repo / 'packages/web-renderer/dist/jasonette.umd.js', out / 'jasonette.umd.js')

def child(name):
    js = f'''(() => {{
      const result = {{id: {json.dumps(name)}, ran: true, childOrigin: location.origin}};
      for (const [key, check] of Object.entries({{
        parentDOM: () => parent.document.getElementById('host-secret').textContent,
        parentStorage: () => parent.localStorage.getItem('host-secret'),
        childStorage: () => localStorage.getItem('host-secret'),
        topNavigation: () => {{ top.location.href = '/hijacked.html'; return 'accepted'; }}
      }})) {{ try {{ result[key] = check(); }} catch (error) {{ result[key] = error.name; }} }}
      parent.postMessage(result, '*');
    }})();'''
    return '<!doctype html><html><body><script>' + js + '</script></body></html>'

for name in ['component-url', 'background-url']:
    (out / f'{name}.html').write_text(child(name))
(out / 'hijacked.html').write_text('navigation should be denied')

script = '''
window.results = {};
window.errors = [];
addEventListener('error', event => window.errors.push(String(event.message)));
addEventListener('message', event => {
  if (event.data && event.data.id) window.results[event.data.id] = {...event.data, eventOrigin: event.origin};
});
localStorage.setItem('host-secret', 'parent-storage-secret');
const fixtures = __FIXTURES__;
for (const [id, value, isBackground] of fixtures) {
  const root = document.createElement('div');
  root.id = id;
  document.body.appendChild(root);
  const renderer = new Jasonette.JasonetteRenderer(root);
  const html = {type: 'html', ...value};
  const body = isBackground
    ? {background: html, sections: [{items: [{type: 'label', text: 'Foreground'}]}]}
    : {sections: [{items: [html]}]};
  renderer.renderDocument({$jason: {body}});
}
window.snapshot = () => ({
  href: location.href,
  parentStorage: localStorage.getItem('host-secret'),
  results: window.results,
  errors: window.errors,
  frames: [...document.querySelectorAll('iframe')].map(frame => ({
    id: frame.closest('[id]')?.id,
    sandbox: frame.getAttribute('sandbox'),
    src: frame.getAttribute('src'),
    srcdoc: frame.hasAttribute('srcdoc')
  }))
});
'''
fixtures = [
    ['component-inline', {'text': child('component-inline')}, False],
    ['component-url', {'url': '/component-url.html'}, False],
    ['background-inline', {'text': child('background-inline')}, True],
    ['background-url', {'url': '/background-url.html'}, True],
]
script = script.replace('__FIXTURES__', json.dumps(fixtures).replace("</", "<\\/"))
(out / 'index.html').write_text('<!doctype html><html><body><div id="host-secret">parent-dom-secret</div><script src="/jasonette.umd.js"></script><script>' + script + '</script></body></html>')
print(out)
