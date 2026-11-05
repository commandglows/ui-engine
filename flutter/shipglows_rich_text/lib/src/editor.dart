import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// A Markdown block prefix exposed by the shared editor toolbar.
enum ShipglowsTextBlock {
  paragraph('Paragraphe', ''),
  heading1('Titre 1', '# '),
  heading2('Titre 2', '## '),
  heading3('Titre 3', '### '),
  quote('Citation', '> ');

  const ShipglowsTextBlock(this.label, this.prefix);

  final String label;
  final String prefix;

  static final _prefix = RegExp(r'^(#{1,6} |> )');

  static ShipglowsTextBlock fromLine(String line) {
    if (line.startsWith('### ')) return heading3;
    if (line.startsWith('## ')) return heading2;
    if (line.startsWith('# ')) return heading1;
    if (line.startsWith('> ')) return quote;
    return paragraph;
  }

  static String strip(String line) => line.replaceFirst(_prefix, '');
}

/// Inline formatting supported by the editor and stored as Markdown.
enum ShipglowsTextMark {
  bold('**', '**'),
  italic('_', '_'),
  underline('<u>', '</u>'),
  strikethrough('~~', '~~'),
  code('`', '`');

  const ShipglowsTextMark(this.open, this.close);

  final String open;
  final String close;
}

/// Text controller that styles common Markdown marks while keeping their
/// source visible and editable.
class ShipglowsMarkdownController extends TextEditingController {
  ShipglowsMarkdownController({super.text});

  static final _inline = RegExp(
    r'(\*\*.+?\*\*|~~.+?~~|`.+?`|<u>.+?</u>|\[[^\]]+\]\([^)]+\)|(?<!_)_(?!_).+?_(?!_))',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing;
    if (withComposing && composing.isValid && !composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    final roles = ShipglowsTheme.of(context);
    var lineStart = 0;
    while (lineStart < text.length) {
      final lineBreak = text.indexOf('\n', lineStart);
      final lineEnd = lineBreak < 0 ? text.length : lineBreak;
      final line = text.substring(lineStart, lineEnd);
      final prefix = RegExp(r'^(#{1,6} |> |- \[[ x]\] |- |\d+\. )')
          .firstMatch(line);
      var lineStyle = base;
      if (line.startsWith('# '))
        lineStyle = base.copyWith(
          fontSize: ShipglowsScale.textXl,
          fontWeight: FontWeight.w700,
        );
      if (line.startsWith('## '))
        lineStyle = base.copyWith(
          fontSize: ShipglowsScale.textLg,
          fontWeight: FontWeight.w700,
        );
      if (line.startsWith('### '))
        lineStyle = base.copyWith(fontWeight: FontWeight.w700);
      if (line.startsWith('> '))
        lineStyle = base.copyWith(
          color: roles.textMuted,
          fontStyle: FontStyle.italic,
        );
      final contentOffset = prefix?.end ?? 0;
      if (contentOffset > 0) {
        spans.add(
          TextSpan(
            text: line.substring(0, contentOffset),
            style: base.copyWith(color: roles.textMuted),
          ),
        );
      }
      spans.addAll(_inlineSpans(line, contentOffset, lineStyle, roles.accent));
      if (lineBreak >= 0) {
        spans.add(const TextSpan(text: '\n'));
        lineStart = lineBreak + 1;
      } else {
        break;
      }
    }
    return TextSpan(style: base, children: spans);
  }

  List<InlineSpan> _inlineSpans(
    String source,
    int start,
    TextStyle style,
    Color accent,
  ) {
    final spans = <InlineSpan>[];
    var offset = start;
    for (final match in _inline.allMatches(source, start)) {
      if (match.start > offset)
        spans.add(
          TextSpan(text: source.substring(offset, match.start), style: style),
        );
      spans.add(_styledToken(match.group(0)!, style, accent));
      offset = match.end;
    }
    if (offset < source.length)
      spans.add(TextSpan(text: source.substring(offset), style: style));
    return spans;
  }

  InlineSpan _styledToken(String token, TextStyle base, Color accent) {
    String open;
    String close;
    TextStyle contentStyle;
    if (token.startsWith('**')) {
      open = '**';
      close = '**';
      contentStyle = base.copyWith(fontWeight: FontWeight.bold);
    } else if (token.startsWith('~~')) {
      open = '~~';
      close = '~~';
      contentStyle = base.copyWith(decoration: TextDecoration.lineThrough);
    } else if (token.startsWith('`')) {
      open = '`';
      close = '`';
      contentStyle = base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: accent.withValues(alpha: .12),
      );
    } else if (token.startsWith('<u>')) {
      open = '<u>';
      close = '</u>';
      contentStyle = base.copyWith(decoration: TextDecoration.underline);
    } else if (token.startsWith('[')) {
      final separator = token.indexOf('](');
      return TextSpan(
        children: [
          TextSpan(
            text: '[',
            style: base.copyWith(color: accent),
          ),
          TextSpan(
            text: token.substring(1, separator),
            style: base.copyWith(
              color: accent,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(
            text: token.substring(separator),
            style: base.copyWith(color: accent),
          ),
        ],
      );
    } else {
      open = '_';
      close = '_';
      contentStyle = base.copyWith(fontStyle: FontStyle.italic);
    }
    final muted = base.copyWith(color: base.color?.withValues(alpha: .58));
    return TextSpan(
      children: [
        TextSpan(text: open, style: muted),
        TextSpan(
          text: token.substring(open.length, token.length - close.length),
          style: contentStyle,
        ),
        TextSpan(text: close, style: muted),
      ],
    );
  }
}

/// Selection-preserving Markdown transformations used by the editor toolbar.
abstract final class ShipglowsTextFormatting {
  static TextEditingValue wrap(TextEditingValue value, ShipglowsTextMark mark) {
    final selection = _selection(value);
    final selected = value.text.substring(selection.start, selection.end);
    final inserted = '${mark.open}$selected${mark.close}';
    return TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, inserted),
      selection: TextSelection(
        baseOffset: selection.start + mark.open.length,
        extentOffset: selection.start + mark.open.length + selected.length,
      ),
    );
  }

  static TextEditingValue link(TextEditingValue value) {
    final selection = _selection(value);
    final selected = value.text.substring(selection.start, selection.end);
    final label = selected.isEmpty ? 'lien' : selected;
    final inserted = '[$label]()';
    return TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, inserted),
      selection: TextSelection.collapsed(
        offset: selection.start + inserted.length - 1,
      ),
    );
  }

  static TextEditingValue block(
    TextEditingValue value,
    ShipglowsTextBlock block,
  ) => _mapLines(
    value,
    (line, _) => '${block.prefix}${ShipglowsTextBlock.strip(line)}',
  );

  static ShipglowsTextBlock blockAt(TextEditingValue value) {
    final (start, end) = _lineBounds(value);
    return ShipglowsTextBlock.fromLine(
      value.text.substring(start, end).split('\n').first,
    );
  }

  static TextEditingValue toggleBullets(TextEditingValue value) {
    final lines = _selectedLines(value);
    final allMarked = lines.every((line) => line.startsWith('- '));
    return _mapLines(
      value,
      (line, _) => allMarked ? line.substring(2) : '- ${_stripList(line)}',
    );
  }

  static TextEditingValue toggleNumbers(TextEditingValue value) {
    final lines = _selectedLines(value);
    final allMarked = lines.every((line) => RegExp(r'^\d+\. ').hasMatch(line));
    return _mapLines(
      value,
      (line, index) => allMarked
          ? line.replaceFirst(RegExp(r'^\d+\. '), '')
          : '${index + 1}. ${_stripList(line)}',
    );
  }

  static TextEditingValue toggleChecklist(TextEditingValue value) {
    final lines = _selectedLines(value);
    final allMarked = lines.every(
      (line) => line.startsWith('- [ ] ') || line.startsWith('- [x] '),
    );
    return _mapLines(
      value,
      (line, _) => allMarked
          ? line.replaceFirst(RegExp(r'^- \[[ x]\] '), '')
          : '- [ ] ${_stripList(line)}',
    );
  }

  static TextSelection _selection(TextEditingValue value) {
    if (!value.selection.isValid)
      return TextSelection.collapsed(offset: value.text.length);
    return value.selection;
  }

  static (int, int) _lineBounds(TextEditingValue value) {
    final selection = _selection(value);
    final start = selection.start == 0
        ? 0
        : value.text.lastIndexOf('\n', selection.start - 1) + 1;
    final nextBreak = value.text.indexOf('\n', selection.end);
    return (start, nextBreak < 0 ? value.text.length : nextBreak);
  }

  static List<String> _selectedLines(TextEditingValue value) {
    final (start, end) = _lineBounds(value);
    return value.text.substring(start, end).split('\n');
  }

  static String _stripList(String line) => line
      .replaceFirst(RegExp(r'^- \[[ x]\] '), '')
      .replaceFirst(RegExp(r'^- '), '')
      .replaceFirst(RegExp(r'^\d+\. '), '');

  static TextEditingValue _mapLines(
    TextEditingValue value,
    String Function(String line, int index) map,
  ) {
    final (start, end) = _lineBounds(value);
    final mapped = value.text
        .substring(start, end)
        .split('\n')
        .indexed
        .map((entry) => map(entry.$2, entry.$1))
        .join('\n');
    return TextEditingValue(
      text: value.text.replaceRange(start, end, mapped),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + mapped.length,
      ),
    );
  }
}

/// Editable Markdown field with optional formatting toolbar.
///
/// Text remains Markdown in [controller], so apps can store or synchronize it
/// without a package-specific document format. Set [showToolbar] to false for
/// compact multiline inputs such as a command bar.
class ShipglowsRichTextField extends StatelessWidget {
  const ShipglowsRichTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
    this.showToolbar = true,
    this.minLines = 1,
    this.maxLines = 6,
    this.hintText,
    this.style,
    this.decoration,
    this.onChanged,
    this.toolbarTrailing,
    this.undoController,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool autofocus;
  final bool showToolbar;
  final int minLines;
  final int maxLines;
  final String? hintText;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final Widget? toolbarTrailing;
  final UndoHistoryController? undoController;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      undoController: undoController,
      style: style,
      onChanged: onChanged,
      decoration: decoration ?? InputDecoration(hintText: hintText),
    );
    if (!showToolbar) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          trailing: toolbarTrailing,
          undoController: undoController,
        ),
        const Divider(height: 1),
        Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                const _FormatIntent(ShipglowsTextMark.bold),
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
                const _FormatIntent(ShipglowsTextMark.bold),
            const SingleActivator(LogicalKeyboardKey.keyI, control: true):
                const _FormatIntent(ShipglowsTextMark.italic),
            const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
                const _FormatIntent(ShipglowsTextMark.italic),
            const SingleActivator(LogicalKeyboardKey.keyU, control: true):
                const _FormatIntent(ShipglowsTextMark.underline),
            const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
                const _FormatIntent(ShipglowsTextMark.underline),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                const _LinkIntent(),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                const _LinkIntent(),
            const SingleActivator(
              LogicalKeyboardKey.keyX,
              control: true,
              shift: true,
            ): const _FormatIntent(
              ShipglowsTextMark.strikethrough,
            ),
            const SingleActivator(
              LogicalKeyboardKey.keyX,
              meta: true,
              shift: true,
            ): const _FormatIntent(
              ShipglowsTextMark.strikethrough,
            ),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _FormatIntent: _FormatAction(controller),
              _LinkIntent: _LinkAction(controller),
            },
            child: field,
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.trailing,
    this.undoController,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final Widget? trailing;
  final UndoHistoryController? undoController;

  void apply(TextEditingValue Function(TextEditingValue) edit) {
    if (!enabled) return;
    controller.value = edit(controller.value);
    focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        if (undoController != null) undoController!,
      ]),
      builder: (context, _) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ShipglowsScale.spaceXs,
        runSpacing: ShipglowsScale.spaceXs,
        children: _toolbarChildren(controller.value),
      ),
    );
  }

  List<Widget> _toolbarChildren(TextEditingValue value) => [
    if (undoController != null) ...[
      IconButton(
        tooltip: 'Annuler',
        visualDensity: VisualDensity.compact,
        onPressed: enabled && undoController!.value.canUndo
            ? undoController!.undo
            : null,
        icon: const Icon(Icons.undo),
      ),
      IconButton(
        tooltip: 'Rétablir',
        visualDensity: VisualDensity.compact,
        onPressed: enabled && undoController!.value.canRedo
            ? undoController!.redo
            : null,
        icon: const Icon(Icons.redo),
      ),
    ],
    DropdownButton<ShipglowsTextBlock>(
      value: ShipglowsTextFormatting.blockAt(value),
      underline: const SizedBox.shrink(),
      onChanged: enabled
          ? (block) {
              if (block != null) {
                apply((v) => ShipglowsTextFormatting.block(v, block));
              }
            }
          : null,
      items: [
        for (final block in ShipglowsTextBlock.values)
          DropdownMenuItem(value: block, child: Text(block.label)),
      ],
    ),
    for (final (mark, icon, label) in <(ShipglowsTextMark, IconData, String)>[
      (ShipglowsTextMark.bold, Icons.format_bold, 'Gras'),
      (ShipglowsTextMark.italic, Icons.format_italic, 'Italique'),
      (ShipglowsTextMark.underline, Icons.format_underlined, 'Souligné'),
      (ShipglowsTextMark.strikethrough, Icons.strikethrough_s, 'Barré'),
      (ShipglowsTextMark.code, Icons.code, 'Code'),
    ])
      IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        onPressed: enabled
            ? () => apply((v) => ShipglowsTextFormatting.wrap(v, mark))
            : null,
        icon: Icon(icon),
      ),
    IconButton(
      tooltip: 'Liste à puces',
      visualDensity: VisualDensity.compact,
      onPressed: enabled
          ? () => apply(ShipglowsTextFormatting.toggleBullets)
          : null,
      icon: const Icon(Icons.format_list_bulleted),
    ),
    IconButton(
      tooltip: 'Liste numérotée',
      visualDensity: VisualDensity.compact,
      onPressed: enabled
          ? () => apply(ShipglowsTextFormatting.toggleNumbers)
          : null,
      icon: const Icon(Icons.format_list_numbered),
    ),
    IconButton(
      tooltip: 'Liste de tâches',
      visualDensity: VisualDensity.compact,
      onPressed: enabled
          ? () => apply(ShipglowsTextFormatting.toggleChecklist)
          : null,
      icon: const Icon(Icons.checklist),
    ),
    IconButton(
      tooltip: 'Lien',
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? () => apply(ShipglowsTextFormatting.link) : null,
      icon: const Icon(Icons.link),
    ),
    if (trailing != null) trailing!,
  ];
}

class _FormatIntent extends Intent {
  const _FormatIntent(this.mark);
  final ShipglowsTextMark mark;
}

class _LinkIntent extends Intent {
  const _LinkIntent();
}

class _FormatAction extends Action<_FormatIntent> {
  _FormatAction(this.controller);
  final TextEditingController controller;
  @override
  Object? invoke(_FormatIntent intent) {
    controller.value = ShipglowsTextFormatting.wrap(
      controller.value,
      intent.mark,
    );
    return null;
  }
}

class _LinkAction extends Action<_LinkIntent> {
  _LinkAction(this.controller);
  final TextEditingController controller;
  @override
  Object? invoke(_LinkIntent intent) {
    controller.value = ShipglowsTextFormatting.link(controller.value);
    return null;
  }
}
