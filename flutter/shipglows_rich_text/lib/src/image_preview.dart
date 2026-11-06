import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Read-only image shown where an editor would show a document, for an item
/// whose content is a picture rather than Markdown text.
///
/// [image] loads the full picture; the host keeps the same future across
/// rebuilds. [thumbnail] stands in while it loads and stays beside
/// [missingMessage] when it fails or resolves to null.
class ShipglowsImagePreview extends StatelessWidget {
  const ShipglowsImagePreview({
    super.key,
    required this.image,
    required this.semanticLabel,
    required this.missingMessage,
    this.thumbnail,
  });

  /// Full picture; null or an error means it is no longer available.
  final Future<Uint8List?> image;

  /// Announced by screen readers in place of the picture.
  final String semanticLabel;

  /// Shown when the full picture cannot be displayed.
  final String missingMessage;

  /// Small version available at once, if the host has one.
  final Uint8List? thumbnail;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: image,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return _picture(bytes);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          final small = thumbnail;
          return small != null
              ? _picture(small)
              : const Center(child: CircularProgressIndicator());
        }
        return _missing(context);
      },
    );
  }

  /// Fits inside the space given, without upscaling a small picture.
  Widget _picture(Uint8List bytes) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ShipglowsScale.radiusSm),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }

  Widget _missing(BuildContext context) {
    final small = thumbnail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (small != null) ...[
          Flexible(child: _picture(small)),
          const SizedBox(height: ShipglowsScale.spaceSm),
        ],
        Text(
          missingMessage,
          style: TextStyle(color: ShipglowsTheme.of(context).textMuted),
        ),
      ],
    );
  }
}
