import 'package:flutter/widgets.dart';

import '../../l10n/zukko_chat_l10n.dart';
import 'chat_image.dart';
import 'image_viewer.dart';

/// Hero tag of image [index] of message [messageId]. Unique per screen: ids
/// differ per message (a pending message has its local id) and per index.
Object chatImageHeroTag(String messageId, int index) =>
    'zukko-image-$messageId-$index';

/// Wraps an image thumbnail: a [Hero] with [chatImageHeroTag] that opens the
/// full-screen viewer at [index] on tap.
///
/// A tap is handled here and does NOT reach the chat's message tap
/// (`ZukkoChatInteractions.onMessageTap`): opening the picture is the
/// action. Styles pass `enabled: false` for a failed message so its tap still
/// resends, and for images with nothing to show yet.
class ChatImageTap extends StatelessWidget {
  final List<String> urls;
  final int index;
  final String messageId;
  final ZukkoChatL10n l10n;
  final bool enabled;
  final Widget child;

  const ChatImageTap({
    super.key,
    required this.urls,
    required this.index,
    required this.messageId,
    required this.l10n,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hero = Hero(tag: chatImageHeroTag(messageId, index), child: child);
    if (!enabled || chatImageProvider(urls[index]) == null) return hero;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openImageViewer(
          context,
          urls: urls,
          initialIndex: index,
          heroTags: [
            for (var i = 0; i < urls.length; i++)
              chatImageHeroTag(messageId, i),
          ],
          l10n: l10n,
        ),
        child: hero,
      ),
    );
  }
}

/// Opens the full-screen viewer over the current route. [heroTags] has one tag
/// per url; the page of image `i` flies from/to the thumbnail with that tag.
/// With "reduce motion" on, the route does not animate.
Future<void> openImageViewer(
  BuildContext context, {
  required List<String> urls,
  required int initialIndex,
  required List<Object> heroTags,
  required ZukkoChatL10n l10n,
}) {
  assert(urls.length == heroTags.length);
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 250);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => ImageViewer(
        images: [for (final u in urls) chatImageProvider(u)],
        initialIndex: initialIndex,
        heroTags: heroTags,
        l10n: l10n,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
