import 'package:flutter/material.dart' show CircularProgressIndicator, Icons;
import 'package:flutter/widgets.dart';

import '../../l10n/chatwoot_l10n.dart';
import 'attachment_preview.dart';

/// Hero tag of image [index] of message [messageId]. Unique per screen: ids
/// differ per message (a pending message has its local id) and per index.
Object chatImageHeroTag(String messageId, int index) =>
    'chatwoot-image-$messageId-$index';

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
Future<void> openImageViewer(
  BuildContext context, {
  required List<String> urls,
  required int initialIndex,
  required List<Object> heroTags,
  required ZukkoChatL10n l10n,
}) {
  assert(urls.length == heroTags.length);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
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

/// Whether a drag of [dy] px at [velocity] px/s should dismiss the viewer.
bool shouldDismissImageViewer(double dy, double velocity) =>
    dy.abs() > 100 || velocity.abs() > 700;

/// Full-screen, swipeable, zoomable images on black. Drag down/up to dismiss
/// (only while not zoomed), pinch or double-tap to zoom.
class ImageViewer extends StatefulWidget {
  /// Null entries (nothing loadable) show the error placeholder.
  final List<ImageProvider?> images;
  final int initialIndex;
  final List<Object> heroTags;
  final ZukkoChatL10n l10n;

  const ImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTags,
    required this.l10n,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  static const _white = Color(0xFFFFFFFF);

  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  int _pointers = 0;
  double _dy = 0;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _spring.addListener(() => setState(() => _dy = _from * _spring.value));
  }

  @override
  void dispose() {
    _spring.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_zoomed || _pointers > 1) return;
    _spring.stop();
    setState(() => _dy += d.delta.dy);
  }

  void _dragEnd(DragEndDetails d) {
    if (_dy == 0) return;
    if (shouldDismissImageViewer(_dy, d.velocity.pixelsPerSecond.dy)) {
      Navigator.of(context).maybePop();
      return;
    }
    _from = _dy;
    _spring.value = 1;
    _spring.animateTo(0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final fade = (1 - _dy.abs() / (height * 0.5)).clamp(0.0, 1.0);
    final count = widget.images.length;
    final l10n = widget.l10n;
    return Listener(
      onPointerDown: (_) => _pointers++,
      onPointerUp: (_) => _pointers--,
      onPointerCancel: (_) => _pointers--,
      child: ColoredBox(
        color: const Color(0xFF000000).withValues(alpha: fade),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              // No recognizer while zoomed: panning the image owns the gesture.
              onVerticalDragUpdate: _zoomed ? null : _dragUpdate,
              onVerticalDragEnd: _zoomed ? null : _dragEnd,
              child: Transform.translate(
                offset: Offset(0, _dy),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: count,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _zoomed = false;
                  }),
                  itemBuilder: (_, i) => _ZoomPage(
                    image: widget.images[i],
                    heroTag: widget.heroTags[i],
                    label: count > 1
                        ? '${l10n.imageLabel} ${i + 1} / $count'
                        : l10n.imageLabel,
                    onZoomed: (z) {
                      if (z != _zoomed) setState(() => _zoomed = z);
                    },
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Opacity(
                opacity: fade,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Semantics(
                        button: true,
                        label: l10n.closeLabel,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.close, color: _white),
                          ),
                        ),
                      ),
                    ),
                    if (count > 1)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ExcludeSemantics(
                            child: Text(
                              '${_index + 1} / $count',
                              style: const TextStyle(
                                color: _white,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomPage extends StatefulWidget {
  final ImageProvider? image;
  final Object heroTag;
  final String label;
  final ValueChanged<bool> onZoomed;

  const _ZoomPage({
    required this.image,
    required this.heroTag,
    required this.label,
    required this.onZoomed,
  });

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage>
    with SingleTickerProviderStateMixin {
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.5;

  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(
      () => widget.onZoomed(_transform.value.getMaxScaleOnAxis() > 1.01),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.01;
    final target = Matrix4.identity();
    if (!zoomedIn) {
      const s = _doubleTapScale;
      target
        ..translateByDouble(-_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    final tween = Matrix4Tween(begin: _transform.value, end: target);
    void tick() => _transform.value = tween.evaluate(_anim);
    _anim
      ..removeListener(tick)
      ..addListener(tick)
      ..forward(from: 0).whenComplete(() => _anim.removeListener(tick));
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    return Semantics(
      image: true,
      label: widget.label,
      child: GestureDetector(
        onDoubleTapDown: (d) => _tapAt = d.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: _maxScale,
          child: Center(
            child: Hero(
              tag: widget.heroTag,
              child: image == null
                  ? const _Failed()
                  : Image(
                      image: image,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                      errorBuilder: (_, _, _) => const _Failed(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.broken_image_outlined,
    size: 48,
    color: Color(0x99FFFFFF),
  );
}
