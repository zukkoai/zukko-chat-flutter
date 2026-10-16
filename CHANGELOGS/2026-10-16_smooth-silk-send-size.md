# Smooth Silk: send button matches the attach button

## What
The Smooth Silk send button is now a 48 dp circle (`SmoothSilkMetrics.buttonSize`), the same as the "+" attach circle, and sits level with it (bottom padding = the pill's inner padding).

## Why
Owner: the send circle (54 dp, the full composer height) looked too big next to the "+" circle.

## Fix
`smooth_silk_composer.dart`: `ComposerSendButton(size: buttonSize)` wrapped in `Padding(bottom: pillPadding.bottom)`. Goldens `smoothSilk_{light,dark}_chrome.png` updated.
