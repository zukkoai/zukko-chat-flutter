import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/zukko_chat_upload.dart';
import '../../l10n/zukko_chat_l10n.dart';

/// What the attachment button picks.
enum AttachmentSource { image, file }

/// Bottom sheet: photo or file. Null when dismissed.
Future<AttachmentSource?> showAttachmentSourceSheet(
  BuildContext context, {
  required ZukkoChatL10n l10n,
  required Color background,
  required Color foreground,
}) => showModalBottomSheet<AttachmentSource>(
  context: context,
  backgroundColor: background,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AttachmentOption(
          source: AttachmentSource.image,
          icon: Icons.image_outlined,
          label: l10n.attachImageLabel,
          color: foreground,
        ),
        _AttachmentOption(
          source: AttachmentSource.file,
          icon: Icons.insert_drive_file_outlined,
          label: l10n.attachFileLabel,
          color: foreground,
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

class _AttachmentOption extends StatelessWidget {
  final AttachmentSource source;
  final IconData icon;
  final String label;
  final Color color;

  const _AttachmentOption({
    required this.source,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    onTap: () => Navigator.pop(context, source),
  );
}

/// What the user picked: the files the server accepts and how many were left
/// out, by reason: over [ZukkoChatUpload.maxSize], of a type the server
/// rejects, or beyond [ZukkoChatUpload.maxAttachments].
typedef AttachmentPick = ({
  List<ZukkoChatUpload> fitting,
  int tooLarge,
  int badType,
  int overCount,
});

/// Splits [files] into what can be sent and what was left out, and why.
AttachmentPick screenAttachments(List<ZukkoChatUpload> files) {
  final fitting = <ZukkoChatUpload>[];
  var tooLarge = 0, badType = 0, overCount = 0;
  for (final f in files) {
    if (f.isTooLarge) {
      tooLarge++;
    } else if (!f.isTypeAccepted) {
      badType++;
    } else if (fitting.length >= ZukkoChatUpload.maxAttachments) {
      overCount++;
    } else {
      fitting.add(f);
    }
  }
  return (
    fitting: fitting,
    tooLarge: tooLarge,
    badType: badType,
    overCount: overCount,
  );
}

/// The whole attachment flow: source sheet, system picker, limit checks. Empty
/// when the user dismissed either step or [context] went away meanwhile.
Future<AttachmentPick> pickWithSheet(
  BuildContext context, {
  required ZukkoChatL10n l10n,
  required Color background,
  required Color foreground,
}) async {
  const none = (
    fitting: <ZukkoChatUpload>[],
    tooLarge: 0,
    badType: 0,
    overCount: 0,
  );
  final source = await showAttachmentSourceSheet(
    context,
    l10n: l10n,
    background: background,
    foreground: foreground,
  );
  if (source == null) return none;
  final files = await pickAttachments(source);
  return screenAttachments(files);
}

/// Opens the system picker; empty when cancelled.
Future<List<ZukkoChatUpload>> pickAttachments(AttachmentSource source) async {
  final files = await FilePicker.pickFiles(
    type: source == AttachmentSource.image ? FileType.image : FileType.any,
  );
  return [for (final file in files) ?await _toUpload(file)];
}

Future<ZukkoChatUpload?> _toUpload(PlatformFile file) async {
  if (kIsWeb) {
    // The web has no file paths, only bytes. Check the reported size before
    // reading: an oversized placeholder (never sent) lets the view say so.
    final size = await file.length();
    if ((size ?? 0) > ZukkoChatUpload.maxSize) {
      return ZukkoChatUpload.file(name: file.name, path: '', size: size);
    }
    return ZukkoChatUpload.bytes(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }
  final path = file.path;
  return path == null
      ? null
      : ZukkoChatUpload.file(
          name: file.name,
          path: path,
          size: await file.length(),
        );
}
