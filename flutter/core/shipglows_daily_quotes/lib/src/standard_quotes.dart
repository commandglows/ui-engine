import 'daily_quote.dart';

const _ambition = QuoteContext.ambition;
const _recovery = QuoteContext.recovery;
const _relationships = QuoteContext.relationships;

/// Every quote of the bank. Ids are stored by apps: never rename or reuse one.
const List<DailyQuote> standardQuotes = [
  // Long-term goals.
  DailyQuote('next_step', 'Un grand projet ne demande aujourd’hui qu’un seul pas.', 'A big plan only asks one step of you today.', {_ambition}),
  DailyQuote('small_counts', 'Un petit pas fait vaut mieux qu’un grand pas imaginé.', 'A small step taken beats a big one imagined.', {_ambition}),
  DailyQuote('clear_action', 'Quand tout paraît flou, cherche la plus petite action possible.', 'When everything feels blurry, look for the smallest possible action.', {_ambition}),
  DailyQuote('dream_calendar', 'Un rêve devient réel le jour où il trouve une place dans l’agenda.', 'A dream gets real the day it finds room in your calendar.', {_ambition}),
  DailyQuote('slow_progress', 'Avancer lentement, c’est quand même avancer.', 'Moving slowly is still moving.', {_ambition}),
  DailyQuote('adjust_route', 'Changer de chemin n’est pas renoncer au but.', 'Changing the route is not giving up the goal.', {_ambition}),
  DailyQuote('finish_small', 'Finir une petite chose donne l’élan pour la suivante.', 'Finishing one small thing gives momentum for the next.', {_ambition}),
  DailyQuote('rest_part', 'Le repos fait partie du chemin.', 'Rest is part of the road.', {_ambition, _recovery}),

  // Regaining control.
  DailyQuote('own_pace', 'Ton rythme est le bon rythme.', 'Your pace is the right pace.', {_recovery}),
  DailyQuote('lapse_road', 'Un écart n’efface pas le chemin parcouru.', 'A lapse does not erase the road travelled.', {_recovery}),
  DailyQuote('urge_passes', 'Une envie monte, puis elle redescend.', 'An urge rises, then it falls.', {_recovery}),
  DailyQuote('today_only', 'Aujourd’hui est le seul jour à traverser.', 'Today is the only day to get through.', {_recovery}),
  DailyQuote('ask_help', 'Demander de l’aide, c’est déjà reprendre la main.', 'Asking for help is already taking back control.', {_recovery}),
  DailyQuote('curious_not_harsh', 'Regarde ce qui s’est passé avec curiosité, pas avec dureté.', 'Look at what happened with curiosity, not harshness.', {_recovery}),
  DailyQuote('each_choice', 'Chaque choix compte, même le plus petit.', 'Every choice counts, even the smallest.', {_recovery}),
  DailyQuote('more_than_habit', 'Tu es bien plus qu’une habitude.', 'You are far more than a habit.', {_recovery}),

  // Relationships and wellbeing.
  DailyQuote('feelings_count', 'Ce que tu ressens compte.', 'What you feel matters.', {_relationships}),
  DailyQuote('deserve_respect', 'Le respect n’a pas à se mériter.', 'Respect is not something you have to earn.', {_relationships}),
  DailyQuote('own_rhythm', 'Tu peux avancer à ton rythme, et en parler quand tu veux.', 'You can move at your own pace, and talk about it when you choose.', {_relationships}),
  DailyQuote('no_is_answer', 'Non est une réponse complète.', 'No is a complete answer.', {_relationships}),
  DailyQuote('safety_first', 'Ta sécurité passe avant tout le reste.', 'Your safety comes before everything else.', {_relationships}),
  DailyQuote('not_alone', 'Tu n’as pas à porter ça sans personne.', 'You do not have to carry this with no one.', {_relationships, _recovery}),
  DailyQuote('own_actions', 'Chacun répond de ses propres actes.', 'Everyone answers for their own actions.', {_relationships}),
  DailyQuote('change_with_help', 'Changer sa façon d’agir s’apprend, et cela commence par demander de l’aide.', 'Changing how you act can be learned, and it starts by asking for help.', {_relationships, _recovery}),
  DailyQuote('kind_to_self', 'Parle-toi comme à une personne que tu aimes.', 'Speak to yourself as you would to someone you love.', {_relationships, _recovery, _ambition}),
  DailyQuote('breathe_first', 'Une respiration d’abord. Le reste ensuite.', 'One breath first. The rest after.', {_relationships, _recovery, _ambition}),

  // Public domain authors. Translations are ours.
  DailyQuote('epictetus_control', 'Certaines choses dépendent de nous, d’autres non.', 'Some things are up to us, and some are not.', {_ambition, _recovery}, author: 'Épictète', source: 'Manuel, 1'),
  DailyQuote('marcus_obstacle', 'Ce qui fait obstacle à l’action fait avancer l’action.', 'What stands in the way of action advances action.', {_ambition}, author: 'Marc Aurèle', source: 'Pensées, V, 20'),
  DailyQuote('seneca_imagination', 'Nous souffrons plus souvent en imagination qu’en réalité.', 'We suffer more often in imagination than in reality.', {_ambition, _recovery}, author: 'Sénèque', source: 'Lettres à Lucilius, 13, 4'),
  DailyQuote('laozi_journey', 'Un voyage de mille lieues commence sous tes pieds.', 'A journey of a thousand miles begins beneath your feet.', {_ambition, _recovery}, author: 'Lao Tseu', source: 'Tao Te King, 64'),
];
