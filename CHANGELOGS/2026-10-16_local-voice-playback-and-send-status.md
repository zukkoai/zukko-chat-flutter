# Local voice playback and clear send status

## What
- A voice message the user just recorded can be played while it uploads (sending) and after it failed (error).
- Every outgoing message in `sending` state shows a small clock (all 3 styles, text/file/voice/image); the clock has a "Sending" screen-reader label.
- Failed hint now reads "Not sent. Tap to retry" (en; other locales already said not sent + retry). New l10n field `messageSendingLabel` in all 6 locales.

## Why
A dimmed bubble alone looked like a delivered message, and the local recording could not be played back.

## Fix
- `AudioEngine.setFilePath` added; `AudioPlaybackController` loads local files through it (http(s) still `setUrl`, no caching). `canPlay` = http(s) or, off the web, an existing local file.
- When a bubble's source changes (local path -> server URL after upload), `AudioPlayerBar` calls `release(oldSource)`: a playing local note is stopped and its state cleared.
- The play button and waveform consume their own taps, so playing on a failed bubble does not resend; tapping elsewhere still resends.
- Shared `SendingMark` in `components/message_chrome.dart`; `MessageSlot.sendingLabel`.
- Goldens `*_messages.png` (6) regenerated: the sample "Sending..." message now has the clock.
