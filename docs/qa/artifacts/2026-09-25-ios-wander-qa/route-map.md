# Offline route map — Jasonpedia Tutorial

Source: `Jasonpedia/demo.json` plus the linked category index fixtures read
from the checkout. All URLs below are the document targets authored in those
fixtures. Navigate from the home screen by tapping the label; do not launch
these as entry overrides during the wander pass.

## Home: Jasonpedia Tutorial

| Home label | Category entry | Representative nested route |
| --- | --- | --- |
| Core | `Jasonpedia/core/index.json` | `$render` → `Jasonpedia/core/render/index.json` → “Multiple templates” → `Jasonpedia/core/render/templates.json` |
| View | `Jasonpedia/view/index.json` | `Layout` → `Jasonpedia/view/layout/index.json` → `Horizontal Layout` → `Jasonpedia/view/layout/horizontal.json`; also `Component` → `Jasonpedia/view/component/index.json` → `HTML` → `Jasonpedia/view/component/html/index.json` |
| Action | `Jasonpedia/action/index.json` | Safe visible action: tap `$util.toast` in the first `$util` section. Optional action screen: `$geo.get` → `Jasonpedia/action/geo/index.json`, then Display or Map (requires interaction and location permission) |
| Template | `Jasonpedia/template/index.json` | “Inline Data” → `Jasonpedia/template/inline.json`; alternative `#each` → `Jasonpedia/template/each.json` |
| Web Container | `Jasonpedia/webcontainer/index.json` | Select “SVG Clock” / SVG entry → `Jasonpedia/webcontainer/svg.json` |

## Other known routes

- View components: `Jasonpedia/view/component/index.json` lists label, image,
  button, HTML, map, slider, textarea, textfield, space, and common styling.
- Core navigation: `Jasonpedia/core/href/index.json` includes push/modal
  documents, tabs, external mail, and browser targets. Prefer the internal push
  route during this pass; skip external app/browser actions unless specifically
  needed.
- Action index starts with `$util.banner`, `$util.toast`, `$util.alert`, and
  picker/date picker actions. `$util.toast` is the low-risk visible action for
  initial exploration.
- Showcase links on `demo.json` point to external Instagram and Twitter demo
  documents. The plan says to sample these only if they load promptly.

## Planned navigation discipline

For each category, capture the home/category screen, tap into one nested item,
record the rendered screen, then use the app's own back navigation to return to
the home screen before entering the next Tutorial category. For View, include
both a layout and component route. Record a route as completed only after a tap
and observed in-app transition; a direct-entry launch is recovery evidence, not
a completed navigation path.
