import 'deck.dart';

/// The standard questions. Ids never change once used.
const List<ReflectionQuestion> standardReflectionQuestions = [
  // Distance.
  ReflectionQuestion(
    'distance_loved_one',
    ReflectionLens.distance,
    'Si une personne que tu aimes vivait exactement ça, que lui dirais-tu ?',
    'If someone you love were living exactly this, what would you tell them?',
  ),
  ReflectionQuestion(
    'distance_ten_years',
    ReflectionLens.distance,
    'Dans dix ans, qu’aimerais-tu pouvoir dire de la façon dont tu as traversé cette période ?',
    'Ten years from now, what would you like to be able to say about how you went through this time?',
  ),
  ReflectionQuestion(
    'distance_third_person',
    ReflectionLens.distance,
    'Raconte ce moment en disant « il » ou « elle » à la place de « je ». Qu’est-ce que tu remarques ?',
    'Tell this moment saying “he” or “she” instead of “I”. What do you notice?',
  ),
  ReflectionQuestion(
    'distance_outside_eye',
    ReflectionLens.distance,
    'Si quelqu’un regardait ta semaine de l’extérieur, qu’est-ce qui le frapperait ?',
    'If someone looked at your week from the outside, what would strike them?',
  ),
  ReflectionQuestion(
    'distance_own_advice',
    ReflectionLens.distance,
    'Quel conseil donnes-tu souvent aux autres sans jamais te l’appliquer ?',
    'What advice do you often give others and never apply to yourself?',
  ),
  ReflectionQuestion(
    'distance_past_self',
    ReflectionLens.distance,
    'Que dirait de ta vie d’aujourd’hui la personne que tu étais il y a cinq ans ?',
    'What would the person you were five years ago say about your life today?',
  ),

  // Values.
  ReflectionQuestion(
    'values_unseen',
    ReflectionLens.whatMatters,
    'Qu’est-ce qui compte vraiment pour toi en ce moment, même si personne ne le voit ?',
    'What really matters to you right now, even if nobody sees it?',
  ),
  ReflectionQuestion(
    'values_no_one_to_convince',
    ReflectionLens.whatMatters,
    'Si tu n’avais personne à convaincre, que choisirais-tu pour toi ?',
    'If you had no one to convince, what would you choose for yourself?',
  ),
  ReflectionQuestion(
    'values_admire',
    ReflectionLens.whatMatters,
    'Quelle personne admires-tu, et qu’est-ce que ça dit de ce que tu veux pour toi ?',
    'Who do you admire, and what does that say about what you want for yourself?',
  ),
  ReflectionQuestion(
    'values_stopped_wanting',
    ReflectionLens.whatMatters,
    'Qu’est-ce que tu as arrêté de vouloir ? L’as-tu vraiment décidé ?',
    'What have you stopped wanting? Did you really decide that?',
  ),
  ReflectionQuestion(
    'values_time_spent',
    ReflectionLens.whatMatters,
    'À quoi ton temps est-il passé cette semaine ? Est-ce que ça ressemble à ce qui compte pour toi ?',
    'Where did your time go this week? Does it look like what matters to you?',
  ),

  // Beliefs about oneself.
  ReflectionQuestion(
    'belief_never_checked',
    ReflectionLens.belief,
    'Quelle idée sur toi tiens-tu pour vraie sans l’avoir jamais vérifiée ?',
    'What idea about yourself do you hold as true without ever having checked it?',
  ),
  ReflectionQuestion(
    'belief_learned_from',
    ReflectionLens.belief,
    'Quelle phrase sur toi répètes-tu sans savoir qui te l’a apprise ?',
    'What sentence about yourself do you repeat without knowing who taught it to you?',
  ),
  ReflectionQuestion(
    'belief_unchosen_rule',
    ReflectionLens.belief,
    'Quelle règle suis-tu sans jamais l’avoir choisie ?',
    'What rule do you follow without ever having chosen it?',
  ),
  ReflectionQuestion(
    'belief_not_for_me',
    ReflectionLens.belief,
    'De quoi te dis-tu « ce n’est pas pour moi » ? Qu’est-ce qui te le fait croire ?',
    'What do you call “not for me”? What makes you believe that?',
  ),
  ReflectionQuestion(
    'belief_old_self',
    ReflectionLens.belief,
    'Quelle image de toi est restée alors que tu as changé ?',
    'What image of yourself has stayed even though you have changed?',
  ),

  // Growth.
  ReflectionQuestion(
    'growth_three_years',
    ReflectionLens.growth,
    'Que sais-tu faire aujourd’hui que tu ne savais pas faire il y a trois ans ?',
    'What can you do today that you could not do three years ago?',
  ),
  ReflectionQuestion(
    'growth_crossed',
    ReflectionLens.growth,
    'Qu’est-ce qui t’a fait peur et que tu as quand même traversé ? Qu’en as-tu gardé ?',
    'What scared you that you went through anyway? What did you keep from it?',
  ),
  ReflectionQuestion(
    'growth_changed_mind',
    ReflectionLens.growth,
    'Sur quoi as-tu changé d’avis ces dernières années ? Qu’est-ce qui t’a fait changer ?',
    'What have you changed your mind about in recent years? What changed it?',
  ),
  ReflectionQuestion(
    'growth_try',
    ReflectionLens.growth,
    'Qu’est-ce que tu n’as jamais osé essayer et qui ne dépend que de toi ?',
    'What have you never dared to try that depends only on you?',
  ),
  ReflectionQuestion(
    'growth_learning',
    ReflectionLens.growth,
    'Qu’est-ce que tu es en train d’apprendre en ce moment, même sans l’avoir voulu ?',
    'What are you learning right now, even without having wanted to?',
  ),

  // Another point of view. See the README before offering these.
  ReflectionQuestion(
    'other_their_side',
    ReflectionLens.otherView,
    'Comment l’autre personne raconterait-elle ce moment ? Qu’est-ce que ça t’apprend ?',
    'How would the other person tell this moment? What does that teach you?',
  ),
  ReflectionQuestion(
    'other_disagree',
    ReflectionLens.otherView,
    'Qui n’est pas d’accord avec toi en ce moment ? Sur quel point cette personne pourrait-elle avoir raison ?',
    'Who disagrees with you right now? On what point might they be right?',
  ),

  // One's own part. See the README before offering these.
  ReflectionQuestion(
    'part_story',
    ReflectionLens.ownPart,
    'Quelle histoire te racontes-tu sur cette situation ? Qu’est-ce qui la contredit ?',
    'What story are you telling yourself about this situation? What contradicts it?',
  ),
  ReflectionQuestion(
    'part_repeat',
    ReflectionLens.ownPart,
    'Qu’est-ce qui se répète dans ta vie ? Quelle part de cela dépend de toi ?',
    'What keeps repeating in your life? What part of it depends on you?',
  ),
  ReflectionQuestion(
    'part_avoid',
    ReflectionLens.ownPart,
    'Qu’est-ce que tu évites de regarder en ce moment ?',
    'What are you avoiding looking at right now?',
  ),
  ReflectionQuestion(
    'part_yes_no',
    ReflectionLens.ownPart,
    'À quoi dis-tu oui alors que tu voudrais dire non ?',
    'What do you say yes to when you would like to say no?',
  ),
];
