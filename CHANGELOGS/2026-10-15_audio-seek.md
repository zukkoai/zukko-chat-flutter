# Voice messages: seek by tapping or dragging the waveform

## Symptom
A playing voice message could not be moved, e.g. from 0:03 to 0:15.

## Fix
- `AudioPlaybackController.seek(source, fraction)`: jumps within the current message (keeps playing or paused); a message that is not playing yet is loaded and played from that point.
- `AudioPlayerBar`: the waveform is a scrubber (tap to jump, drag to preview and seek on release, RTL aware) and a screen-reader slider (increase / decrease by 10 %).
