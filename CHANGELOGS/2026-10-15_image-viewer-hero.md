# Full-screen image viewer with Hero

## What
- New `ui/chat/components/image_viewer.dart`: `ChatImageTap` (Hero + tap on a thumbnail), `openImageViewer`, `ImageViewer` (transparent route, PageView with counter, pinch / double-tap zoom, drag to dismiss, close button, loading and error states).
- All three styles wrap single images and every `ImageGrid` tile with it. Hero tag: `chatwoot-image-<messageId>-<index>`.
- A tap on an image opens the viewer and does not call `onMessageTap`; a failed message keeps tap-to-resend (viewer disabled for it).
- New l10n string `closeLabel` in all 6 languages. Zoomed images block paging and dismiss-drag.

## Why
Images were display-only; users could not view them larger.
