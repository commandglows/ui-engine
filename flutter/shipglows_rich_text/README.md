# `shipglows_rich_text`

Shared multiline Markdown editor for ShipGlows Flutter apps. It keeps the
document as ordinary Markdown text, styles common Markdown while editing, and
offers a formatting toolbar for headings, quotes, bold, italic, underline,
strikethrough, inline code, links, bullet and numbered lists, and task lists.
Undo and redo use Flutter's `UndoHistoryController`.

Use the toolbar for a writing surface, or hide it for a compact multiline
field such as the shared command bar:

```dart
final controller = ShipglowsMarkdownController(text: initialMarkdown);
final undo = UndoHistoryController();

ShipglowsRichTextField(
  controller: controller,
  undoController: undo,
  minLines: 6,
  maxLines: 18,
)

ShipglowsRichTextField(
  controller: commandController,
  showToolbar: false,
  minLines: 1,
  maxLines: 5,
)
```

Dispose controllers in the owning state. `ShipglowsTextFormatting` exposes
selection-preserving Markdown transformations for hosts that need additional
commands. Toolbar shortcuts are Ctrl/⌘+B, Ctrl/⌘+I, Ctrl/⌘+U, Ctrl/⌘+K and
Ctrl/⌘+Shift+X;
Flutter's text field provides its standard undo and redo keyboard shortcuts.
