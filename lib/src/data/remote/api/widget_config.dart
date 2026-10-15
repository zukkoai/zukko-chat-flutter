/// Branding and behaviour of the web widget inbox, from `POST /config`
/// (`website_channel_config` + `global_config`). Held in memory only: the
/// server owner can change it at any time.
class WidgetConfig {
  final String? websiteName;
  final String? welcomeTitle;
  final String? welcomeTagline;

  /// Hex colour such as `#1f93ff`.
  final String? widgetColor;
  final String? avatarUrl;
  final String? launcherIconUrl;
  final String? replyTime;
  final String? locale;
  final String? outOfOfficeMessage;
  final bool workingHoursEnabled;
  final bool allowMessagesAfterResolved;
  final bool csatSurveyEnabled;
  final bool preChatFormEnabled;
  final bool disableBranding;

  /// `default`, `hold_to_record` or `hold_to_record_mobile_only`.
  final String? audioRecordingMode;
  final String? brandName;
  final String? brandUrl;

  /// The untouched `website_channel_config` for fields not modelled here.
  final Map<String, dynamic> raw;

  const WidgetConfig({
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
    this.brandName,
    this.brandUrl,
    this.raw = const {},
  });

  /// [channel] is `website_channel_config`, [global] is `global_config`. The
  /// `auth_token` (a secret) is dropped from [raw].
  factory WidgetConfig.fromJson(
    Map<String, dynamic> channel, [
    Map<String, dynamic>? global,
  ]) {
    String? str(String k) => channel[k] is String ? channel[k] as String : null;
    bool flag(String k, bool fallback) =>
        channel[k] is bool ? channel[k] as bool : fallback;
    return WidgetConfig(
      websiteName: str('website_name'),
      welcomeTitle: str('welcome_title'),
      welcomeTagline: str('welcome_tagline'),
      widgetColor: str('widget_color'),
      avatarUrl: str('avatar_url'),
      launcherIconUrl: str('launcher_icon_url'),
      replyTime: str('reply_time'),
      locale: str('locale'),
      outOfOfficeMessage: str('out_of_office_message'),
      workingHoursEnabled: flag('working_hours_enabled', false),
      allowMessagesAfterResolved: flag('allow_messages_after_resolved', true),
      csatSurveyEnabled: flag('csat_survey_enabled', false),
      preChatFormEnabled: flag('pre_chat_form_enabled', false),
      disableBranding: flag('disable_branding', false),
      audioRecordingMode: str('audio_recording_mode'),
      brandName: global?['BRAND_NAME'] is String
          ? global!['BRAND_NAME'] as String
          : null,
      brandUrl: global?['WIDGET_BRAND_URL'] is String
          ? global!['WIDGET_BRAND_URL'] as String
          : null,
      raw: Map.unmodifiable({...channel}..remove('auth_token')),
    );
  }
}
