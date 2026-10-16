# Voice message shows its real length

## Symptom
After sending a voice message the bubble showed 0:00; after pressing play it jumped to 5:00 although the recording was a few seconds long.

## Root cause
- The server's attachment JSON has no audio length, and `_confirmEcho` replaced the local bubble (which knew the recorded length) with the server version whose length is `Duration.zero`.
- The bubble took the length (and the progress scale) only from the player, so it was 0:00 until play. The 5:00 comes from the player, not from the file: the SDK's WAV header is correct (`wavFromPcm16`, data size = PCM length), so a 5:00 value is the platform player guessing the length of the streamed proxy URL. Not reproducible without a device.

## Fix
- `zukko_chat_controller.dart`: keep the echo's recorded length when the server message replaces it.
- `audio_playback.dart` / `audio_player.dart`: `prime()` registers the known length per source; for a remote message without a length the first bytes of the WAV are read (Range request) and parsed by `wavDuration` (`shared/wav.dart`). A known length wins over the player's and also scales the progress.
