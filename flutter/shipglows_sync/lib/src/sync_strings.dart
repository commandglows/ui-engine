import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'sync_progress.dart';
import 'sync_status.dart';

/// Texts of the sync widgets. The app picks the language: use [fr], [en],
/// [forLocale], or its own values for other words ("données" instead of
/// "réglages"). `{count}`, `{time}` and `{date}` are replaced.
@immutable
class SyncStrings {
  const SyncStrings({
    required this.localOnly,
    required this.synced,
    required this.pending,
    required this.syncing,
    required this.needsReview,
    required this.unreachable,
    required this.failed,
    required this.signInAgain,
    required this.lastSynced,
    required this.bannerNeedsReview,
    required this.bannerUnreachable,
    required this.bannerOffline,
    required this.bannerFailed,
    required this.bannerSignIn,
    required this.retry,
    required this.signIn,
    required this.compare,
    required this.reviewTitle,
    required this.reviewDescription,
    required this.reviewUnion,
    required this.reviewRecovery,
    required this.reviewNoConflicts,
    required this.reviewConflicts,
    required this.allDevice,
    required this.allAccount,
    required this.device,
    required this.account,
    required this.confirm,
    required this.stayLocal,
    required this.incomplete,
    required this.reviewChanged,
    required this.reviewFailed,
    required this.empty,
    required this.enabled,
    required this.disabled,
    required this.progressKicker,
    required this.progressDoneKicker,
    required this.stageTitles,
    required this.stageMessages,
    required this.stageSteps,
    required this.close,
    required this.recoveryTitle,
    required this.recoverySavedOn,
    required this.recoveryConfirmed,
    required this.recoveryInterrupted,
    required this.restoreDevice,
    required this.restoreAccount,
    required this.restoreWarning,
    required this.restore,
    required this.restored,
    required this.restoreFailed,
    required this.dropRecovery,
    required this.cancel,
    this.formatTime,
  });

  // Status chip.
  final String localOnly;
  final String synced;
  final String pending;
  final String syncing;
  final String needsReview;
  final String unreachable;
  final String failed;
  final String signInAgain;

  /// `{time}`.
  final String lastSynced;

  // Issue banner.
  final String bannerNeedsReview;
  final String bannerUnreachable;

  /// `{count}` changes waiting.
  final String bannerOffline;
  final String bannerFailed;
  final String bannerSignIn;
  final String retry;
  final String signIn;
  final String compare;

  // Review dialog.
  final String reviewTitle;
  final String reviewDescription;
  final String reviewUnion;
  final String reviewRecovery;
  final String reviewNoConflicts;

  /// `{count}`.
  final String reviewConflicts;
  final String allDevice;
  final String allAccount;
  final String device;
  final String account;
  final String confirm;
  final String stayLocal;
  final String incomplete;
  final String reviewChanged;
  final String reviewFailed;
  final String empty;
  final String enabled;
  final String disabled;

  // First-sync progress.
  final String progressKicker;
  final String progressDoneKicker;
  final Map<SyncStage, String> stageTitles;
  final Map<SyncStage, String> stageMessages;

  /// Step list labels (the [SyncStage.ready] entry is unused).
  final Map<SyncStage, String> stageSteps;
  final String close;

  // Recovery copies.
  final String recoveryTitle;

  /// `{date}`.
  final String recoverySavedOn;
  final String recoveryConfirmed;
  final String recoveryInterrupted;
  final String restoreDevice;
  final String restoreAccount;
  final String restoreWarning;
  final String restore;
  final String restored;
  final String restoreFailed;
  final String dropRecovery;
  final String cancel;

  /// Date and time in these strings' language; `null` uses the app's
  /// `MaterialLocalizations` (English when the app declares no locale).
  final String Function(DateTime value)? formatTime;

  /// Chip label of [status].
  String statusLabel(SyncStatus status) => switch (status.health) {
    SyncHealth.localOnly => localOnly,
    SyncHealth.synced => synced,
    SyncHealth.pending => pending,
    SyncHealth.syncing => syncing,
    SyncHealth.needsReview => needsReview,
    SyncHealth.unreachable => unreachable,
    SyncHealth.failed =>
      status.issue?.retryable == false ? signInAgain : failed,
  };

  static const fr = SyncStrings(
    localOnly: 'Sur cet appareil',
    synced: 'Synchronisé',
    pending: 'En attente de synchro',
    syncing: 'Synchronisation…',
    needsReview: 'Choix à faire',
    unreachable: 'Compte injoignable',
    failed: 'Synchro impossible',
    signInAgain: 'Reconnectez-vous pour synchroniser',
    lastSynced: 'Dernière synchro : {time}',
    bannerNeedsReview:
        'Cet appareil et votre compte ne contiennent pas les mêmes réglages. '
        'Choisissez lesquels garder pour activer la synchronisation.',
    bannerUnreachable:
        'Impossible de joindre votre compte. Les réglages affichés sont ceux '
        'de cet appareil ; un nouvel essai se fera tout seul.',
    bannerOffline:
        'Hors ligne : {count} modification(s) en attente, envoyée(s) dès le '
        'retour du réseau.',
    bannerFailed:
        'La synchronisation a échoué. Vos modifications restent sur cet '
        'appareil.',
    bannerSignIn:
        'Votre session a expiré. Reconnectez-vous pour reprendre la '
        'synchronisation.',
    retry: 'Réessayer',
    signIn: 'Se reconnecter',
    compare: 'Comparer',
    reviewTitle: 'Choisir avant de synchroniser',
    reviewDescription:
        'Comparez les réglages de cet appareil avec ceux de votre compte.',
    reviewUnion:
        'Ce qui n’existe que d’un côté est gardé. Pour chaque différence, '
        'choisissez la version à garder.',
    reviewRecovery:
        'Les deux versions de départ restent enregistrées sur cet appareil : '
        'vous pourrez revenir en arrière.',
    reviewNoConflicts:
        'Aucune différence ne demande de choix. Confirmez pour activer la '
        'synchronisation.',
    reviewConflicts: '{count} différence(s) à choisir.',
    allDevice: 'Garder l’appareil partout',
    allAccount: 'Garder le compte partout',
    device: 'Sur cet appareil',
    account: 'Dans mon compte',
    confirm: 'Confirmer et synchroniser',
    stayLocal: 'Rester en local',
    incomplete: 'Choisissez une version pour chaque différence.',
    reviewChanged:
        'Des réglages ont changé depuis la comparaison. Vérifiez la nouvelle '
        'comparaison avant de confirmer.',
    reviewFailed:
        'La synchronisation n’a pas abouti. Rien n’a été modifié ; '
        'réessayez.',
    empty: 'Aucun',
    enabled: 'Activé',
    disabled: 'Désactivé',
    progressKicker: 'Synchronisation du compte',
    progressDoneKicker: 'Synchronisation terminée',
    stageTitles: {
      SyncStage.waitingServer: 'Connexion au cloud',
      SyncStage.dataReceived: 'Données reçues',
      SyncStage.dataApplied: 'Données appliquées',
      SyncStage.ready: 'Données synchronisées',
    },
    stageMessages: {
      SyncStage.waitingServer:
          'On récupère les données de votre compte pour mettre l’application '
          'dans le bon état.',
      SyncStage.dataReceived:
          'Les données de votre compte viennent d’arriver depuis le cloud.',
      SyncStage.dataApplied:
          'Vos réglages synchronisés sont appliqués à l’application.',
      SyncStage.ready:
          'Vos données synchronisées sont en place sur cet appareil.',
    },
    stageSteps: {
      SyncStage.waitingServer: 'Récupération des données du compte',
      SyncStage.dataReceived: 'Données reçues',
      SyncStage.dataApplied: 'Données appliquées',
      SyncStage.ready: 'Prêt',
    },
    close: 'Continuer',
    recoveryTitle: 'Copies avant synchronisation',
    recoverySavedOn: 'Enregistrées le {date}.',
    recoveryConfirmed: 'La synchronisation choisie a abouti.',
    recoveryInterrupted:
        'La synchronisation choisie n’est pas encore arrivée dans votre '
        'compte.',
    restoreDevice: 'Restaurer la copie de cet appareil',
    restoreAccount: 'Restaurer la copie du compte',
    restoreWarning:
        'Cette copie remplacera les réglages actuels, ici et dans votre '
        'compte.',
    restore: 'Restaurer',
    restored: 'Copie restaurée.',
    restoreFailed: 'La copie n’a pas pu être restaurée.',
    dropRecovery: 'Supprimer les copies',
    cancel: 'Annuler',
    formatTime: _frenchTime,
  );

  static const en = SyncStrings(
    localOnly: 'On this device',
    synced: 'Synced',
    pending: 'Waiting to sync',
    syncing: 'Syncing…',
    needsReview: 'Choice needed',
    unreachable: 'Account unreachable',
    failed: 'Sync failed',
    signInAgain: 'Sign in again to sync',
    lastSynced: 'Last synced: {time}',
    bannerNeedsReview:
        'This device and your account hold different settings. Choose which '
        'to keep to turn sync on.',
    bannerUnreachable:
        'Your account cannot be reached. The settings shown are this '
        'device’s; it will try again on its own.',
    bannerOffline:
        'Offline: {count} change(s) waiting, sent as soon as the network is '
        'back.',
    bannerFailed: 'Sync failed. Your changes stay on this device.',
    bannerSignIn: 'Your session expired. Sign in again to resume syncing.',
    retry: 'Try again',
    signIn: 'Sign in',
    compare: 'Compare',
    reviewTitle: 'Choose before syncing',
    reviewDescription:
        'Compare the settings on this device with those in your account.',
    reviewUnion:
        'Anything found on one side only is kept. For each difference, choose '
        'the version to keep.',
    reviewRecovery:
        'Both starting versions stay saved on this device, so you can go '
        'back.',
    reviewNoConflicts:
        'No difference needs a choice. Confirm to turn sync on.',
    reviewConflicts: '{count} difference(s) to choose.',
    allDevice: 'Keep this device for all',
    allAccount: 'Keep my account for all',
    device: 'On this device',
    account: 'In my account',
    confirm: 'Confirm and sync',
    stayLocal: 'Stay local',
    incomplete: 'Choose a version for each difference.',
    reviewChanged:
        'Settings changed since the comparison. Check the new comparison '
        'before confirming.',
    reviewFailed: 'Sync did not go through. Nothing was changed; try again.',
    empty: 'None',
    enabled: 'On',
    disabled: 'Off',
    progressKicker: 'Syncing your account',
    progressDoneKicker: 'Sync complete',
    stageTitles: {
      SyncStage.waitingServer: 'Reaching the cloud',
      SyncStage.dataReceived: 'Data received',
      SyncStage.dataApplied: 'Data applied',
      SyncStage.ready: 'Data synced',
    },
    stageMessages: {
      SyncStage.waitingServer:
          'Fetching your account data to set the app up correctly.',
      SyncStage.dataReceived: 'Your account data just arrived from the cloud.',
      SyncStage.dataApplied: 'Your synced settings are applied to the app.',
      SyncStage.ready: 'Your synced data is in place on this device.',
    },
    stageSteps: {
      SyncStage.waitingServer: 'Fetching account data',
      SyncStage.dataReceived: 'Data received',
      SyncStage.dataApplied: 'Data applied',
      SyncStage.ready: 'Ready',
    },
    close: 'Continue',
    recoveryTitle: 'Copies from before sync',
    recoverySavedOn: 'Saved on {date}.',
    recoveryConfirmed: 'The chosen sync went through.',
    recoveryInterrupted: 'The chosen sync has not reached your account yet.',
    restoreDevice: 'Restore this device’s copy',
    restoreAccount: 'Restore the account’s copy',
    restoreWarning:
        'This copy will replace the current settings, here and in your '
        'account.',
    restore: 'Restore',
    restored: 'Copy restored.',
    restoreFailed: 'The copy could not be restored.',
    dropRecovery: 'Delete the copies',
    cancel: 'Cancel',
  );

  static SyncStrings forLocale(Locale locale) =>
      locale.languageCode == 'fr' ? fr : en;
}

/// `23/10/2026 13:52`, local time.
String _frenchTime(DateTime value) {
  final t = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}
