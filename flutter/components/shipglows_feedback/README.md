# shipglows_feedback

In-app messages: info, success, warning, error. One look and one queue in
every app instead of each app's own SnackBars and toasts. Depends on
`shipglows_theme`. Not the Windows system toasts (see the desktop shell
audit, item 12).

- `showFeedback(context, message, kind:)`, or `context.showInfo` /
  `showSuccess` / `showWarning` / `showError`: a floating snack bar on
  `surfaceRaised` with a `border` outline, 480 wide on large windows. The
  icon in the kind's color (`accent`, `success`, `warning`, `danger`), the
  text in `text`, so the kind never rests on color alone.
- Defaults by kind: 4 s for info and success, 6 s for warning, 8 s with a
  close button for errors. Optional action (`actionLabel`, `onAction`): the
  message then stays until dismissed for assistive-technology users.
- Messages queue one after the other; `replaceCurrent: true` closes the one
  on screen first. The same text of the same kind, still queued or shown, is
  not queued again (a failing sync reporting each retry).
- Read as « Error: … » by a screen reader: `FeedbackStrings.en`, `.fr`
  (picked from the app locale) or the app's own (`copyWith`).
- After an await, read `FeedbackMessenger.of(context)` before it and show
  through it after (same queue, theme and texts, the widget may be gone).
  Never pass the `ScaffoldMessenger`'s own context to `feedbackSnackBar`:
  `MaterialApp` puts it above the theme, so the brand roles are lost.
- `showError(…, details: () => error.toString())` offers « Copy details »
  (beside the action when there is one), then confirms « Details copied ».
- Two actions: `secondaryActionLabel:` / `onSecondaryAction:` on
  `showFeedback`, `FeedbackMessenger.show` and `feedbackSnackBar`; a snack
  bar takes one `SnackBarAction`, so the second is a text button beside the
  message, which closes it too.
- `replaceCurrent: true` also skips the repeat check.
- `FeedbackInline(message:, kind:, title:, dense:, trailing:, actions:)`: a message in
  place (under a form, in a panel), tinted with its kind, announced when it
  appears. `FeedbackContent(liveRegion: true)` for the bare icon and text.
- `FeedbackErrorState(message:, title:, onRetry:, details:)`: what a screen
  shows when loading it failed, with « Retry » and « Copy details ».
  `compact: true` aligns it to the start with a smaller icon (a panel, a
  card); `helperText:` says what to do; `selectable: true` lets the message
  be copied by hand; `secondaryLabel:` / `onSecondary:` for a second
  action; `showIcon:`, `copyLabel:`.
- `FeedbackStringsScope(strings: FeedbackStrings.fr, child:)` in
  `MaterialApp.builder` sets the texts for the whole app (French apps
  without `flutter_localizations` read as English otherwise).
- `FeedbackAppearanceScope(appearance: FeedbackAppearance(…), child:)` in
  `MaterialApp.builder` gives an app its own snack bar colors and placement
  (`margin`, read as each message is built); unset, the shared look stays.
- `feedbackSnackBar(context, …, wrapContent:)` builds the same snack bar for
  code that shows it itself; `FeedbackContent` is the icon and text alone,
  for an app's own surface.
- `FeedbackLog.addListener` hears every message shown through
  `showFeedback` / `FeedbackMessenger` (repeats not queued are not heard),
  for a history: `FeedbackHistory` of `shipglows_notification_center`.
- Errors take `danger`, which the `ColorScheme` fallback sets to
  `scheme.error`: an app keeping red for emergencies sets its own.

```dart
context.showSuccess('Saved');
context.showError('Could not publish', actionLabel: 'Retry', onAction: publish);

final feedback = FeedbackMessenger.of(context);
try {
  await api.save();
  feedback.showSuccess('Saved');
} catch (error) {
  feedback.showError('Could not save', details: () => '$error');
}
```
