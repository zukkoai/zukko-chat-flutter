import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/chatwoot_upload.dart';
import '../../l10n/chatwoot_l10n.dart';

/// What the attachment button picks.
enum AttachmentSource { image, file }

/// Bottom sheet: photo or file. Null when dismissed.
Future<AttachmentSource?> showAttachmentSourceSheet(
  BuildContext context, {
  required ChatwootL10n l10n,
  required Color background,
  required Color foreground,
}) => showModalBottomSheet<AttachmentSource>(
  context: context,
  backgroundColor: background,
  showDragHandle: true,
  builder: (context) {
    Widget option(AttachmentSource source, IconData icon, String label) =>
        ListTile(
          leading: Icon(icon, color: foreground),
          title: Text(label, style: TextStyle(color: foreground)),
          onTap: () => Navigator.pop(context, source),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            AttachmentSource.image,
            Icons.image_outlined,
            l10n.attachImageLabel,
          ),
          option(
            AttachmentSource.file,
            Icons.insert_drive_file_outlined,
            l10n.attachFileLabel,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  },
);

/// Opens the system picker; empty when cancelled.
Future<List<ChatwootUpload>> pickAttachments(AttachmentSource source) async {
  final files = await FilePicker.pickFiles(
    type: source == AttachmentSource.image ? FileType.image : FileType.any,
  );
  return [for (final file in files) ?await _toUpload(file)];
}

Future<ChatwootUpload?> _toUpload(PlatformFile file) async {
  if (kIsWeb) {
    // The web has no file paths, only bytes. Check the reported size before
    // reading: an oversized placeholder (never sent) lets the view say so.
    final size = await file.length();
    if ((size ?? 0) > ChatwootUpload.maxSize) {
      return ChatwootUpload.file(name: file.name, path: '', size: size);
    }
    return ChatwootUpload.bytes(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }
  final path = file.path;
  return path == null
      ? null
      : ChatwootUpload.file(
          name: file.name,
          path: path,
          size: await file.length(),
        );
}
