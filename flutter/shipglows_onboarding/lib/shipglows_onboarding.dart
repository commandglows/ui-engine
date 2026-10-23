/// First-run introduction for ShipGlows Flutter apps.
///
/// - [OnboardingPage]: one page of the card — title, text, optional body and
///   the preview drawn in the right column. [OnboardingLanguagePage] asks for
///   the language first. [OnboardingStatements] fills a mission page
///   (mission, vision, goal).
/// - [OnboardingFlow]: the card itself, its segmented progress bar and the
///   Back / Skip / Next actions.
/// - [OnboardingGate]: whether the introduction is still due for the signed-in
///   account, kept in an [OnboardingCompletionStore].
/// - [OnboardingOverlay]: shows the flow above the app while it is due.
library;

export 'src/onboarding_flow.dart';
export 'src/onboarding_gate.dart';
export 'src/onboarding_page.dart';
export 'src/onboarding_statements.dart';
export 'src/onboarding_strings.dart';
export 'src/onboarding_theme.dart';
