# Voice recording state follows the new design

## What
The composer's recording state is restyled per style (Smooth Silk, Minimal Clean, Thread Feed): blinking red dot, mm:ss timer, live level bars, a "slide to cancel" hint with a nudging chevron, and a larger microphone with pulsing halo rings (two rings in Smooth Silk, one elsewhere). New `voice_recording_view.dart`; per-style sizes live in the `*_metrics.dart` files.

## Why
The design (Biriktirish menyusi va ovoz yozish) specifies a distinct recording layout; the old state was a plain dot, timer and text in the idle composer.

## Fix
- The level bars are driven by the real microphone: `VoiceRecorderController.level` is computed from the recorded PCM chunks (no new package or permission).
- The mic keeps its running press while it moves to the recording layout (GlobalKey in `ComposerHandle.micKey`).
- Reduced motion (`MediaQuery.disableAnimations`) turns off the blink, nudge, halo and bar motion; all controllers are disposed with the widgets.
- Texts come from existing l10n strings only. Tests: `test/ui/chat/styles/voice_recording_test.dart` with new recording goldens.
