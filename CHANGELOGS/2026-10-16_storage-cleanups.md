# Storage cleanups: conversation copies, typed attachments, reinstall/restore, Hive type ids

## #19 Conversation box no longer embeds messages and contact

- What: the stored conversation holds only `id`, `inboxId`, `status`.
- Why: embedded copies duplicated the messages/contact boxes and went stale.
- Fix: already removed in the model (Hive fields 2 and 3 stay reserved, never written). Added tests that a saved conversation round-trips and that an old record carrying fields 2 and 3 still loads.

## #20 Typed `attachments`, `contentAttributes`, `customAttributes`

- What: `ZukkoChatMessage.attachments` is `List<ZukkoChatAttachment>?`, `contentAttributes` and `ZukkoChatUser.customAttributes` are `Map<String, dynamic>?`. `ZukkoChatAttachment` (exported) mirrors the server's `push_event_data` (id, message_id, file_type, account_id, extension, data_url, thumb_url, external_url, file_size, width, height).
- Why: `dynamic` pushed type checks into every reader.
- Fix: tolerant parsing (wrong type -> null field, non-map element skipped, non-list -> null). `ZukkoChatMessageAdapter` is now hand-written (same type id and field indices) so attachments stay plain JSON maps in Hive and old records load. The chat mapper reads the typed model.

## #23 Reinstall / restore between Keychain and Hive files

- Symptom: iOS keeps Keychain entries after uninstall while Hive files are deleted; a restore can bring back Hive files without the `this_device` key.
- Behaviour: (a) key present, boxes missing: the key is reused and empty boxes are created, nothing to fix. (b) boxes present, key missing or different: a new key is generated, the old boxes fail to decrypt.
- Fix: `_openEncrypted` now treats any failure to open a box (not only `HiveError`) as an unreadable cache: only that SDK box is deleted and recreated, `STORAGE_FAILED` is reported once. Host app boxes are untouched. No first-run marker: it solves no case beyond these. The JWT stays in the encrypted contact box.

## Hive type ids 210-214

- What: contact 210, conversation 211, message 212, user 213, event user 214 (were 0-4). Box names, secure-storage key and field indices are unchanged.
- Why: avoid clashing with the host app's Hive types.
- Fix: 200 and 201 are skipped on purpose because `Hive.initFlutter` registers Color/TimeOfDay adapters there (with 200-204 every open failed with "typeId 200 already used"). Boxes written with the old ids cannot be read; the generic recovery above wipes them and starts fresh. The host clash guard in `hive_adapters.dart` stays, now for 210-214.
