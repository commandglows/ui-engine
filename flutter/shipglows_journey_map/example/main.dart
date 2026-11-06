// Minimal usage. Run with `flutter create .` inside example/ then
// `flutter run`, or copy the widget into your app.
import 'package:flutter/material.dart';
import 'package:shipglows_journey_map/shipglows_journey_map.dart';

void main() => runApp(const MaterialApp(home: ExampleScreen()));

/// Two chapters of a goal journey with a scroll-to-current controller.
class ExampleScreen extends StatefulWidget {
  /// Creates the example.
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  final _controller = JourneyMapController();
  String? _selected;

  // Keep the same list instance between builds: the map re-flattens only when
  // the instance changes.
  final _chapters = [
    JourneyChapter(
      id: 'dream',
      title: 'Run a marathon',
      trailing: '2/5',
      icon: Icons.flag_outlined,
      nodes: [
        for (var i = 0; i < 5; i++)
          JourneyNode(
            id: 'step-$i',
            label: 'Step ${i + 1}',
            marker: '${i + 1}',
            state: i < 2
                ? JourneyNodeState.done
                : i == 2
                ? JourneyNodeState.current
                : JourneyNodeState.upcoming,
          ),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Journey')),
    body: JourneyMapView(
      chapters: _chapters,
      controller: _controller,
      selectedId: _selected,
      initialScrollToCurrent: true,
      onSelect: (id) => setState(() => _selected = id),
    ),
  );
}
