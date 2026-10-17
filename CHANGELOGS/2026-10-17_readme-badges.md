# README: logos as fixed-size badges

## Symptom
On the pub.dev package page the Flutter / Chatwoot / Zukko.AI logos at the top of the README rendered huge (full width); on GitHub they looked fine.

## Root cause
The logos were simpleicons SVGs without intrinsic width/height. pub.dev's README CSS ignores the `height="56"` attribute (height auto), so an SVG without its own size stretches to the column width.

## Fix
Replaced them with shields.io "for-the-badge" badges (SVGs with fixed 28 px height): Flutter, Chatwoot and Zukko.AI (Zukko logo embedded from zukko.ai's 32 px favicon). pub.dev shows README changes only with a new package version.
