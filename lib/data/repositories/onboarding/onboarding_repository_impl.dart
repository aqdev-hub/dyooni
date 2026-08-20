import '../../local/onboarding/onboarding_local_datasource.dart';
import 'onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl(this._local);
  final OnboardingLocalDataSource _local;

  @override
  Future<bool> hasSeenOnboarding() => _local.hasSeenOnboarding();

  @override
  Future<void> completeOnboarding() => _local.markOnboardingSeen();
}
