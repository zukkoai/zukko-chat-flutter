import 'package:flutter/material.dart' show CircularProgressIndicator, Icons;
import 'package:flutter/widgets.dart';

/// One page of the image viewer: pinch / pan, double-tap to zoom in and out.
/// [onZoomed] reports whether the image is zoomed in.
class ZoomableImage extends StatefulWidget {
  /// Null shows the error placeholder.
  final ImageProvider? image;
  final Object heroTag;
  final String label;
  final ValueChanged<bool> onZoomed;
  final Color foreground;

  const ZoomableImage({
    super.key,
    required this.image,
    required this.heroTag,
    required this.label,
    required this.onZoomed,
    this.foreground = const Color(0xFFFFFFFF),
  });

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.5;

  /// Above this scale the image counts as zoomed in.
  static const _zoomThreshold = 1.01;

  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(_tick);
  Matrix4Tween? _tween;
  Offset _tapAt = Offset.zero;

  bool get _zoomedIn => _transform.value.getMaxScaleOnAxis() > _zoomThreshold;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() => widget.onZoomed(_zoomedIn));
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _tick() {
    final tween = _tween;
    if (tween != null) _transform.value = tween.evaluate(_anim);
  }

  void _toggleZoom() {
    final target = Matrix4.identity();
    if (!_zoomedIn) {
      const s = _doubleTapScale;
      target
        ..translateByDouble(-_tapAt.dx * (s - 1), -_tapAt.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.stop();
      _transform.value = target;
      return;
    }
    // One listener for the controller's life: a double-tap during a running
    // animation just restarts it from the current matrix.
    _tween = Matrix4Tween(begin: _transform.value, end: target);
    _anim.forward(from: 0);
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
                  ? _Failed(color: widget.foreground)
                  : Image(
                      image: image,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Center(
                              child: CircularProgressIndicator(
                                color: widget.foreground,
                              ),
                            ),
                      errorBuilder: (_, _, _) =>
                          _Failed(color: widget.foreground),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  final Color color;

  const _Failed({required this.color});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.broken_image_outlined,
    size: 48,
    color: color.withValues(alpha: 0.6),
  );
}
