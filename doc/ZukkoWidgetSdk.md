# Zukko Widget API migration (chatwoot_sdk)

Single source of truth for moving this SDK from the Chatwoot Public Client API to the Zukko chat server's Widget API.
Verified from server code on 2026-10-13. Server repo: `/Users/alisherakhmedov/Desktop/Work/microservices/chat` (Rails Chatwoot fork); all server paths below are relative to it.
Plan doc (Uzbek, partially wrong): `/Users/alisherakhmedov/Desktop/Work/microservices/chat/alisher/plans/flutter_sdk/flutter-sdk-guide.md`; design reference `image.png` in the same folder (purple chat list + conversation screen).

## 1. Goal

Native Flutter client over the Widget API, with the same inbox and features as the website widget: config/branding, pre-chat form, HMAC `set_user`, CSAT, working hours.

Current SDK uses the Public Client API `/public/api/v1/inboxes/:identifier/contacts/:source_id/...`: needs an API-channel inbox, identity = `source_id` in the URL, no JWT.

Both APIs use the same `RoomChannel` + `pubsub_token`. Inbox types differ: `website_token` (WebWidget) vs API channel identifier.

## 2. Server contract (Widget API)

Routes (`config/routes.rb:1071-1099`, prefix `/api/v1/widget`):

| Method | Path | Notes |
|---|---|---|
| POST | `/config` | configs#create |
| POST | `/direct_uploads` | ActiveStorage DirectUploads subclass |
| GET | `/campaigns` | |
| POST | `/events` | |
| GET, POST | `/messages` | |
| PATCH, PUT | `/messages/:id` | |
| GET, POST | `/conversations` | |
| POST | `/conversations/{destroy_custom_attributes,set_custom_attributes,update_last_seen,toggle_typing,transcript}` | |
| GET | `/conversations/toggle_status` | |
| GET, PATCH, PUT | `/contact` | |
| POST | `/contact/destroy_custom_attributes` | |
| PATCH | `/contact/set_user` | |
| GET | `/inbox_members` | |
| POST | `/labels` | |
| DELETE | `/labels/:id` | `:id` = label title |
| POST | `/integrations/dyte/add_participant_to_meeting` | |

No conversation-by-id routes: the widget always acts on `conversations.last`.

### Auth

- `website_token` read from params (query or body): `app/controllers/concerns/website_token_helper.rb:6-7`. Unknown token -> 404 `{"error":"Resource could not be found"}`. Account inactive -> 401 'Account is not available'; account discarded -> 410; inbox discarded -> 410 'Inbox is no longer available'.
- `X-Auth-Token` header = JWT HS256 signed with `secret_key_base` (`app/services/widget/token_service.rb`), payload `{source_id, inbox_id}`, NO `exp` -> never expires. Decode errors -> `{}`.
- Missing/invalid/stale JWT on non-config endpoints -> **404** (not 401); no contact created (`website_token_helper.rb:15-23`).
- `inbox_members` and `campaigns` need only `website_token`.

### POST /config

`app/controllers/api/v1/widget/configs_controller.rb`. Without a valid `X-Auth-Token` it creates a new Contact+ContactInbox; with a valid token it reuses the contact. Mints a NEW JWT on every call (lines 30-33). `pubsub_token` only comes from this response.

Response (`app/views/api/v1/widget/configs/create.json.jbuilder`):
- `website_channel_config{allow_messages_after_resolved, api_host, auth_token, avatar_url, csat_survey_enabled, disable_branding, enabled_features, enabled_languages, locale, out_of_office_message, audio_recording_mode (Zukko: default|hold_to_record|hold_to_record_mobile_only), portal, pre_chat_form_enabled, pre_chat_form_options, reply_time, timezone, utc_off_set, website_name, website_token, welcome_tagline, welcome_title, widget_color, launcher_icon_url (Zukko), working_hours, working_hours_enabled}`
- `contact{email, id, identifier, name, phone_number, pubsub_token}` (name/email may be null)
- `global_config{LOGO_THUMBNAIL, BRAND_NAME, WIDGET_BRAND_URL}`

Recommended session flow: always call `/config` on start, sending the saved `X-Auth-Token` if any; store returned `auth_token` + `pubsub_token`; on any 404 from a widget call, drop the token and re-run `/config`.

### Conversations

- POST `/conversations`: permitted `contact[name,email,phone_number]`, `message[content,referer_url,timestamp,echo_id]`, `custom_attributes{}`. The `message` key is REQUIRED (`base_controller.rb:42` reads `message[:referer_url]`, else 500). Runs ContactIdentifyAction (can merge contacts by email/phone). ALWAYS creates a new conversation. Response: `{id (display_id), inbox_id, contact_last_seen_at(int), status, messages[], custom_attributes, contact}`.
- GET `/conversations`: single object `{id, inbox_id, contact_last_seen_at, status}` of the last conversation, or `{}` — not a list.
- Current conversation = contact_inbox conversations `.last` (or all HMAC-verified contact_inboxes' conversations): `base_controller.rb:10-21`.
- `update_last_seen` POST -> empty 200.
- `toggle_typing` POST `typing_status=on|off` -> empty 200; 404 if no conversation.
- `toggle_status` GET -> resolves the conversation; 403 unless widget `end_conversation?`; 404 if none.
- `transcript` POST emails if the contact has an email.
- `set_custom_attributes` replaces the whole hash; `destroy_custom_attributes` takes the `custom_attribute` key.

### Messages

- GET `/messages`, params `before`/`after` = message ids (`finders/message_finder.rb:23-48`): none -> latest 20; `before=X` -> 20 with id<X; `after=X` -> up to 100 with id>X; both -> range up to 1000. Always ascending (oldest first); private + activity messages filtered.
  Response `{payload:[{id, content, message_type(int: 0 incoming,1 outgoing,2 activity,3 template), content_type, content_attributes, created_at(int), conversation_id(display_id), attachments?, sender?}], meta:{contact_last_seen_at}}` — NOT a bare list.
- POST `/messages`: `message[content,referer_url,timestamp,echo_id,reply_to]`, `message[attachments][]`, `contact[name,email]`. Auto-creates a conversation if none (needs `message[referer_url]` and `message[timestamp]` keys present — send `referer_url` even if empty). `reply_to` kept in `content_attributes.in_reply_to` only if that message is in the conversation (Zukko, `base_controller.rb:90-95`).
  Response flat `{id, content, inbox_id, conversation_id, message_type, created_at, private, source_id, content_attributes, attachments?, sender?}` (no `content_type`).
- PATCH `/messages/:id`: input_email form (`contact[email]`) or `message[submitted_values][name,title,value,csat_survey_response{feedback_message,rating}]` (CSAT). Scoped to inbox, not contact (upstream behaviour).

### Attachments

- Multipart `message[attachments][]` (file part or ActiveStorage signed_id string).
- Direct upload flow (`app/javascript/widget/components/ChatAttachment.vue:72-95`): POST `/direct_uploads?website_token=` with `X-Auth-Token` and `{blob:{filename,content_type,byte_size,checksum}}` -> PUT bytes to returned url+headers -> send `signed_id` in `message[attachments][]`.
- Caveat: the signed_id path doesn't set `file_type` (DB default image) — possible mislabel, UNVERIFIED.
- Limits (`models/attachment.rb:172-190`): 40 MB; image/*, video/*, audio/*, csv, txt, rtf, json, pdf, zip, 7z, rar, tar, MS Office, ODT.
- Attachment JSON: `{id, message_id, file_type, account_id, extension, data_url (301 redirect), thumb_url, external_url, file_size, width, height}`.

### Contact

- PATCH `/contact/set_user` (`contacts_controller.rb:12-25`): params `identifier, identifier_hash, email, name, avatar_url, phone_number, custom_attributes{}, additional_attributes{}`.
  - HMAC: `identifier_hash` = hex HMAC-SHA256(`web_widget.hmac_token`, identifier); required if inbox `hmac_mandatory`; mismatch -> 401 'HMAC failed: Invalid Identifier Hash Provided'; success sets `contact_inbox.hmac_verified`.
  - If the current contact already has a DIFFERENT identifier -> new Contact+ContactInbox and a new JWT returned as `widget_auth_token`. SDK must swap the token and call `/config` again to get the new `pubsub_token` (not in the set_user response).
  - If the identifier belongs to another existing contact -> merged (ContactIdentifyAction / ContactMergeAction).
  - `additional_attributes` filtered via `Contacts::ServerOwnedAttributes` (Zukko).
  - Response `{id, has_email, has_name, has_phone_number, widget_auth_token?}`.
- GET `/contact` -> `{id, has_email, has_name, has_phone_number, identifier}`.
- PATCH `/contact`: same params, no HMAC.

## 3. Realtime (ActionCable)

- `wss://host/cable`; no connection auth, no Origin check.
- Subscribe identifier `{"channel":"RoomChannel","pubsub_token":"<token>"}` (omit `user_id`/`account_id` for contacts); unknown token fails the subscription (`app/channels/room_channel.rb`).
- Client must send the `update_presence` action every 20 s (web widget `PRESENCE_INTERVAL=20000`) or the contact shows offline.
- Frames: `welcome`, `ping`, `confirm_subscription`, `reject_subscription`, and `{identifier, message:{event, data}}`.
- Events a contact receives (web widget map `app/javascript/widget/helpers/actionCable.js:15-26`):
  - `message.created`: also echoes the contact's own messages -> dedupe by `echo_id`; private/activity skipped; payload = `Message#push_event_data` incl. echo_id, attachments, sender, conversation{...}.
  - `message.updated` (+`previous_changes`).
  - `conversation.typing_on/off` (`{conversation, user, is_private}`): ignore `is_private`; own typing not echoed; server never auto-clears -> client clears after 30 s.
  - `conversation.status_changed` / `conversation.created` / `conversation.updated` (Conversations::EventDataPresenter payload, `data.status`).
  - `presence.update` (`{account_id, users:<available agents>}`).
  - `contact.merged` (web widget reads `data.pubsub_token`; server delivery to contacts UNVERIFIED).
- HMAC-verified contacts get broadcasts on every verified contact_inbox token (multi-device).
- After reconnect refetch with `GET /messages?after=<last id>`.

## 4. Plan doc corrections

- `/config` must also be called on resume (with the saved token) — the plan skips it.
- Auth failures are 404, not 401; the JWT never expires.
- `GET /messages` returns `{payload, meta}`; pagination is by message id (`before`/`after`).
- `POST /messages` needs the `referer_url` key.
- `POST /conversations` always creates a new conversation; `GET /conversations` is one object.
- WS needs `update_presence` every 20 s, welcome/confirm/reject handling, reconnect refetch, echo dedupe, typing timeout, `conversation.created/updated` (`contact.merged` goes to agents only).
- `toggle_status` is gated by the `end_conversation` flag.
- Plan omits: `set_user`/HMAC/token swap, attachments, CSAT, Dyte route, the Public Client API, and `dev_docs/mobile_web_widget_integration.ru.md` (existing WebView guide).

## 5. Current SDK vs target (gap analysis)

Status 2026-10-15: the SDK speaks the Widget API (see `CHANGELOGS/2026-10-15_widget-api-migration.md`).

**Done**
- `WidgetSession` (`/config` with the saved JWT, `set_user`, second `/config` on a token swap, `GET /contact` check after `set_user`), fail-closed HMAC 401, 404 revalidation + replay in `WidgetAuthInterceptor`, rate limit (3 per minute, `SESSION_EXPIRED`); `website_token` + `X-Auth-Token` on every call.
- JWT in the encrypted contact box (`authToken`, `@HiveField(5)`); `phoneNumber`; `clientInstanceKey` uses `websiteToken`; no logging of tokens, bodies or URLs with secrets (`LogInterceptor` banned by a test).
- Messages: `{payload, meta}`, `before`/`after`, send body with `referer_url`/`timestamp`/`echo_id`/`reply_to`, multipart `message[attachments][]` with size/type validation (direct upload dropped), `toggle_typing`, `update_last_seen` (UI wired: debounce 3 s, seen on open/incoming).
- Realtime: `conversation.created/updated/status_changed` (stored `{id, inboxId, status}`, `onConversationUpdated`), agent attachments, `after=` refetch after a reconnect, rejected/silent subscription -> one rate-limited session refresh, then closed + `onError`. `contact.merged` is not sent to contacts (agents only): not implemented on purpose.
- Resolved conversation: kept (match the web widget), `onConversationResolved` once; a session reset clears the UI and refetches.
- Tests: loopback server speaks the Widget routes and `/cable` (`test/utils/fake_chat_server.dart`), end-to-end test in `test/core/widget_end_to_end_test.dart`.

**Remaining** (tracked in `TODO.md`)
- Live-server checks: dead pubsub token behaviour (silence vs `reject_subscription`), `set_user` merge (which contact/pubsub token survives).
- Out of scope in v1: CSAT (`PATCH /messages/:id`), pre-chat form, working hours / out-of-office UI, `toggle_status` (end conversation), Dyte, pagination UI (`before` is supported by the service only), `allow_messages_after_resolved` enforcement (`client.config` exposes it).

**UI vs design image**
- Theme: `ChatwootChatTheme` (brightness, font, accent/background overrides) feeding three chat styles (`ChatwootChatStyle`: smoothSilk, minimalClean, threadFeed; light and dark).
- Missing: chat list screen (the Widget API has one conversation per contact), custom header with call buttons.

## 6. Owner requirements (decided 2026-10-13)

- Amount of code change is irrelevant — rewrite whatever is needed. Priority: correct, optimal, clean.
- Must work fully and efficiently with the Zukko chat server (`/Users/alisherakhmedov/Desktop/Work/microservices/chat`) — Widget API is the target; no need to preserve the Public Client API or the current public SDK signatures for compatibility's sake.
- UI: SDK must offer 2–3 selectable chat UI styles (design reference `image.png` next to the plan is one inspiration).
- No implementation until the owner explicitly says to start.

Still to settle during design (choose the cleanest option, then confirm with owner): storage (current hive_ce vs alternatives), model codegen style, attachments/voice in v1, handling of old Hive data (clean start acceptable), mapping the design's chat list onto the single-conversation Widget API.
