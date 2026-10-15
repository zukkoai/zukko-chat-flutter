import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

void main() {
  test('reads the inbox settings, applies defaults, drops the secret', () {
    final config = ZukkoChatConfig.fromJson(
      {
        'auth_token': 'JWT',
        'website_name': 'Zukko',
        'widget_color': '#1f93ff',
        'working_hours_enabled': true,
        'allow_messages_after_resolved': 'not a bool',
        'extra': 1,
      },
      {'BRAND_NAME': 'Zukko Chat', 'WIDGET_BRAND_URL': 5},
    );

    expect(config.websiteName, 'Zukko');
    expect(config.widgetColor, '#1f93ff');
    expect(config.workingHoursEnabled, isTrue);
    expect(config.allowMessagesAfterResolved, isTrue); // default
    expect(config.csatSurveyEnabled, isFalse);
    expect(config.brandName, 'Zukko Chat');
    expect(config.brandUrl, isNull); // wrong type
    expect(config.raw.containsKey('auth_token'), isFalse);
    expect(config.raw['extra'], 1);
    expect(() => config.raw['x'] = 1, throwsUnsupportedError);
  });
}
