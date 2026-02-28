---
layout: post
title: Supercharged tab bar!
image: assets/tabbar.png
---

With the latest version, Jasonette now supports [href](https://docs.jasonette.com/href) and [action](https://docs.jasonette.com/action) attributes for the bottom tab bar, which lets you do cool things like open a view in a modal, or execute any actions when you tap a tab item.

Let me explain what this means.

## How it currently works

The [bottom tab bar](https://docs.jasonette.com/document/#tabs) is useful for switching between multiple views.

<img class='bordered medium' src='http://docs.jasonette.com/images/footer_tabs.jpeg'>

Normally to make sure the each tab loads a separate view when tapped, you would simply specify the `url` attribute like this:

```json
{
  "$jason": {
    "body": {
      "footer": {
        "tabs": {
          "items": [{
            "text": "Tab 1",
            "url": "https://jasonbase.com/things/3fn.json"
          }, {
            "text": "Tab 2",
            "url": "https://jasonbase.com/things/2fn.json"
          }, {
            "text": "Tab 3",
            "url": "https://jasonbase.com/things/9fn.json"
          }]
        }
      }
    }
  }
}
```

This is sufficient for most use cases, but sometimes you want more. For example you may want to:

1. Open a new view as a modal instead of as a tab view.
2. Open a browser when you tap a tab item.
2. Exectue an action (Such as open a camera) when you tap.

These things weren't possible since the only supported attribute was `url`.

However, this changes today. You can attach not only `url` but also [href](https://docs.jasonette.com/href/) as well as [action](https://docs.jasonette.com/actions/).


Go download the `develop` branch ([iOS](https://github.com/Jasonette/JASONETTE-iOS) and [Android](https://github.com/Jasonette/JASONETTE-Android)) and try it out. Here's what has changed:

## href
You can now set `href` as well as `url`. [href](https://docs.jasonette.com/href/) is obviously more powerful since you can specify not just the url but also the `view` or the type of `transition`.

<img class='bordered medium' src='/assets/tab_href.gif'>

See below example:

```json
{
  "$jason": {
    "body": {
      "footer": {
        "tabs": {
          "items": [{
            "text": "Tab 1",
            "url": "https://jasonbase.com/things/3fn.json"
          }, {
            "text": "Tab 2",
            "href": {
              "url": "https://jasonbase.com/things/2fn.json",
              "transition": "modal"
            }
          }, {
            "text": "Tab 3",
            "href": {
              "url": "https://www.google.com",
              "view": "web"
            }
          }]
        }
      }
    }
  }
}
```

1. `tab 1` uses the original `url` approach. It's simpler and usually works for most cases.
2. `tab 2` now opens in a modal view when you tap, instead of opening within the current view.
3. `tab 3` now opens a browser since it's a `"view": "web"` type href.


## action

You can even set an `action` attribute for a tab. You may see something like this in photo apps like Instagram--you tap one of the tab bar items and it opens a camera.

<img class='bordered medium' src='/assets/tab_action.gif'>

Here's an example:

```json
{
  "$jason": {
    "body": {
      "footer": {
        "tabs": {
          "items": [{
            "text": "Tab 1",
            "url": "https://jasonbase.com/things/3fn.json"
          }, {
            "text": "Tab 2",
            "action": {
              "type": "$media.camera"
            }
          }, {
            "text": "Tab 3",
            "href": {
              "url": "https://www.google.com",
              "view": "web"
            }
          }]
        }
      }
    }
  }
}
```

`Tab 2` now runs the [$media.camera action](https://docs.jasonette.com/actions/#mediacamera) when you tap.

Note that you can attach **any** kind of actions here, not just camera.


## Tip

Sometimes people are confused about how the tabs work. Here's a rule of thumb:

**You MUST specify the tabs for every view.**

Let's say you have tab1, tab2, and tab3. All of those views MUST contain the **same** `tabs` object. If you only have the `tabs` object on `tab1`'s markup, the tab bar will go away when you navigate away to tab2 or tab3.

## Try it out!
As of today this works on both [Android](https://github.com/Jasonette/JASONETTE-Android) and [iOS](https://github.com/Jasonette/JASONETTE-iOS)
