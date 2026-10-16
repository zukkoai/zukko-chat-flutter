import 'package:url_launcher/url_launcher.dart';

import '../../../shared/sdk_log.dart';
import '../../../shared/url_policy.dart';

final _linkPattern = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+',
  caseSensitive: false,
);

const _trailingPunctuation = '.,!?:;)]}\'"';

/// A link found in message text: where it is and where it goes.
class TextLink {
  final int start;
  final int end;
  final Uri uri;

  const TextLink(this.start, this.end, this.uri);
}

/// Every http(s) / `www.` link in [text], in order.
List<TextLink> findLinks(String text) {
  final links = <TextLink>[];
  for (final match in _linkPattern.allMatches(text)) {
    var end = match.end;
    while (end > match.start && _trailingPunctuation.contains(text[end - 1])) {
      end--;
    }
    final uri = parseLink(text.substring(match.start, end));
    if (uri != null) links.add(TextLink(match.start, end, uri));
  }
  return links;
}

/// [raw] as an http(s) URI (`www.` gets https), or null.
Uri? parseLink(String raw) {
  final withScheme = raw.toLowerCase().startsWith('www.')
      ? 'https://$raw'
      : raw;
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  return isHttpUrl(uri.toString()) ? uri : null;
}

/// Opens [uri] in the OS browser; only http(s), failures are logged.
Future<void> openExternalLink(Uri uri) async {
  if (!isHttpUrl(uri.toString())) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    sdkLog('could not open link: $e');
  }
}
