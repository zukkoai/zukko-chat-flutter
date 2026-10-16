/// Hive type ids of the persisted models. They sit high so they cannot clash
/// with the host app's own Hive types (hive_ce allows 0-223). 200 and 201 are
/// skipped on purpose: `Hive.initFlutter` registers its Color and TimeOfDay
/// adapters there. Never reuse or renumber an id.
const zukkoChatContactHiveTypeId = 210;
const zukkoChatConversationHiveTypeId = 211;
const zukkoChatMessageHiveTypeId = 212;
const zukkoChatUserHiveTypeId = 213;
const zukkoChatEventUserHiveTypeId = 214;
