import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../shared/format.dart';

/// File attachment: icon tile, name and size.
class FileTile extends StatelessWidget {
  final String name;
  final int? size;
  final Color iconFill;
  final Color iconColor;
  final TextStyle nameStyle;
  final TextStyle sizeStyle;
  final double iconRadius;

  const FileTile({
    super.key,
    required this.name,
    required this.iconFill,
    required this.iconColor,
    required this.nameStyle,
    required this.sizeStyle,
    this.size,
    this.iconRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = size;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconFill,
            borderRadius: BorderRadius.circular(iconRadius),
          ),
          child: Icon(
            Icons.insert_drive_file_outlined,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: nameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (bytes != null) Text(formatBytes(bytes), style: sizeStyle),
            ],
          ),
        ),
      ],
    );
  }
}
