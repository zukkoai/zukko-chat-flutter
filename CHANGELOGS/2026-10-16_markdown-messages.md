# Markdown in incoming messages

## What
Messages from the agent / AI / operators are rendered as Markdown in all three styles: paragraphs, line breaks, bold, italic, strike, inline code, code blocks, links, bullet and ordered lists (nested), headings (modestly scaled), blockquotes, rules and simple tables. The visitor's own messages stay plain text.

## Why
The AI agent and operators reply in Markdown (`**Narxi:**`); the SDK showed the raw stars. The Zukko Chat web widget already renders it.

## Fix
- New `lib/src/ui/chat/components/markdown_text.dart` (`MarkdownText`), used by `ChatTextMessage` for incoming messages. Parser: the Dart `markdown` package (GFM extension set), rendered to our own widgets with the style's tokens (no hardcoded colors).
- Parsed once per text (in State, re-parsed only when the text changes).
- Links reuse `parseLink` / `openExternalLink` (http/https only); other schemes show as plain text.
- Raw HTML is never interpreted: it shows as literal text.
- Images are not loaded: shown as a link (alt text or URL).
- Tables are a bordered grid, scrollable sideways; code blocks scroll sideways, monospace, tinted from the text color.
- Plain text (one paragraph, no markup) still goes through `LinkifiedText`, so it looks exactly as before.
- Tests: `test/ui/chat/components/markdown_text_test.dart`.
