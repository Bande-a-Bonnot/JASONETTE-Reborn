#!/usr/bin/env node

import { readFileSync, existsSync, watch } from 'node:fs';
import { resolve, extname } from 'node:path';
import { createServer } from 'node:http';

const args = process.argv.slice(2);
const command = args[0];

function usage(): void {
  console.log(`Usage:
  jasonette serve <file.json>   Start dev server with live reload
  jasonette validate <file.json> Validate a $jason document

Options:
  --port <n>       Port for dev server (default: 3000)
  --format json    Output validation as JSON
  --help           Show this help`);
}

if (!command || command === '--help') {
  usage();
  process.exit(0);
}

if (command === 'serve') {
  const file = args[1];
  if (!file) {
    console.error('Error: missing file argument');
    usage();
    process.exit(1);
  }

  const filePath = resolve(file);
  if (!existsSync(filePath)) {
    console.error(`Error: file not found: ${filePath}`);
    process.exit(1);
  }

  const port = Number(args.indexOf('--port') >= 0 ? args[args.indexOf('--port') + 1] : 3000);

  const html = (jsonPath: string) => `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Jasonette Dev</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #app { height: 100%; }
  </style>
  <link rel="stylesheet" href="/__jasonette__/jasonette.css" />
</head>
<body>
  <div id="app"></div>
  <script type="module">
    import { JasonetteRenderer } from '/__jasonette__/index.js';

    const root = document.getElementById('app');
    const renderer = new JasonetteRenderer(root);

    async function loadDocument() {
      const res = await fetch('/__json__');
      const doc = await res.json();
      renderer.renderDocument(doc);
    }

    loadDocument();

    // Live reload via SSE
    const es = new EventSource('/__reload__');
    es.onmessage = () => loadDocument();
  </script>
</body>
</html>`;

  let clients: import('node:http').ServerResponse[] = [];

  const server = createServer((req, res) => {
    if (req.url === '/__reload__') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
      });
      res.write('data: connected\n\n');
      clients.push(res);
      req.on('close', () => {
        clients = clients.filter((c) => c !== res);
      });
      return;
    }

    if (req.url === '/__json__') {
      try {
        const content = readFileSync(filePath, 'utf-8');
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(content);
      } catch {
        res.writeHead(500);
        res.end('Error reading file');
      }
      return;
    }

    if (req.url?.startsWith('/__jasonette__/')) {
      const asset = req.url.replace('/__jasonette__/', '');
      const assetPath = resolve(import.meta.dirname, asset);
      if (existsSync(assetPath)) {
        const ext = extname(assetPath);
        const mimeTypes: Record<string, string> = {
          '.js': 'application/javascript',
          '.css': 'text/css',
          '.mjs': 'application/javascript',
        };
        res.writeHead(200, { 'Content-Type': mimeTypes[ext] ?? 'text/plain' });
        res.end(readFileSync(assetPath));
        return;
      }
    }

    // Default: serve the HTML shell
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html(filePath));
  });

  // Watch file for changes
  watch(filePath, () => {
    for (const client of clients) {
      client.write('data: reload\n\n');
    }
  });

  server.listen(port, () => {
    console.log(`Jasonette dev server running at http://localhost:${port}`);
    console.log(`Serving: ${filePath}`);
    console.log('Live reload enabled — editing the file will refresh the browser.');
  });
} else if (command === 'validate') {
  const file = args[1];
  if (!file) {
    console.error('Error: missing file argument');
    usage();
    process.exit(1);
  }

  const filePath = resolve(file);
  if (!existsSync(filePath)) {
    console.error(`Error: file not found: ${filePath}`);
    process.exit(1);
  }

  const formatJson = args.includes('--format') && args[args.indexOf('--format') + 1] === 'json';

  try {
    const content = readFileSync(filePath, 'utf-8');
    const doc = JSON.parse(content);

    const errors: string[] = [];

    if (!doc.$jason) {
      errors.push('Missing top-level $jason key');
    } else {
      if (!doc.$jason.head && !doc.$jason.body) {
        errors.push('$jason must have at least head or body');
      }

      if (doc.$jason.body?.sections) {
        if (!Array.isArray(doc.$jason.body.sections)) {
          errors.push('body.sections must be an array');
        }
      }

      if (doc.$jason.head?.templates?.body && !doc.$jason.head?.data) {
        errors.push('templates.body defined but no head.data provided');
      }
    }

    if (formatJson) {
      console.log(JSON.stringify({
        valid: errors.length === 0,
        file: filePath,
        errors,
      }, null, 2));
    } else if (errors.length > 0) {
      console.error(`Validation failed for ${file}:`);
      for (const err of errors) {
        console.error(`  - ${err}`);
      }
      process.exit(1);
    } else {
      console.log(`${file}: valid`);
    }
  } catch (err) {
    if (formatJson) {
      console.log(JSON.stringify({
        valid: false,
        file: filePath,
        errors: [`Parse error: ${err}`],
      }, null, 2));
    } else {
      console.error(`Error parsing ${file}: ${err}`);
      process.exit(1);
    }
  }
} else {
  console.error(`Unknown command: ${command}`);
  usage();
  process.exit(1);
}
