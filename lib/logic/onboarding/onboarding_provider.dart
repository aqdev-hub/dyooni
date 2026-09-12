import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/onboarding/onboarding_local_datasource.dart';
import '../../data/repositories/onboarding/onboarding_repository.dart';
import '../../data/repositories/onboarding/onboarding_repository_impl.dart';

/// Overridden in `main.dart` with the resolved instance once `SharedPreferences.getInstance()`
/// completes — see main.dart. Kept as a plain `Provider` (not late-initialized globally) so tests
/// can override it with a fake in-memory instance instead of touching real device storage.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart'),
);

final onboardingLocalDataSourceProvider = Provider<OnboardingLocalDataSource>(
  (ref) => OnboardingLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepositoryImpl(ref.watch(onboardingLocalDataSourceProvider)),
);

/// Whether onboarding has already been completed — read once at app start to decide the
/// initial route (see core/routes/app_router.dart).
final onboardingCompletedProvider =
    AsyncNotifierProvider<OnboardingCompletedController, bool>(
  OnboardingCompletedController.new,
);

class OnboardingCompletedController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(onboardingRepositoryProvider).hasSeenOnboarding();

  Future<void> complete() async {
    await ref.read(onboardingRepositoryProvider).completeOnboarding();
    state = const AsyncData(true);
  }
}

/// Current page index of the onboarding PageView — plain UI state, doesn't need a Repository.
final onboardingPageIndexProvider = StateProvider.autoDispose<int>((ref) => 0);
