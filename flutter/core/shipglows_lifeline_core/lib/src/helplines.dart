/// A number a person can reach.
class LifelineContact {
  const LifelineContact({
    required this.number,
    required this.name,
    required this.detail,
    this.emergency = false,
    this.sms = false,
  });

  /// Number to dial, without spaces.
  final String number;

  /// Who answers.
  final String name;

  /// Who it is for, and when it answers.
  final String detail;

  /// Whether this is an emergency service: the only case for the danger color.
  final bool emergency;

  /// Whether it is reached by text message rather than by a call.
  final bool sms;
}

/// Helplines of France, in French. Checked on 2026-11-06.
///
/// Sources: service-public.gouv.fr/particuliers/vosdroits/F33954,
/// masecurite.interieur.gouv.fr, arretonslesviolences.gouv.fr/besoin-d-aide and
/// the « Aide à distance en santé » leaflet of Santé publique France.
abstract final class FrenchHelplines {
  /// European emergency number.
  static const emergency = LifelineContact(
    number: '112',
    name: 'Numéro d’urgence européen',
    detail: 'En cas de danger immédiat, à toute heure',
    emergency: true,
  );

  /// Police and gendarmerie.
  static const police = LifelineContact(
    number: '17',
    name: 'Police, gendarmerie',
    detail: 'Si quelqu’un te met en danger maintenant',
    emergency: true,
  );

  /// Emergency number by text message.
  static const emergencySms = LifelineContact(
    number: '114',
    name: 'Urgence par SMS',
    detail: 'Pour les personnes sourdes, malentendantes ou aphasiques',
    emergency: true,
    sms: true,
  );

  /// National suicide prevention line.
  static const suicidePrevention = LifelineContact(
    number: '3114',
    name: 'Numéro national de prévention du suicide',
    detail: 'Des professionnels te répondent. Gratuit, 24h/24, 7j/7',
  );

  /// Listening line run by volunteers.
  static const sosAmitie = LifelineContact(
    number: '0972394050',
    name: 'SOS Amitié',
    detail: 'Quelqu’un t’écoute. Anonyme, 24h/24, 7j/7',
  );

  /// For women facing violence, and those around them. Not an emergency service.
  static const violenceAgainstWomen = LifelineContact(
    number: '3919',
    name: 'Violences Femmes Info',
    detail:
        'Pour les femmes victimes de violences et leur entourage. Gratuit, anonyme, 24h/24, 7j/7',
  );

  /// For victims of any offence, whoever they are.
  static const victimSupport = LifelineContact(
    number: '116006',
    name: 'France Victimes',
    detail: 'Pour toute personne victime, de violences ou d’autre chose. 7j/7',
  );

  /// Drugs, alcohol and addictions.
  static const drugsInfo = LifelineContact(
    number: '0800231313',
    name: 'Drogues Info Service',
    detail: 'Sans jugement, pour parler de ta consommation. Gratuit, anonyme',
  );
}
