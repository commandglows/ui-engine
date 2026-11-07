import 'package:flutter/widgets.dart';

/// `MaterialApp.builder` that sets reduced motion, as the OS setting would.
///
/// A looping animation otherwise keeps `pumpAndSettle` waiting until it fails.
Widget reducedMotionBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  );
}
