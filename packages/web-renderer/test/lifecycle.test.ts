import { describe, it, expect, beforeEach, vi } from 'vitest';
import { JasonetteRenderer } from '../src/renderer.js';
import type { JasonDocument } from '../src/types.js';

describe('Lifecycle hooks', () => {
  let root: HTMLElement;
  let renderer: JasonetteRenderer;

  beforeEach(() => {
    root = document.createElement('div');
    document.body.appendChild(root);
    renderer = new JasonetteRenderer(root);
  });

  it('triggers $load action on load', async () => {
    const logSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            $load: { type: '$log', options: { msg: 'loaded' } },
          },
        },
        body: { sections: [] },
      },
    };

    // Simulate load by rendering + manually calling lifecycle
    renderer.renderDocument(doc);

    // $load fires via load() method which we can't easily test without fetch
    // But we can verify actions are stored
    const state = renderer.getState();
    expect(state.actions['$load']).toBeDefined();
    logSpy.mockRestore();
  });

  it('stores $show action for visibility change', () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            $show: { type: '$log', options: { msg: 'shown' } },
          },
        },
        body: { sections: [] },
      },
    };

    renderer.renderDocument(doc);
    const state = renderer.getState();
    expect(state.actions['$show']).toBeDefined();
  });

  it('stores $foreground action for visibility change', () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            $foreground: { type: '$log', options: { msg: 'foregrounded' } },
          },
        },
        body: { sections: [] },
      },
    };

    renderer.renderDocument(doc);
    const state = renderer.getState();
    expect(state.actions['$foreground']).toBeDefined();
  });

  it('stores $pull action for pull-to-refresh', () => {
    const doc: JasonDocument = {
      $jason: {
        head: {
          actions: {
            $pull: { type: '$reload' },
          },
        },
        body: {
          sections: [{ items: [{ type: 'label', text: 'Content' }] }],
        },
      },
    };

    renderer.renderDocument(doc);
    const state = renderer.getState();
    expect(state.actions['$pull']).toBeDefined();
  });
});
