# Branding footer is always shown

## What
Removed the public option `ZukkoChatOptions.showBranding`. The "Powered by zukko.ai" footer is now always rendered.

## Why
The footer is the Zukko brand; host apps must not be able to turn it off.

## Fix
Dropped the field, constructor parameter, `==` and `hashCode` entries from `zukko_chat_options.dart`; `zukko_chat_view.dart` always calls `style.buildFooter`. The test that checked hiding now checks the footer is shown with default options.
