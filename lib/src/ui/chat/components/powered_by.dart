import 'dart:async';

import 'package:flutter/widgets.dart';

import 'link_launcher.dart';

const _brandName = 'zukko.ai';
final _brandUri = Uri.parse('https://zukko.ai');

/// "Powered by zukko.ai": [prefix] in [style], the brand as a link in
/// [linkColor].
class PoweredBy extends StatelessWidget {
  final String prefix;
  final TextStyle style;
  final Color linkColor;

  const PoweredBy({
    super.key,
    required this.prefix,
    required this.style,
    required this.linkColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(prefix, style: style),
      Semantics(
        link: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(openExternalLink(_brandUri)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              _brandName,
              style: style.copyWith(
                color: linkColor,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
