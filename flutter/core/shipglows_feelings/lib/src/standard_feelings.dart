import 'feeling.dart';

const _joy = FeelingFamily.joy;
const _calm = FeelingFamily.calm;
const _strength = FeelingFamily.strength;
const _connection = FeelingFamily.connection;
const _curiosity = FeelingFamily.curiosity;
const _sadness = FeelingFamily.sadness;
const _fear = FeelingFamily.fear;
const _anger = FeelingFamily.anger;
const _shame = FeelingFamily.shame;
const _disgust = FeelingFamily.disgust;
const _confusion = FeelingFamily.confusion;
const _exhaustion = FeelingFamily.exhaustion;
const _loneliness = FeelingFamily.loneliness;
const _urges = FeelingFamily.urges;
const _body = FeelingFamily.body;

/// Every word of the bank. Ids are stored by apps: never rename or reuse one.
const List<Feeling> standardFeelings = [
  // Joy and pleasure.
  Feeling('joy', _joy, 'Joie', 'Joy', aliases: ['joyeux', 'joyeuse', 'heureux', 'heureuse', 'happy']),
  Feeling('happiness', _joy, 'Bonheur', 'Happiness', aliases: ['heureux', 'heureuse', 'happy']),
  Feeling('cheerfulness', _joy, 'Gaieté', 'Cheerfulness', aliases: ['gai', 'gaie', 'bonne humeur']),
  Feeling('pleasure', _joy, 'Plaisir', 'Pleasure'),
  Feeling('enthusiasm', _joy, 'Enthousiasme', 'Enthusiasm', aliases: ['enthousiaste', 'emballe', 'emballee']),
  Feeling('excitement', _joy, 'Excitation', 'Excitement', aliases: ['excite', 'excitee']),
  Feeling('amusement', _joy, 'Amusement', 'Amusement', aliases: ['amuse', 'amusee', 'rire', 'drole']),
  Feeling('awe', _joy, 'Émerveillement', 'Awe', aliases: ['emerveille', 'emerveillee', 'wonder']),
  Feeling('contentment', _joy, 'Contentement', 'Contentment', aliases: ['content', 'contente']),
  Feeling('satisfaction', _joy, 'Satisfaction', 'Satisfaction', aliases: ['satisfait', 'satisfaite']),
  Feeling('euphoria', _joy, 'Euphorie', 'Euphoria', aliases: ['euphorique']),
  Feeling('lightness', _joy, 'Légèreté', 'Lightness', aliases: ['leger', 'legere']),
  Feeling('carefree', _joy, 'Insouciance', 'Carefreeness', aliases: ['insouciant', 'insouciante']),
  Feeling('fulfilment', _joy, 'Épanouissement', 'Fulfilment', aliases: ['epanoui', 'epanouie', 'comble', 'comblee']),
  Feeling('delight', _joy, 'Ravissement', 'Delight', aliases: ['ravi', 'ravie', 'enchante', 'enchantee']),

  // Calm and safety.
  Feeling('calm', _calm, 'Calme', 'Calm', aliases: ['tranquille', 'paisible']),
  Feeling('serenity', _calm, 'Sérénité', 'Serenity', aliases: ['serein', 'sereine']),
  Feeling('soothing', _calm, 'Apaisement', 'Soothed', aliases: ['apaise', 'apaisee']),
  Feeling('relief', _calm, 'Soulagement', 'Relief', aliases: ['soulage', 'soulagee', 'delivre', 'delivree']),
  Feeling('safety', _calm, 'Sécurité', 'Safety', aliases: ['safe', 'protege', 'protegee', 'rassure', 'rassuree']),
  Feeling('relaxation', _calm, 'Détente', 'Relaxation', aliases: ['detendu', 'detendue', 'relax', 'relaxed']),
  Feeling('comfort', _calm, 'Réconfort', 'Comfort', aliases: ['reconforte', 'reconfortee']),
  Feeling('at_peace', _calm, 'En paix', 'At peace', aliases: ['paix']),
  Feeling('acceptance', _calm, 'Acceptation', 'Acceptance', aliases: ['accepter']),
  Feeling('letting_go', _calm, 'Lâcher-prise', 'Letting go'),
  Feeling('stability', _calm, 'Stabilité', 'Stability', aliases: ['stable', 'equilibre']),
  Feeling('grounded', _calm, 'Ancrage', 'Grounded', aliases: ['ancre', 'ancree', 'pose', 'posee']),
  Feeling('at_ease', _calm, 'À l’aise', 'At ease', aliases: ['aise']),
  Feeling('rest', _calm, 'Repos', 'Rested', aliases: ['repose', 'reposee']),

  // Strength and drive.
  Feeling('confidence', _strength, 'Confiance en moi', 'Self-confidence', aliases: ['sur de moi', 'sure de moi', 'assurance']),
  Feeling('pride', _strength, 'Fierté', 'Pride', aliases: ['fier', 'fiere', 'proud']),
  Feeling('courage', _strength, 'Courage', 'Courage', aliases: ['courageux', 'courageuse', 'brave']),
  Feeling('determination', _strength, 'Détermination', 'Determination', aliases: ['determine', 'determinee']),
  Feeling('inner_strength', _strength, 'Force intérieure', 'Inner strength', aliases: ['fort', 'forte', 'strong']),
  Feeling('dignity', _strength, 'Dignité', 'Dignity', aliases: ['digne', 'respect']),
  Feeling('freedom', _strength, 'Liberté', 'Freedom', aliases: ['libre', 'free']),
  Feeling('hope', _strength, 'Espoir', 'Hope', aliases: ['confiance en l avenir']),
  Feeling('optimism', _strength, 'Optimisme', 'Optimism', aliases: ['optimiste']),
  Feeling('momentum', _strength, 'Élan', 'Momentum', aliases: ['entrain']),
  Feeling('motivation', _strength, 'Motivation', 'Motivation', aliases: ['motive', 'motivee']),
  Feeling('clarity', _strength, 'Clarté', 'Clarity', aliases: ['lucide', 'lucidite', 'clair', 'claire']),
  Feeling('energy', _strength, 'Énergie', 'Energy', aliases: ['energique', 'pleine forme']),
  Feeling('accomplishment', _strength, 'Accomplissement', 'Accomplishment', aliases: ['reussite', 'victoire']),
  Feeling('in_my_place', _strength, 'À ma place', 'In my place', aliases: ['legitime', 'legitimite']),

  // Connection and tenderness.
  Feeling('tenderness', _connection, 'Tendresse', 'Tenderness', aliases: ['tendre']),
  Feeling('love', _connection, 'Amour', 'Love', aliases: ['amoureux', 'amoureuse', 'aimer']),
  Feeling('gratitude', _connection, 'Gratitude', 'Gratitude', aliases: ['reconnaissant', 'reconnaissante', 'merci', 'grateful']),
  Feeling('affection', _connection, 'Affection', 'Affection', aliases: ['affectueux', 'affectueuse']),
  Feeling('trust', _connection, 'Confiance', 'Trust', aliases: ['confiant', 'confiante']),
  Feeling('closeness', _connection, 'Complicité', 'Closeness', aliases: ['proche', 'complice']),
  Feeling('compassion', _connection, 'Compassion', 'Compassion'),
  Feeling('belonging', _connection, 'Appartenance', 'Belonging', aliases: ['accepte', 'acceptee', 'inclus', 'incluse']),
  Feeling('admiration', _connection, 'Admiration', 'Admiration'),
  Feeling('attachment', _connection, 'Attachement', 'Attachment', aliases: ['attache', 'attachee']),
  Feeling('empathy', _connection, 'Empathie', 'Empathy'),
  Feeling('warmth', _connection, 'Chaleur humaine', 'Warmth', aliases: ['chaleureux', 'chaleureuse']),
  Feeling('desire', _connection, 'Désir', 'Desire', aliases: ['attirance', 'attire', 'attiree']),
  Feeling('being_moved', _connection, 'Attendrissement', 'Being moved', aliases: ['emu', 'emue', 'touche', 'touchee', 'emotion']),

  // Curiosity and surprise.
  Feeling('curiosity', _curiosity, 'Curiosité', 'Curiosity', aliases: ['curieux', 'curieuse']),
  Feeling('interest', _curiosity, 'Intérêt', 'Interest', aliases: ['interesse', 'interessee']),
  Feeling('inspiration', _curiosity, 'Inspiration', 'Inspiration', aliases: ['inspire', 'inspiree']),
  Feeling('surprise', _curiosity, 'Surprise', 'Surprise', aliases: ['surpris', 'surprised']),
  Feeling('astonishment', _curiosity, 'Étonnement', 'Astonishment', aliases: ['etonne', 'etonnee']),
  Feeling('fascination', _curiosity, 'Fascination', 'Fascination', aliases: ['fascine', 'fascinee', 'captive', 'captivee']),
  Feeling('anticipation', _curiosity, 'Hâte', 'Anticipation', aliases: ['impatient de', 'attente']),
  Feeling('shock', _curiosity, 'Choc', 'Shock', aliases: ['choque', 'choquee']),

  // Sadness and hurt.
  Feeling('sadness', _sadness, 'Tristesse', 'Sadness', aliases: ['triste', 'sad']),
  Feeling('sorrow', _sadness, 'Chagrin', 'Sorrow', aliases: ['pleurer']),
  Feeling('hurt', _sadness, 'Peine', 'Hurt', aliases: ['peine', 'peinee', 'mal']),
  Feeling('melancholy', _sadness, 'Mélancolie', 'Melancholy', aliases: ['melancolique', 'cafard', 'spleen']),
  Feeling('nostalgia', _sadness, 'Nostalgie', 'Nostalgia', aliases: ['nostalgique']),
  Feeling('disappointment', _sadness, 'Déception', 'Disappointment', aliases: ['decu', 'decue', 'disappointed']),
  Feeling('despair', _sadness, 'Désespoir', 'Despair', aliases: ['desespere', 'desesperee']),
  Feeling('discouragement', _sadness, 'Découragement', 'Discouragement', aliases: ['decourage', 'decouragee', 'demoralise', 'demoralisee']),
  Feeling('dejection', _sadness, 'Abattement', 'Dejection', aliases: ['abattu', 'abattue', 'accable', 'accablee']),
  Feeling('regret', _sadness, 'Regret', 'Regret', aliases: ['regretter']),
  Feeling('grief', _sadness, 'Deuil', 'Grief', aliases: ['perte']),
  Feeling('low_mood', _sadness, 'Déprime', 'Low mood', aliases: ['deprime', 'deprimee', 'down', 'pas le moral', 'moral a zero']),
  Feeling('heartbreak', _sadness, 'Cœur brisé', 'Heartbreak', aliases: ['rupture', 'coeur']),
  Feeling('gloom', _sadness, 'Morosité', 'Gloom', aliases: ['morose', 'maussade', 'sombre']),
  Feeling('resignation', _sadness, 'Résignation', 'Resignation', aliases: ['resigne', 'resignee']),
  Feeling('wound', _sadness, 'Blessure', 'Feeling wounded', aliases: ['blesse', 'blessee']),

  // Fear and worry.
  Feeling('fear', _fear, 'Peur', 'Fear', aliases: ['effraye', 'effrayee', 'scared', 'afraid', 'flipper', 'trouille']),
  Feeling('worry', _fear, 'Inquiétude', 'Worry', aliases: ['inquiet', 'inquiete', 'soucieux', 'soucieuse', 'souci']),
  Feeling('anxiety', _fear, 'Anxiété', 'Anxiety', aliases: ['anxieux', 'anxieuse', 'anxious']),
  Feeling('anguish', _fear, 'Angoisse', 'Anguish', aliases: ['angoisse', 'angoissee']),
  Feeling('panic', _fear, 'Panique', 'Panic', aliases: ['paniquer', 'affole', 'affolee']),
  Feeling('terror', _fear, 'Terreur', 'Terror', aliases: ['terrifie', 'terrifiee', 'terrorise', 'terrorisee']),
  Feeling('dread', _fear, 'Effroi', 'Dread'),
  Feeling('stunned', _fear, 'Sidération', 'Frozen', aliases: ['sidere', 'sideree', 'fige', 'figee', 'paralyse', 'paralysee', 'tetanise']),
  Feeling('apprehension', _fear, 'Appréhension', 'Apprehension', aliases: ['apprehender']),
  Feeling('stress', _fear, 'Stress', 'Stress', aliases: ['stresse', 'stressee', 'stressed']),
  Feeling('tension', _fear, 'Tension', 'Tension', aliases: ['tendu', 'tendue', 'crispe', 'crispee']),
  Feeling('insecurity', _fear, 'Insécurité', 'Insecurity', aliases: ['pas en securite']),
  Feeling('on_guard', _fear, 'Sur mes gardes', 'On my guard', aliases: ['qui-vive', 'vigilance', 'mefiance', 'mefiant', 'mefiante']),
  Feeling('danger', _fear, 'Sentiment de danger', 'Sense of danger', aliases: ['menace', 'menacee']),
  Feeling('powerlessness', _fear, 'Impuissance', 'Powerlessness', aliases: ['impuissant', 'impuissante', 'demuni', 'demunie', 'helpless']),
  Feeling('nervousness', _fear, 'Nervosité', 'Nervousness', aliases: ['nerveux', 'nerveuse', 'nervous']),
  Feeling('trapped', _fear, 'Enfermement', 'Feeling trapped', aliases: ['piege', 'piegee', 'coince', 'coincee', 'etouffer']),

  // Anger and annoyance.
  Feeling('anger', _anger, 'Colère', 'Anger', aliases: ['fache', 'fachee', 'en colere', 'angry', 'enerve', 'enervee']),
  Feeling('rage', _anger, 'Rage', 'Rage', aliases: ['furieux', 'furieuse', 'fureur', 'enrage', 'enragee']),
  Feeling('irritation', _anger, 'Irritation', 'Irritation', aliases: ['irrite', 'irritee', 'a cran']),
  Feeling('annoyance', _anger, 'Agacement', 'Annoyance', aliases: ['agace', 'agacee', 'contrarie', 'contrariee', 'annoyed']),
  Feeling('frustration', _anger, 'Frustration', 'Frustration', aliases: ['frustre', 'frustree', 'frustrated']),
  Feeling('exasperation', _anger, 'Exaspération', 'Exasperation', aliases: ['exaspere', 'exasperee', 'excede', 'excedee', 'ras-le-bol']),
  Feeling('resentment', _anger, 'Ressentiment', 'Resentment', aliases: ['rancune', 'rancoeur']),
  Feeling('bitterness', _anger, 'Amertume', 'Bitterness', aliases: ['amer', 'amere', 'aigri', 'aigrie']),
  Feeling('indignation', _anger, 'Indignation', 'Indignation', aliases: ['indigne', 'indignee', 'revolte', 'revoltee']),
  Feeling('injustice', _anger, 'Sentiment d’injustice', 'Sense of injustice', aliases: ['injuste', 'unfair']),
  Feeling('jealousy', _anger, 'Jalousie', 'Jealousy', aliases: ['jaloux', 'jalouse', 'envieux', 'envieuse']),
  Feeling('hostility', _anger, 'Hostilité', 'Hostility', aliases: ['hostile']),
  Feeling('impatience', _anger, 'Impatience', 'Impatience', aliases: ['impatient', 'impatiente']),
  Feeling('beside_myself', _anger, 'Hors de moi', 'Beside myself'),
  Feeling('hatred', _anger, 'Haine', 'Hatred', aliases: ['hate', 'detester']),
  Feeling('betrayal', _anger, 'Trahison', 'Betrayal', aliases: ['trahi', 'trahie', 'betrayed']),

  // Shame and guilt.
  Feeling('shame', _shame, 'Honte', 'Shame', aliases: ['honteux', 'honteuse', 'ashamed']),
  Feeling('guilt', _shame, 'Culpabilité', 'Guilt', aliases: ['coupable', 'culpabiliser', 'guilty']),
  Feeling('embarrassment', _shame, 'Gêne', 'Embarrassment', aliases: ['gene', 'genee', 'embarrasse', 'embarrassee']),
  Feeling('humiliation', _shame, 'Humiliation', 'Humiliation', aliases: ['humilie', 'humiliee']),
  Feeling('remorse', _shame, 'Remords', 'Remorse'),
  Feeling('worthlessness', _shame, 'Dévalorisation', 'Feeling worthless', aliases: ['nul', 'nulle', 'minable', 'rabaisse', 'rabaissee']),
  Feeling('inferiority', _shame, 'Sentiment d’infériorité', 'Feeling inferior', aliases: ['inferieur', 'inferieure', 'moins bien']),
  Feeling('self_disgust', _shame, 'Dégoût de moi', 'Disgust with myself'),
  Feeling('shyness', _shame, 'Timidité', 'Shyness', aliases: ['timide', 'shy']),
  Feeling('vulnerability', _shame, 'Vulnérabilité', 'Vulnerability', aliases: ['vulnerable', 'fragile', 'fragilite', 'a fleur de peau']),
  Feeling('self_doubt', _shame, 'Manque de confiance en moi', 'Self-doubt'),
  Feeling('not_enough', _shame, 'Pas à la hauteur', 'Not good enough', aliases: ['hauteur', 'incapable', 'imposteur']),
  Feeling('ill_at_ease', _shame, 'Malaise', 'Ill at ease', aliases: ['mal a l aise', 'inconfort']),

  // Disgust and aversion.
  Feeling('disgust', _disgust, 'Dégoût', 'Disgust', aliases: ['degoute', 'degoutee', 'disgusted']),
  Feeling('repulsion', _disgust, 'Répulsion', 'Repulsion', aliases: ['repugnance']),
  Feeling('contempt', _disgust, 'Mépris', 'Contempt', aliases: ['meprisant', 'meprisante']),
  Feeling('sickened', _disgust, 'Écœurement', 'Sickened', aliases: ['ecoeure', 'ecoeuree']),
  Feeling('aversion', _disgust, 'Aversion', 'Aversion', aliases: ['animosite']),

  // Confusion and doubt.
  Feeling('confusion', _confusion, 'Confusion', 'Confusion', aliases: ['confus', 'confuse', 'confused', 'deboussole', 'deboussolee']),
  Feeling('lost', _confusion, 'Perte de repères', 'Feeling lost', aliases: ['perdu', 'perdue', 'desoriente', 'desorientee']),
  Feeling('doubt', _confusion, 'Doute', 'Doubt', aliases: ['douter', 'sceptique', 'hesitation']),
  Feeling('ambivalence', _confusion, 'Ambivalence', 'Ambivalence', aliases: ['ambivalent', 'ambivalente']),
  Feeling('perplexity', _confusion, 'Perplexité', 'Perplexity', aliases: ['perplexe']),
  Feeling('indecision', _confusion, 'Indécision', 'Indecision', aliases: ['indecis', 'indecise']),
  Feeling('unreality', _confusion, 'Impression d’irréalité', 'Feeling unreal', aliases: ['irreel', 'pas reel', 'a cote de moi']),
  Feeling('detachment', _confusion, 'Détachement', 'Detachment', aliases: ['detache', 'detachee', 'deconnecte', 'deconnectee', 'ailleurs']),
  Feeling('torn', _confusion, 'Tiraillement', 'Feeling torn', aliases: ['tiraille', 'tiraillee', 'dechire', 'dechiree']),
  Feeling('bewilderment', _confusion, 'Désarroi', 'Bewilderment', aliases: ['desempare', 'desemparee', 'deroute', 'deroutee']),
  Feeling('mixed_feelings', _confusion, 'Sentiments mêlés', 'Mixed feelings', aliases: ['mitige', 'mitigee', 'partage', 'partagee']),
  Feeling('foggy', _confusion, 'Tête dans le brouillard', 'Foggy', aliases: ['brouillard', 'embrouille', 'embrouillee']),

  // Tiredness and emptiness.
  Feeling('fatigue', _exhaustion, 'Fatigue', 'Tiredness', aliases: ['fatigue', 'fatiguee', 'tired']),
  Feeling('exhaustion', _exhaustion, 'Épuisement', 'Exhaustion', aliases: ['epuise', 'epuisee', 'vide', 'vidée', 'exhausted', 'burnout']),
  Feeling('weariness', _exhaustion, 'Lassitude', 'Weariness', aliases: ['las', 'lasse', 'marre']),
  Feeling('boredom', _exhaustion, 'Ennui', 'Boredom', aliases: ['ennuye', 'ennuyee', 'bored']),
  Feeling('emptiness', _exhaustion, 'Vide', 'Emptiness', aliases: ['empty', 'creux']),
  Feeling('numbness', _exhaustion, 'Engourdissement', 'Numbness', aliases: ['engourdi', 'engourdie', 'anesthesie', 'anesthesiee', 'plus rien', 'numb']),
  Feeling('indifference', _exhaustion, 'Indifférence', 'Indifference', aliases: ['indifferent', 'indifferente', 'blase', 'blasee']),
  Feeling('no_drive', _exhaustion, 'Sans envie', 'No drive', aliases: ['flemme', 'demotive', 'demotivee', 'apathie']),
  Feeling('at_my_limit', _exhaustion, 'À bout', 'At my limit', aliases: ['bout', 'rouleau', 'craquer', 'effondre', 'effondree']),
  Feeling('under_pressure', _exhaustion, 'Sous pression', 'Under pressure', aliases: ['pression', 'charge mentale']),
  Feeling('overwhelmed', _exhaustion, 'Débordement', 'Overwhelmed', aliases: ['deborde', 'debordee', 'submerge', 'submergee', 'depasse', 'depassee']),
  Feeling('heaviness', _exhaustion, 'Lourdeur', 'Heaviness', aliases: ['lourd', 'lourde']),

  // Loneliness and missing.
  Feeling('loneliness', _loneliness, 'Solitude', 'Loneliness', aliases: ['seul', 'seule', 'lonely', 'alone']),
  Feeling('isolation', _loneliness, 'Isolement', 'Isolation', aliases: ['isole', 'isolee', 'isolated']),
  Feeling('abandonment', _loneliness, 'Abandon', 'Abandonment', aliases: ['abandonne', 'abandonnee']),
  Feeling('rejection', _loneliness, 'Rejet', 'Rejection', aliases: ['rejete', 'rejetee', 'rejected']),
  Feeling('misunderstood', _loneliness, 'Incompréhension', 'Feeling misunderstood', aliases: ['incompris', 'incomprise', 'pas ecoute', 'pas ecoutee']),
  Feeling('exclusion', _loneliness, 'Exclusion', 'Exclusion', aliases: ['exclu', 'exclue', 'mis de cote']),
  Feeling('missing_someone', _loneliness, 'Manque de quelqu’un', 'Missing someone', aliases: ['absence', 'miss']),
  Feeling('homesickness', _loneliness, 'Mal du pays', 'Homesickness'),
  Feeling('invisible', _loneliness, 'Sentiment d’être invisible', 'Feeling invisible', aliases: ['ignore', 'ignoree', 'transparent']),

  // What I feel like doing.
  Feeling('urge_cry', _urges, 'Envie de pleurer', 'Urge to cry', aliases: ['larmes']),
  Feeling('urge_flee', _urges, 'Envie de fuir', 'Urge to run away', aliases: ['partir', 'fuite']),
  Feeling('urge_shout', _urges, 'Envie de crier', 'Urge to shout', aliases: ['hurler']),
  Feeling('urge_hide', _urges, 'Envie de me cacher', 'Urge to hide', aliases: ['cacher', 'repli']),
  Feeling('urge_break', _urges, 'Envie de tout casser', 'Urge to smash things', aliases: ['frapper', 'casser']),
  Feeling('urge_people', _urges, 'Envie de voir du monde', 'Urge to see people', aliases: ['sortir', 'amis']),
  Feeling('urge_quiet', _urges, 'Envie d’être au calme', 'Urge for quiet', aliases: ['tranquillite']),
  Feeling('urge_move', _urges, 'Envie de bouger', 'Urge to move', aliases: ['sport', 'marcher']),
  Feeling('urge_sleep', _urges, 'Envie de dormir', 'Urge to sleep', aliases: ['sommeil']),
  Feeling('urge_talk', _urges, 'Envie d’en parler', 'Urge to talk', aliases: ['parler', 'confier']),
  Feeling('craving', _urges, 'Envie irrésistible', 'Craving', aliases: ['besoin', 'compulsion', 'pulsion']),
  Feeling('lack', _urges, 'Sensation de manque', 'Withdrawal', aliases: ['manque', 'sevrage']),

  // In my body.
  Feeling('tight_throat', _body, 'Gorge serrée', 'Tight throat', aliases: ['gorge', 'noeud']),
  Feeling('knot_stomach', _body, 'Boule au ventre', 'Knot in my stomach', aliases: ['ventre', 'estomac', 'stomach']),
  Feeling('racing_heart', _body, 'Cœur qui s’emballe', 'Racing heart', aliases: ['coeur', 'palpitations', 'heart']),
  Feeling('short_breath', _body, 'Souffle court', 'Short of breath', aliases: ['respiration', 'respirer', 'etouffer', 'breath']),
  Feeling('chest_weight', _body, 'Poids sur la poitrine', 'Weight on my chest', aliases: ['poitrine', 'oppression', 'chest']),
  Feeling('clenched_jaw', _body, 'Mâchoire serrée', 'Clenched jaw', aliases: ['machoire', 'dents']),
  Feeling('heavy_shoulders', _body, 'Épaules lourdes', 'Heavy shoulders', aliases: ['epaules', 'dos', 'nuque']),
  Feeling('trembling', _body, 'Tremblements', 'Trembling', aliases: ['trembler', 'shaking']),
  Feeling('sweaty_hands', _body, 'Mains moites', 'Sweaty hands', aliases: ['mains', 'transpiration', 'sueur']),
  Feeling('nausea', _body, 'Nausée', 'Nausea', aliases: ['mal au coeur', 'vomir']),
  Feeling('heavy_head', _body, 'Tête lourde', 'Heavy head', aliases: ['tete', 'mal de tete', 'migraine', 'headache']),
  Feeling('chills', _body, 'Frissons', 'Chills', aliases: ['frissonner']),
  Feeling('heat', _body, 'Bouffée de chaleur', 'Flush of heat', aliases: ['chaud', 'chaleur', 'rougir']),
  Feeling('cold', _body, 'Froid à l’intérieur', 'Cold inside', aliases: ['froid']),
  Feeling('heavy_legs', _body, 'Jambes lourdes', 'Heavy legs', aliases: ['jambes', 'jambes coupees']),
  Feeling('restlessness', _body, 'Agitation', 'Restlessness', aliases: ['agite', 'agitee', 'tenir en place', 'restless']),
  Feeling('body_tension', _body, 'Tensions dans le corps', 'Tension in my body', aliases: ['muscles', 'courbatures', 'douleur']),
  Feeling('tingling', _body, 'Fourmillements', 'Tingling', aliases: ['picotements']),
  Feeling('lost_appetite', _body, 'Plus d’appétit', 'No appetite', aliases: ['appetit', 'manger']),
  Feeling('restless_sleep', _body, 'Sommeil agité', 'Restless sleep', aliases: ['dormir', 'insomnie', 'nuit']),
  Feeling('tears', _body, 'Larmes aux yeux', 'Tears in my eyes', aliases: ['pleurer', 'yeux']),
  Feeling('relaxed_body', _body, 'Corps détendu', 'Relaxed body', aliases: ['relache', 'relachee']),
  Feeling('deep_breath', _body, 'Respiration ample', 'Deep breathing', aliases: ['souffle']),
  Feeling('body_energy', _body, 'Énergie dans le corps', 'Energy in my body', aliases: ['vitalite', 'vivant', 'vivante']),
];
