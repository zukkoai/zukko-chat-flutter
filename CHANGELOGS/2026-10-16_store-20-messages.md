# Device stores only the newest 20 messages

## What
`PersistedZukkoChatMessagesDao.maxStored` is now 20 (was 500). After every save the oldest messages beyond the newest 20 are deleted from the device.

## Why
On open the SDK shows only the newest page (20) from cache; older pages are fetched from the server on scroll and are memory-only. The other 480 stored messages were never used.
