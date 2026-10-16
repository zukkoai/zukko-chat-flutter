# Link previews

## What
The first http(s) link of a text message now gets a preview card (title, description, https image) in all three styles. New option `ZukkoChatOptions.enableLinkPreviews` (default true).

## Why
`TextMessage.linkPreviewData` was never filled, so cards only showed the domain and address.

## Fix
- `components/link_preview_service.dart`: `LinkPreviewService` (session LRU cache of 100, failures cached, one request per URL), `fetchLinkPreview` (plain Dio without SDK auth headers, 5 s timeout, first 512 KB, html only) and `parseLinkPreview` (og:/twitter: tags, `<title>` fallback, https image only). No new dependency (`flutter_link_previewer` would add http/html/punycode and its own widget, with no size cap).
- `LoadedLinkPreviewCard` fetches lazily on first build through `LinkPreviewScope`, provided by `ZukkoChatView` (null when the option is off: no fetch, domain card as before).
- Card: semantics label "title, domain", min height 48 dp.
