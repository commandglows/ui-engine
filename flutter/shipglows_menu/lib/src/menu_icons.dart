import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'menu_icon.dart';

/// Draws a [ShipglowsMenuIcon] in Flutter: by name from [overrides], then
/// from [ShipglowsMenuIcons.material]; else its Segoe glyph on Windows
/// (Segoe Fluent Icons, Segoe MDL2 Assets on Windows 10); else nothing.
/// Decorative: screen readers read the entry's label.
class ShipglowsMenuIconView extends StatelessWidget {
  const ShipglowsMenuIconView(
    this.icon, {
    super.key,
    this.size = 18,
    this.color,
    this.overrides = const {},
  });

  final ShipglowsMenuIcon icon;
  final double size;
  final Color? color;
  final Map<String, IconData> overrides;

  @override
  Widget build(BuildContext context) {
    final name = icon.name;
    final data = name == null
        ? null
        : overrides[name] ?? ShipglowsMenuIcons.material[name];
    if (data != null) {
      return ExcludeSemantics(
        child: Icon(data, size: size, color: color),
      );
    }
    final glyph = icon.glyph;
    if (glyph == null || !ShipglowsMenuIcons.hasSegoeFont) {
      return SizedBox.square(dimension: size);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            String.fromCharCode(glyph),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Segoe Fluent Icons',
              fontFamilyFallback: const ['Segoe MDL2 Assets'],
              fontSize: size * 0.9,
              height: 1,
              color: color ?? IconTheme.of(context).color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Flutter icons standing for the named [ShipglowsMenuIcon]s.
abstract final class ShipglowsMenuIcons {
  /// Whether the Segoe icon fonts can be used (Windows desktop).
  static bool get hasSegoeFont =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static const material = <String, IconData>{
    'open': Icons.open_in_new_rounded,
    'settings': Icons.settings_outlined,
    'info': Icons.info_outline_rounded,
    'update': Icons.sync_rounded,
    'quit': Icons.power_settings_new_rounded,
    'feedback': Icons.feedback_outlined,
    'manual': Icons.menu_book_outlined,
    'whatsNew': Icons.auto_awesome_outlined,
    'troubleshoot': Icons.build_outlined,
    'help': Icons.help_outline_rounded,
    'community': Icons.people_outline_rounded,
    'screenshot': Icons.screenshot_monitor_outlined,
    'video': Icons.videocam_outlined,
    'audio': Icons.mic_none_rounded,
    'search': Icons.search_rounded,
    'commandBar': Icons.keyboard_command_key_rounded,
    'keyboard': Icons.keyboard_outlined,
    'add': Icons.add_rounded,
    'edit': Icons.edit_outlined,
    'note': Icons.sticky_note_2_outlined,
    'calendar': Icons.calendar_today_outlined,
    'folder': Icons.folder_outlined,
    'copy': Icons.content_copy_rounded,
    'star': Icons.star_outline_rounded,
  };
}
