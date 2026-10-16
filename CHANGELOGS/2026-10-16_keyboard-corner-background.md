# Keyboard corner background matches the chat

## Symptom
Modern keyboards have rounded top corners; through them the chat showed the app's plain white/black instead of the chat background.

## Root cause
`ZukkoChat` built a `Scaffold` without `backgroundColor`. The body shrinks above the keyboard, so the area behind the keyboard was painted with the host theme's `scaffoldBackgroundColor`, while the chat style painted its background only over the body.

## Fix
The `Scaffold` background is now the resolved chat style background (same theme resolution as `ZukkoChatView`). In all three styles the area directly above the keyboard is that background (composer is a floating pill or a transparent bar with a top border), so no per-style property is needed.
