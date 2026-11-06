import 'package:flutter/material.dart';
import 'package:shipglows_journey_map/shipglows_journey_map.dart';

/// A chapter of [count] nodes; node [current] is the current one and every
/// node before it is done.
JourneyChapter chapterOf(
  String id,
  int count, {
  int? current,
  String prefix = 'n',
}) => JourneyChapter(
  id: id,
  title: 'Chapter $id',
  trailing: '0/$count',
  nodes: [
    for (var i = 0; i < count; i++)
      JourneyNode(
        id: '$prefix$id-$i',
        label: 'Node $i',
        caption: 'Caption $i',
        marker: '${i + 1}',
        state: current == null
            ? JourneyNodeState.neutral
            : i < current
            ? JourneyNodeState.done
            : i == current
            ? JourneyNodeState.current
            : JourneyNodeState.upcoming,
      ),
  ],
);

/// Hosts [child] in a Material app of a fixed size.
Widget host(
  Widget child, {
  Size size = const Size(420, 900),
  ThemeData? theme,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: theme,
  debugShowCheckedModeBanner: false,
  home: Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: SizedBox(width: size.width, child: child),
      ),
    ),
  ),
);
