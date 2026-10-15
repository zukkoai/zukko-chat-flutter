import 'package:flutter/material.dart' show Icons, Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../l10n/zukko_chat_l10n.dart';
import 'zoomable_image.dart';

/// Drag distance (px) past which the viewer is dismissed.
const _dismissDistance = 100.0;

/// Fling speed (px/s) past which the viewer is dismissed.
const _dismissVelocity = 700.0;

/// Whether a drag of [dy] px at [velocity] px/s should dismiss the viewer.
bool shouldDismissImageViewer(double dy, double velocity) =>
    dy.abs() > _dismissDistance || velocity.abs() > _dismissVelocity;

/// Full-screen, swipeable, zoomable images on [background]. Drag down/up to
/// dismiss (only while not zoomed), pinch or double-tap to zoom.
class ImageViewer extends StatefulWidget {
  /// Null entries (nothing loadable) show the error placeholder.
  final List<ImageProvider?> images;
  final int initialIndex;
  final List<Object> heroTags;
  final ZukkoChatL10n l10n;

  /// A lightbox is dark by default, whatever the chat theme.
  final Color background;
  final Color foreground;

  const ImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTags,
    required this.l10n,
    this.background = const Color(0xFF000000),
    this.foreground = const Color(0xFFFFFFFF),
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  /// Fraction of the screen height at which the background is fully faded.
  static const _fadeFraction = 0.5;

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
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dy = 0);
      return;
    }
    _from = _dy;
    _spring.value = 1;
    _spring.animateTo(0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final fade = (1 - _dy.abs() / (height * _fadeFraction)).clamp(0.0, 1.0);
    final count = widget.images.length;
    final l10n = widget.l10n;
    final foreground = widget.foreground;
    // Overlay routes have no Material: it supplies the text style and ink.
    return Material(
      type: MaterialType.transparency,
      child: Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        onPointerCancel: (_) => _pointers--,
        child: ColoredBox(
          color: widget.background.withValues(alpha: fade),
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
                    itemBuilder: (_, i) => ZoomableImage(
                      image: widget.images[i],
                      heroTag: widget.heroTags[i],
                      foreground: foreground,
                      label: count > 1
                          ? l10n.imageIndex(i + 1, count)
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
                        alignment: AlignmentDirectional.topStart,
                        child: Semantics(
                          button: true,
                          label: l10n.closeLabel,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).maybePop(),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.close, color: foreground),
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
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 16,
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
      ),
    );
  }
}
