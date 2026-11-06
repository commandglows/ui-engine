import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_account_deletion/shipglows_account_deletion.dart';

class _Session {
  _Session({this.subject = 'user_1', this.reconnectsAs = 'user_1'});

  String? subject;
  String? reconnectsAs;
  bool failsReconnection = false;
  bool failsSignOut = false;
  final calls = <String>[];

  AccountDeletionAuth get auth => AccountDeletionAuth(
    currentSubject: () => subject,
    reauthenticate: () async {
      calls.add('reconnect');
      if (failsReconnection) throw StateError('network');
      return reconnectsAs;
    },
    signOut: () async {
      calls.add('signOut');
      if (failsSignOut) throw StateError('network');
    },
  );
}

Widget _screen(Widget child) => MaterialApp(
  home: Scaffold(body: child),
);

void main() {
  group('runAccountDeletion', () {
    Future<AccountDeletionOutcome> run(_Session session, {bool fails = false}) {
      return runAccountDeletion(
        auth: session.auth,
        deleteOnServer: () async {
          session.calls.add('server');
          if (fails) throw StateError('server');
        },
      );
    }

    Matcher failure(AccountDeletionFailureKind kind) => throwsA(
      isA<AccountDeletionFailure>().having((f) => f.kind, 'kind', kind),
    );

    test('reconnects, erases on the server, then signs out', () async {
      final session = _Session();
      expect(await run(session), AccountDeletionOutcome.deleted);
      expect(session.calls, ['reconnect', 'server', 'signOut']);
    });

    test('a canceled reconnection deletes nothing', () async {
      final session = _Session(reconnectsAs: null);
      expect(await run(session), AccountDeletionOutcome.canceled);
      expect(session.calls, ['reconnect']);
    });

    test('another account stops before the server', () async {
      final session = _Session(reconnectsAs: 'user_2');
      await expectLater(
        run(session),
        failure(AccountDeletionFailureKind.otherAccount),
      );
      expect(session.calls, ['reconnect']);
    });

    test('no session stops at once', () async {
      final session = _Session(subject: null);
      await expectLater(
        run(session),
        failure(AccountDeletionFailureKind.notSignedIn),
      );
      expect(session.calls, isEmpty);
    });

    test('a failed reconnection deletes nothing', () async {
      final session = _Session()..failsReconnection = true;
      await expectLater(
        run(session),
        failure(AccountDeletionFailureKind.reconnection),
      );
      expect(session.calls, ['reconnect']);
    });

    test('a server failure keeps the session', () async {
      final session = _Session();
      await expectLater(
        run(session, fails: true),
        failure(AccountDeletionFailureKind.server),
      );
      expect(session.calls, ['reconnect', 'server']);
    });

    test('a failed sign-out is not a failure once deleted', () async {
      final session = _Session()..failsSignOut = true;
      expect(await run(session), AccountDeletionOutcome.deleted);
    });
  });

  group('ShipglowsDeleteAccountButton', () {
    testWidgets('the dialog lists the data and only confirming deletes', (
      tester,
    ) async {
      final session = _Session();
      var deleted = 0;
      await tester.pumpWidget(
        _screen(
          ShipglowsDeleteAccountButton(
            auth: session.auth,
            deleteOnServer: () async => session.calls.add('server'),
            erasedData: const ['Tes notes'],
            onDeleted: () => deleted += 1,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('shipglows-delete-account')));
      await tester.pumpAndSettle();
      expect(find.text('• Tes notes'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(session.calls, isEmpty);

      await tester.tap(find.byKey(const Key('shipglows-delete-account')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('shipglows-delete-account-confirm')),
      );
      await tester.pumpAndSettle();
      expect(session.calls, ['reconnect', 'server', 'signOut']);
      expect(deleted, 1);
    });

    testWidgets('a failure shows its message and reports it', (tester) async {
      final session = _Session(reconnectsAs: 'user_2');
      AccountDeletionFailure? reported;
      await tester.pumpWidget(
        _screen(
          ShipglowsDeleteAccountButton(
            auth: session.auth,
            deleteOnServer: () async {},
            erasedData: const [],
            onFailure: (failure) => reported = failure,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('shipglows-delete-account')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('shipglows-delete-account-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shipglows-delete-account-error')),
        findsOneWidget,
      );
      expect(reported?.kind, AccountDeletionFailureKind.otherAccount);
    });

    testWidgets('an app draws its own action and confirmation', (tester) async {
      final session = _Session();
      var asked = 0;
      await tester.pumpWidget(
        _screen(
          ShipglowsDeleteAccountButton(
            auth: session.auth,
            deleteOnServer: () async => session.calls.add('server'),
            erasedData: const [],
            actionBuilder: (context, action) => OutlinedButton(
              key: const Key('own-action'),
              onPressed: action.busy ? null : action.onPressed,
              child: Text(action.label),
            ),
            confirm: (context) async {
              asked += 1;
              return true;
            },
          ),
        ),
      );
      expect(find.byKey(const Key('shipglows-delete-account')), findsNothing);
      await tester.tap(find.byKey(const Key('own-action')));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(session.calls, ['reconnect', 'server', 'signOut']);
    });

    testWidgets('a product with recovery says so in the dialog', (tester) async {
      await tester.pumpWidget(
        _screen(
          ShipglowsDeleteAccountButton(
            auth: _Session().auth,
            deleteOnServer: () async {},
            erasedData: const [],
            paidAccessNotice:
                ShipglowsAccessRecoveryStrings.fr.paidAccessNotice,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('shipglows-delete-account')));
      await tester.pumpAndSettle();
      expect(
        find.text(ShipglowsAccessRecoveryStrings.fr.paidAccessNotice),
        findsOneWidget,
      );
      expect(
        find.text(ShipglowsAccountDeletionStrings.fr.paidAccess),
        findsNothing,
      );
    });
  });

  group('ShipglowsAccessRecovery', () {
    const offer = Key('shipglows-access-recovery');
    const action = Key('shipglows-access-recovery-action');

    testWidgets('takes no space when nothing is recoverable', (tester) async {
      await tester.pumpWidget(
        _screen(
          ShipglowsAccessRecovery(
            findRecoverable: () async => false,
            recover: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(offer), findsNothing);
    });

    testWidgets('moves nothing until pressed, then disappears', (tester) async {
      var recovered = 0;
      var notified = 0;
      await tester.pumpWidget(
        _screen(
          ShipglowsAccessRecovery(
            findRecoverable: () async => true,
            recover: () async => recovered += 1,
            onRecovered: () => notified += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(offer), findsOneWidget);
      expect(recovered, 0);

      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(recovered, 1);
      expect(notified, 1);
      expect(find.byKey(offer), findsNothing);
    });

    testWidgets('a failure keeps the offer and shows the message', (
      tester,
    ) async {
      Object? reported;
      await tester.pumpWidget(
        _screen(
          ShipglowsAccessRecovery(
            findRecoverable: () async => true,
            recover: () async => throw StateError('server'),
            onFailure: (error) => reported = error,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(action));
      await tester.pumpAndSettle();
      expect(find.byKey(offer), findsOneWidget);
      expect(
        find.byKey(const Key('shipglows-access-recovery-error')),
        findsOneWidget,
      );
      expect(reported, isA<StateError>());
    });

    testWidgets('an unreachable check stays silent', (tester) async {
      Object? reported;
      await tester.pumpWidget(
        _screen(
          ShipglowsAccessRecovery(
            findRecoverable: () async => throw StateError('offline'),
            recover: () async {},
            onFailure: (error) => reported = error,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(offer), findsNothing);
      expect(reported, isA<StateError>());
    });
  });
}
