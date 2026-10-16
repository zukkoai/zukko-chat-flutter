import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show LinkPreviewData;

import 'chat_image.dart';
import 'link_launcher.dart';
import 'link_preview_service.dart';

/// Colors and text of a [LinkPreviewCard].
@immutable
class LinkPreviewLook {
  final Color fill;
  final Color? border;
  final Color thumbnailFill;
  final Color iconColor;
  final TextStyle domainStyle;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final double radius;

  const LinkPreviewLook({
    required this.fill,
    required this.thumbnailFill,
    required this.iconColor,
    required this.domainStyle,
    required this.titleStyle,
    required this.descriptionStyle,
    this.border,
    this.radius = 14,
  });
}

/// Card for the first link of a message. Uses [data] when the server sent
/// preview metadata, otherwise shows the domain and the address (nothing is
/// fetched). Tapping opens the link.
class LinkPreviewCard extends StatelessWidget {
  final Uri uri;
  final LinkPreviewData? data;
  final LinkPreviewLook look;

  /// [Axis.vertical]: image on top; [Axis.horizontal]: thumbnail on the side.
  final Axis direction;

  const LinkPreviewCard({
    super.key,
    required this.uri,
    required this.look,
    this.data,
    this.direction = Axis.vertical,
  });

  String get _domain =>
      uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;

  @override
  Widget build(BuildContext context) {
    final title = data?.title;
    final description = data?.description ?? (title == null ? '$uri' : null);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_domain, style: look.domainStyle, maxLines: 1),
        if (title != null)
          Text(
            title,
            style: look.titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (description != null)
          Text(
            description,
            style: look.descriptionStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
    final image = data?.image?.url;
    final Widget body = switch (direction) {
      Axis.vertical => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null)
            ChatImage(
              url: image,
              height: 120,
              placeholderColor: look.thumbnailFill,
              iconColor: look.iconColor,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: text,
          ),
        ],
      ),
      Axis.horizontal => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(look.radius - 6),
              child: SizedBox.square(
                dimension: 56,
                child: image != null
                    ? ChatImage(
                        url: image,
                        placeholderColor: look.thumbnailFill,
                        iconColor: look.iconColor,
                      )
                    : ColoredBox(
                        color: look.thumbnailFill,
                        child: Icon(
                          Icons.link_rounded,
                          size: 22,
                          color: look.iconColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: text),
          ],
        ),
      ),
    };
    final border = look.border;
    return Semantics(
      link: true,
      label: title == null ? _domain : '$title, $_domain',
      excludeSemantics: true,
      onTap: () => unawaited(openExternalLink(uri)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(openExternalLink(uri)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: look.fill,
            borderRadius: BorderRadius.circular(look.radius),
            border: border == null ? null : Border.all(color: border),
          ),
          child: body,
        ),
      ),
    );
  }
}

/// [LinkPreviewCard] that fetches its preview lazily, when first built, through
/// the ambient [LinkPreviewScope] (no scope service: no fetch). [data] is used
/// until the fetch resolves, and when it fails.
class LoadedLinkPreviewCard extends StatefulWidget {
  final Uri uri;
  final LinkPreviewData? data;
  final LinkPreviewLook look;
  final Axis direction;

  const LoadedLinkPreviewCard({
    super.key,
    required this.uri,
    required this.look,
    this.data,
    this.direction = Axis.vertical,
  });

  @override
  State<LoadedLinkPreviewCard> createState() => _LoadedLinkPreviewCardState();
}

class _LoadedLinkPreviewCardState extends State<LoadedLinkPreviewCard> {
  LinkPreviewService? _service;
  LinkPreviewData? _fetched;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = LinkPreviewScope.maybeOf(context);
    if (service != _service) {
      _service = service;
      _load();
    }
  }

  @override
  void didUpdateWidget(LoadedLinkPreviewCard old) {
    super.didUpdateWidget(old);
    if (old.uri != widget.uri) _load();
  }

  void _load() {
    final service = _service;
    final uri = widget.uri;
    _fetched = null;
    if (service == null || widget.data != null) return;
    if (service.isCached(uri)) {
      _fetched = service.cached(uri);
      return;
    }
    unawaited(
      service.load(uri).then((data) {
        if (mounted && widget.uri == uri && _service == service) {
          setState(() => _fetched = data);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => LinkPreviewCard(
    uri: widget.uri,
    data: widget.data ?? _fetched,
    look: widget.look,
    direction: widget.direction,
  );
}
