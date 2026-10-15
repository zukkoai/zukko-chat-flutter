# Send photos, files and voice messages; play voice messages

## What
- `ChatwootUpload` (public): a file by path or bytes; content type from the name; 40 MB limit.
- Network: `ChatwootClientService.createMessageWithAttachments` (multipart `content`, `echo_id`, `attachments[]`); repository and `ChatwootClient.sendMessage(attachments:)`. The interceptor replays a clone of a multipart body after a session reset.
- `components/voice_recorder.dart`: real recording (`record`, 16 kHz mono PCM -> WAV), permission handling, hold / slide-to-cancel / 1 s minimum / 5 min maximum; capture is injectable (`VoiceCapture`) for tests.
- `components/audio_playback.dart`: `AudioPlaybackController` (just_audio), one per chat view, one message at a time; `AudioPlayerBar` shows play/pause, progress and the real length.
- `components/attachment_picker.dart`: photo / file sheet and `file_picker`.
- Controller: `sendAttachments` with an immediate local preview (image, gallery, voice, file), queue/resend through an outbox, replaced by the server's version (real urls) when confirmed.
- Options `enableAttachments`, `enableVoiceMessages` (default on). Removed `ChatwootChatInteractions.onAttachmentPressed`, `voiceRecording`, `ChatwootVoiceRecordCallbacks`.
- L10n: `attachImageLabel`, `attachFileLabel`, `playLabel`, `pauseLabel`, `microphoneDeniedText`, `voiceRecordFailedText`, `fileTooLargeText` in all six languages.
- Example: a home screen with three buttons (one per style) instead of the bottom navigation bar; light/dark switch; the demo client "hosts" sent files; iOS/Android microphone and photo permission entries.

## Not verified here
- No Flutter SDK in this environment: run `flutter pub get`, `flutter analyze --fatal-infos`, `flutter test` (package and example). Package versions `record ^6.0.0`, `just_audio ^0.10.0`, `file_picker ^10.0.0` were chosen without pub access.
