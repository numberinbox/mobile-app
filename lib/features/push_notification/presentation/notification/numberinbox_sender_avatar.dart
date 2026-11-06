import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';

/// Bounded, local-only decoration. No contacts, network, persistent cache or UI context.
class NumberInboxSenderAvatar {
  static String initials(String value) {
    final words = value.characters
        .take(128)
        .toString()
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    return words
        .map((part) => part.characters.first.toUpperCase())
        .join()
        .characters
        .take(2)
        .toString();
  }

  static Future<Uint8List?> render(String label) async {
    final text = initials(label);
    if (text.isEmpty) return null;
    ui.Picture? picture;
    ui.Image? image;
    try {
      const size = 96.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawCircle(
        const Offset(48, 48),
        48,
        Paint()..color = NumberInboxPalette.interactiveAccent,
      );
      final paragraph =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(
                    textAlign: TextAlign.center,
                    fontSize: 36,
                    maxLines: 1,
                  ),
                )
                ..pushStyle(
                  ui.TextStyle(
                    color: NumberInboxPalette.primaryActionForeground,
                    fontWeight: FontWeight.w500,
                  ),
                )
                ..addText(text))
              .build()
            ..layout(const ui.ParagraphConstraints(width: size));
      canvas.drawParagraph(paragraph, Offset(0, (size - paragraph.height) / 2));
      paragraph.dispose();
      picture = recorder.endRecording();
      image = await picture.toImage(96, 96);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      picture?.dispose();
    }
  }
}
