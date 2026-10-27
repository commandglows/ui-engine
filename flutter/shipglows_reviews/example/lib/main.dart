import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_reviews/shipglows_reviews.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// Receives the reviews in memory and can play offline.
class DemoSink implements ReviewSink {
  final received = ValueNotifier<List<CustomerReview>>(const []);
  final offline = ValueNotifier(false);

  @override
  Future<void> send(CustomerReview review) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (offline.value) throw StateError('offline (demo)');
    received.value = [review, ...received.value];
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sink = DemoSink();
  final reviews = await ShipglowsReviews.open(
    config: const ShipglowsReviewsConfig(
      appId: 'reviews-example',
      reviewSite: ReviewSite(
        name: 'Trustpilot',
        url: 'https://www.trustpilot.com/',
      ),
      // Asks after one success, every time: a playground, not an app.
      policy: ReviewPolicy(
        minTimeInstalled: Duration.zero,
        minLaunches: 0,
        minPositiveMoments: 1,
        quietAfterProblem: Duration.zero,
        quietAfterOwnReview: Duration.zero,
        minTimeBetweenPrompts: Duration.zero,
        maxPromptsPerYear: 1000,
        oncePerVersion: false,
      ),
      promptInDebug: true,
    ),
    sink: sink,
  );
  runApp(ExampleApp(reviews: reviews, sink: sink));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.reviews, required this.sink});

  final ShipglowsReviews reviews;
  final DemoSink sink;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'shipglows_reviews',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      builder: (context, child) => FeedbackStringsScope(
        strings: FeedbackStrings.fr,
        child: ShipglowsReviewStringsScope(
          strings: ShipglowsReviewStrings.fr,
          child: child!,
        ),
      ),
      home: ExampleHome(reviews: reviews, sink: sink),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key, required this.reviews, required this.sink});

  final ShipglowsReviews reviews;
  final DemoSink sink;

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  static const appName = 'Exemple';

  ShipglowsReviews get reviews => widget.reviews;

  Future<void> _ask() async {
    final asked = await reviews.maybeAskForReview(context, appName: appName);
    if (!mounted) return;
    setState(() {});
    if (!asked) context.showInfo('Pas maintenant : ${_why()}');
  }

  String _why() => switch (reviews.eligibility) {
    ReviewEligible() => 'prêt',
    ReviewNotYet(:final reason) => reason.name,
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final info = reviews.storeInfo;
    return Scaffold(
      appBar: AppBar(title: const Text('shipglows_reviews')),
      body: ListView(
        padding: EdgeInsets.all(theme.spaceLg),
        children: [
          Text(
            'Plateforme : ${info.platform} · installation : '
            '${info.installSource.name} · version : ${info.appVersion} · '
            'invite du store : ${reviews.usesStorePrompt ? 'oui' : 'non'} · '
            'éligibilité : ${_why()} · lancements : ${reviews.state.launches} '
            '· réussites : ${reviews.state.positiveMoments}',
          ),
          SizedBox(height: theme.spaceLg),
          Wrap(
            spacing: theme.spaceSm,
            runSpacing: theme.spaceSm,
            children: [
              FilledButton(
                onPressed: () {
                  context.showSuccess('Tâche terminée');
                  setState(() {});
                },
                child: const Text('Simuler une réussite'),
              ),
              FilledButton.tonal(
                onPressed: _ask,
                child: const Text('Moment naturel : demander un avis'),
              ),
              OutlinedButton(
                onPressed: () => showShipglowsReviewInvitation(
                  context,
                  reviews: reviews,
                  appName: appName,
                ),
                child: const Text('Invitation'),
              ),
              OutlinedButton(
                onPressed: () => showShipglowsReviewForm(
                  context,
                  reviews: reviews,
                  appName: appName,
                  topic: ReviewTopic.problem,
                ),
                child: const Text('Signaler un problème'),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.sink.offline,
            builder: (context, offline, _) => SwitchListTile(
              title: const Text('Simuler hors ligne'),
              subtitle: const Text(
                'Les avis restent sur l’appareil et partent au retour.',
              ),
              value: offline,
              onChanged: (value) {
                widget.sink.offline.value = value;
                if (!value) unawaited(reviews.flush());
              },
            ),
          ),
          const Divider(),
          ShipglowsReviewSettings(reviews: reviews, appName: appName),
          const Divider(),
          Text('Avis reçus', style: Theme.of(context).textTheme.titleMedium),
          ValueListenableBuilder<List<CustomerReview>>(
            valueListenable: widget.sink.received,
            builder: (context, received, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (received.isEmpty) const Text('Aucun pour l’instant.'),
                for (final review in received)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(theme.spaceMd),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(
                          review.toJson(),
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
