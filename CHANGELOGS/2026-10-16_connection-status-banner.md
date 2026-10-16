# Connection status banner

## What
A thin banner under the header (all 3 styles) shows "No internet connection" or "Connecting…" when the realtime link is down, and hides when it is back. It only appears after 2 s of being down, so short blips and the normal first connect show nothing. Strings added to all 6 locales (`noInternetText`, `connectingText`); the banner is a live region and animates only when reduce-motion is off.

## Why
Users had no sign that messages were not flowing while offline or reconnecting (TODO #16).

## Fix
No new package. The websocket state (`ZukkoChatConnectionState`) is the ground truth for "can we reach the Zukko Chat backend"; `ChatConnectionMonitor` turns it into the banner. "No internet" = our own backend host does not resolve (a DNS lookup of the host only, rechecked every 3 s while down; no third-party host, no plugin, no permission). When the host resolves again the monitor calls `client.resume()`, which now skips a pending backoff (`ZukkoChatSocket.retryNow`); the normal `after=` catch-up runs once subscribed. `onConnectionStateChanged` is unchanged.
