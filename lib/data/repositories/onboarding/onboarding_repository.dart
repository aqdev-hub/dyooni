/// `logic/` imports this interface only — never the DataSource directly (see repository-di.md).
abstract class OnboardingRepository {
  Future<bool> hasSeenOnboarding();
  Future<void> completeOnboarding();
}
