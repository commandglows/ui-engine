/// How much each `shipglows_feelings` word counts. An editorial judgement, not a
/// validated instrument: have it reviewed by a clinician before release.
const Map<String, int> feelingWeights = {
  // Strong: one word is enough to offer help.
  'despair': 5,
  'danger': 5,
  'terror': 5,

  // Heavy.
  'emptiness': 3,
  'at_my_limit': 3,
  'numbness': 3,
  'worthlessness': 3,
  'self_disgust': 3,
  'trapped': 3,
  'panic': 3,
  'stunned': 3,
  'resignation': 3,
  'powerlessness': 3,

  // Weighing.
  'low_mood': 2,
  'exhaustion': 2,
  'overwhelmed': 2,
  'discouragement': 2,
  'dejection': 2,
  'abandonment': 2,
  'rejection': 2,
  'isolation': 2,
  'anguish': 2,
  'fear': 2,
  'unreality': 2,
  'detachment': 2,
  'humiliation': 2,
  'inferiority': 2,
  'not_enough': 2,
  'insecurity': 2,
  'on_guard': 2,

  // Light: they only count when they add up.
  'sadness': 1,
  'sorrow': 1,
  'hurt': 1,
  'grief': 1,
  'heartbreak': 1,
  'wound': 1,
  'loneliness': 1,
  'misunderstood': 1,
  'invisible': 1,
  'shame': 1,
  'guilt': 1,
  'anxiety': 1,
  'worry': 1,
  'urge_cry': 1,
  'urge_flee': 1,
  'urge_hide': 1,
  'chest_weight': 1,
  'short_breath': 1,
  'racing_heart': 1,
  'tight_throat': 1,
  'knot_stomach': 1,
  'trembling': 1,
  'lost_appetite': 1,
  'restless_sleep': 1,
};

/// The weight of a feeling word; 0 for a word that is not listed.
int feelingWeight(String id) => feelingWeights[id] ?? 0;
