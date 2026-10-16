# README: identity validation (HMAC) warning

## What
A prominent `[!IMPORTANT]` block at the top of "User identity (HMAC)" in README.md: what happens when "Enforce identity validation" is on and `identifierHash` is missing or wrong (screen text, `INVALID_IDENTIFIER_HASH`, the exact ERROR log line), what is needed to generate the hash (inbox HMAC token, exact identifier, openssl), the `printf | openssl dgst` test command, a checklist for the "wrong" case, and the production rule (hash on the backend, token never in the app). Also corrected "Why the hash matters": without a hash someone can impersonate a customer, not read their old history.

## Why
Owner asked for a separate warning so integrators know what to do when the ERROR appears.
