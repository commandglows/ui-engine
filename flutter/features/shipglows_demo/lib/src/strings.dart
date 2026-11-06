import 'package:flutter/widgets.dart';

/// Texts of the demo surfaces. The app picks the language: [en], [fr], or
/// its own values through [copyWith], once for the app with
/// [DemoStringsScope] or per call. `{action}` is filled in.
@immutable
class DemoStrings {
  const DemoStrings({
    required this.bannerTitle,
    required this.bannerMessage,
    required this.exit,
    required this.exitTitle,
    required this.exitMessage,
    required this.cancel,
    required this.accountTitle,
    required this.accountMessage,
    required this.accountMessageAny,
    required this.keepExploring,
    required this.createAccount,
  });

  /// Title of [DemoBanner].
  final String bannerTitle;
  final String bannerMessage;

  /// Exit button, and confirm button of the exit dialog.
  final String exit;
  final String exitTitle;

  /// What leaving removes and what it keeps.
  final String exitMessage;
  final String cancel;

  /// Dialog of an action the demo cannot run.
  final String accountTitle;

  /// The blocked action named: `{action}`.
  final String accountMessage;

  /// The blocked action not named.
  final String accountMessageAny;
  final String keepExploring;
  final String createAccount;

  static const en = DemoStrings(
    bannerTitle: 'Demo mode',
    bannerMessage:
        'You are exploring sample data. Nothing you do here changes your '
        'own data.',
    exit: 'Leave demo mode',
    exitTitle: 'Leave demo mode?',
    exitMessage:
        'The sample items and their history will be removed. Your own data '
        'stays.',
    cancel: 'Cancel',
    accountTitle: 'This action needs an account',
    accountMessage:
        'Create your account to use “{action}”. The demo stays as it is.',
    accountMessageAny:
        'Create your account to use this action. The demo stays as it is.',
    keepExploring: 'Keep exploring',
    createAccount: 'Create my account',
  );

  static const fr = DemoStrings(
    bannerTitle: 'Mode démo',
    bannerMessage:
        'Tu explores des exemples. Rien de ce que tu fais ici ne touche tes '
        'propres données.',
    exit: 'Sortir du mode démo',
    exitTitle: 'Sortir du mode démo ?',
    exitMessage:
        'Les exemples et leur historique seront supprimés. Tes propres '
        'données restent.',
    cancel: 'Annuler',
    accountTitle: 'Cette action nécessite un compte',
    accountMessage:
        'Crée ton compte pour utiliser « {action} ». La démo reste telle '
        'quelle.',
    accountMessageAny:
        'Crée ton compte pour utiliser cette action. La démo reste telle '
        'quelle.',
    keepExploring: 'Continuer à explorer',
    createAccount: 'Créer mon compte',
  );

  /// The [DemoStringsScope] above [context]; without one, [fr] when the app
  /// locale is French, [en] otherwise.
  static DemoStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoStringsScope>()?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

  /// [accountMessage] for [action], [accountMessageAny] without one.
  String accountMessageFor(String? action) => action == null || action.isEmpty
      ? accountMessageAny
      : accountMessage.replaceAll('{action}', action);

  DemoStrings copyWith({
    String? bannerTitle,
    String? bannerMessage,
    String? exit,
    String? exitTitle,
    String? exitMessage,
    String? cancel,
    String? accountTitle,
    String? accountMessage,
    String? accountMessageAny,
    String? keepExploring,
    String? createAccount,
  }) => DemoStrings(
    bannerTitle: bannerTitle ?? this.bannerTitle,
    bannerMessage: bannerMessage ?? this.bannerMessage,
    exit: exit ?? this.exit,
    exitTitle: exitTitle ?? this.exitTitle,
    exitMessage: exitMessage ?? this.exitMessage,
    cancel: cancel ?? this.cancel,
    accountTitle: accountTitle ?? this.accountTitle,
    accountMessage: accountMessage ?? this.accountMessage,
    accountMessageAny: accountMessageAny ?? this.accountMessageAny,
    keepExploring: keepExploring ?? this.keepExploring,
    createAccount: createAccount ?? this.createAccount,
  );
}

/// Gives the demo surfaces below it the app's [strings].
class DemoStringsScope extends InheritedWidget {
  const DemoStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final DemoStrings strings;

  @override
  bool updateShouldNotify(DemoStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
