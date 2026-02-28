# Jasonette v2.0 Action Catalogue

## Tier 1 — Core (v1.0)

### Rendering

| Action | Description |
|---|---|
| `$render` | Re-render body with current or specified data/template |
| `$reload` | Re-fetch JSON document from URL and re-render |

### Navigation

| Action | Description |
|---|---|
| `$href` | Navigate to another screen (push/modal/replace/fullscreen) |
| `$back` | Pop navigation stack |
| `$close` | Dismiss modal screen |

### Action Invocation

| Action | Description |
|---|---|
| `trigger` | Invoke named action (recommended form) |
| `$lambda` | Invoke named action (explicit form) |
| `$return.success` | Return success value from named action |
| `$return.error` | Return error value from named action |

### Network

| Action | Description |
|---|---|
| `$network.request` | HTTP request (GET/POST/PUT/DELETE/PATCH) |

### State Management

| Action | Description |
|---|---|
| `$set` | Set local screen state (accessible via `$get.key`) |
| `$cache.set` | Store data in persistent per-URL cache |
| `$cache.get` | Retrieve cached data |
| `$cache.reset` | Clear cached data |
| `$session.set` | Store session data (headers/body) for a domain |
| `$session.get` | Retrieve session data |
| `$session.reset` | Clear session data |
| `$flush` | Per-URL cache reset shorthand |

### UI Feedback

| Action | Description |
|---|---|
| `$util.alert` | Alert dialog with optional form fields |
| `$util.banner` | Notification banner (info/success/warning/error) |
| `$util.toast` | Toast message |
| `$util.picker` | Selection picker |
| `$util.datepicker` | Date picker |
| `$util.share` | System share sheet |

### Timers

| Action | Description |
|---|---|
| `$timer.start` | Start repeating/one-shot timer |
| `$timer.stop` | Stop timer by name |

### Debug

| Action | Description |
|---|---|
| `$log` | Console output (`$log.info`, `$log.debug`, `$log.error`) |

---

## Tier 2 — Extended (v1.1)

| Action | Description |
|---|---|
| `$media.camera` | Capture photo/video from camera |
| `$media.picker` | Select photo/video from library |
| `$media.play` | Play video content |
| `$network.upload` | File upload (multipart/form-data) |
| `$geo.get` | Get current GPS coordinates |
| `$geo.watch` | Watch GPS coordinate changes |
| `$audio.play` | Play audio file |
| `$audio.record` | Record audio |
| `$audio.stop` | Stop audio playback/recording |
| `$agent.request` | Web container agent request |
| `$agent.response` | Web container agent response |
| `$global.set` | Set cross-screen global state |
| `$global.get` | Get cross-screen global state |
| `$global.reset` | Reset cross-screen global state |
| `$convert.csv` | Convert CSV to JSON |
| `$convert.rss` | Convert RSS/XML to JSON |
| `$snapshot` | Screenshot capture |
| `$util.addressbook` | Access device contacts |
| `$notification.register` | Register for notifications |
| `$notification.local` | Schedule local notification |
| `$default` | Web container default browser behavior |
| `$require` | Fetch multiple JSON files in parallel |
| `$ok` | Close view and return data to caller |

---

## Tier 3 — Advanced (v1.2)

| Action | Description |
|---|---|
| `$oauth` | OAuth authentication (PKCE) |
| `$websocket.open` | Open WebSocket connection |
| `$websocket.send` | Send WebSocket message |
| `$websocket.close` | Close WebSocket connection |
| `$push.register` | Register for push notifications |
| `$push.onNotification` | Handle push notification |
| `$script.include` | Load external/inline JS (script engine context only) |
| `$vision.scan` | Barcode/QR scanning |
| `$widget.banner` | iOS widget notification |
| `$convert.base64` | Base64 encode/decode |
| `$convert.md5` | MD5 hash |
| `$convert.sha1` | SHA1 hash |

---

## Lifecycle Hooks

| Hook | Fires When |
|---|---|
| `$load` | Screen first renders (once) |
| `$show` | Screen becomes visible (see spec for interaction rules) |
| `$foreground` | App returns from background |
| `$background` | App enters background |
| `$pull` | Pull-to-refresh gesture |

## Hardware Event Hooks

| Hook | Fires When |
|---|---|
| `$vision.ready` | Scanner hardware ready |
| `$vision.onscan` | Scan completed |
