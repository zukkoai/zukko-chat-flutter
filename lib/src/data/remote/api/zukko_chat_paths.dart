/// REST paths of the Widget API. `website_token` and the JWT are added by
/// `WidgetAuthInterceptor`, never baked into a path.
abstract final class ZukkoChatPaths {
  /// Query parameter carrying the inbox's website token.
  static const websiteTokenParam = 'website_token';

  /// Header carrying the widget session JWT.
  static const authTokenHeader = 'X-Auth-Token';

  static const _base = '/api/v1/widget';

  static const config = '$_base/config';
  static const contact = '$_base/contact';
  static const setUser = '$_base/contact/set_user';
  static const messages = '$_base/messages';
  static const conversations = '$_base/conversations';
  static const toggleTyping = '$_base/conversations/toggle_typing';
  static const updateLastSeen = '$_base/conversations/update_last_seen';
}
