import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show LinkPreviewData;

import 'chat_image.dart';
import 'link_launcher.dart';

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(openExternalLink(uri)),
        child: Container(
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
