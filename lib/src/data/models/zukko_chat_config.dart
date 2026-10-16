/// Branding and behaviour of the web widget inbox, read from the server when
/// the session starts (`POST /config`). Available as `ZukkoChatClient.config`
/// once the session is established. Held in memory only: the server owner can
/// change it at any time.
///
/// Every field mirrors a setting of the inbox in the Zukko Chat admin; a field
/// is null (or its documented default) when the server did not send it.
///
/// {@category FlutterClientSdk}
class ZukkoChatConfig {
  /// Display name of the website / inbox.
  final String? websiteName;

  /// Heading the widget greets visitors with.
  final String? welcomeTitle;

  /// Line under [welcomeTitle].
  final String? welcomeTagline;

  /// Accent colour as hex, such as `#1f93ff`.
  final String? widgetColor;

  /// Avatar of the inbox.
  final String? avatarUrl;

  /// Icon of the web widget's launcher bubble.
  final String? launcherIconUrl;

  /// When agents usually answer (the server's `reply_time` setting, for
  /// example `in_a_few_minutes`).
  final String? replyTime;

  /// Default locale of the inbox, such as `en`.
  final String? locale;

  /// Message to show outside working hours.
  final String? outOfOfficeMessage;

  /// Whether the inbox has working hours; outside them [outOfOfficeMessage]
  /// applies. Defaults to false.
  final bool workingHoursEnabled;

  /// Whether the visitor may write again after an agent resolved the
  /// conversation (a new conversation is then opened). Defaults to true.
  final bool allowMessagesAfterResolved;

  /// Whether a satisfaction survey is sent when a conversation is resolved.
  /// Defaults to false.
  final bool csatSurveyEnabled;

  /// Whether the inbox asks for contact details before the first message.
  /// Defaults to false.
  final bool preChatFormEnabled;

  /// Whether the "powered by" branding must be hidden. Defaults to false.
  final bool disableBranding;

  /// How voice messages are recorded: `default`, `hold_to_record` or
  /// `hold_to_record_mobile_only`.
  final String? audioRecordingMode;

  /// Whether voice messages are on, from `audio_messaging_enabled`. Only an
  /// explicit `false` turns it off; a missing or non-bool value keeps it on
  /// (old backends). The backend must send it: in
  /// `widget/configs/create.json.jbuilder`,
  /// `json.audio_messaging_enabled @web_widget.inbox.account.feature_enabled?('web_widget_audio_messaging')`.
  final bool audioMessagesEnabled;

  /// Brand name from the server's global config (for the "powered by" line).
  final String? brandName;

  /// Brand link from the server's global config.
  final String? brandUrl;

  /// The untouched `website_channel_config` for fields not modelled here
  /// (the secret `auth_token` is removed).
  final Map<String, dynamic> raw;

  const ZukkoChatConfig({
    this.websiteName,
    this.welcomeTitle,
    this.welcomeTagline,
    this.widgetColor,
    this.avatarUrl,
    this.launcherIconUrl,
    this.replyTime,
    this.locale,
    this.outOfOfficeMessage,
    this.workingHoursEnabled = false,
    this.allowMessagesAfterResolved = true,
    this.csatSurveyEnabled = false,
    this.preChatFormEnabled = false,
    this.disableBranding = false,
    this.audioRecordingMode,
    this.audioMessagesEnabled = true,
    this.brandName,
    this.brandUrl,
    this.raw = const {},
  });

  /// [channel] is `website_channel_config`, [global] is `global_config`. The
  /// `auth_token` (a secret) is dropped from [raw].
  factory ZukkoChatConfig.fromJson(
    Map<String, dynamic> channel, [
    Map<String, dynamic>? global,
  ]) {
    String? str(Map<String, dynamic>? m, String k) =>
        m?[k] is String ? m![k] as String : null;
    bool flag(String k, bool fallback) =>
        channel[k] is bool ? channel[k] as bool : fallback;
    return ZukkoChatConfig(
      websiteName: str(channel, 'website_name'),
      welcomeTitle: str(channel, 'welcome_title'),
      welcomeTagline: str(channel, 'welcome_tagline'),
      widgetColor: str(channel, 'widget_color'),
      avatarUrl: str(channel, 'avatar_url'),
      launcherIconUrl: str(channel, 'launcher_icon_url'),
      replyTime: str(channel, 'reply_time'),
      locale: str(channel, 'locale'),
      outOfOfficeMessage: str(channel, 'out_of_office_message'),
      workingHoursEnabled: flag('working_hours_enabled', false),
      allowMessagesAfterResolved: flag('allow_messages_after_resolved', true),
      csatSurveyEnabled: flag('csat_survey_enabled', false),
      preChatFormEnabled: flag('pre_chat_form_enabled', false),
      disableBranding: flag('disable_branding', false),
      audioRecordingMode: str(channel, 'audio_recording_mode'),
      audioMessagesEnabled: flag('audio_messaging_enabled', true),
      brandName: str(global, 'BRAND_NAME'),
      brandUrl: str(global, 'WIDGET_BRAND_URL'),
      raw: Map.unmodifiable({...channel}..remove('auth_token')),
    );
  }
}
