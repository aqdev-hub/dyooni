import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/data/repositories/onboarding/onboarding_repository.dart';
import 'package:dyooni/logic/onboarding/onboarding_provider.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

void main() {
  late MockOnboardingRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockOnboardingRepository();
    container = ProviderContainer(
      overrides: [onboardingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('build() returns false when onboarding has not been seen', () async {
    when(() => repository.hasSeenOnboarding()).thenAnswer((_) async => false);

    final result = await container.read(onboardingCompletedProvider.future);

    expect(result, isFalse);
  });

  test('complete() persists the flag and updates state to true', () async {
    when(() => repository.hasSeenOnboarding()).thenAnswer((_) async => false);
    when(() => repository.completeOnboarding()).thenAnswer((_) async {});

    await container.read(onboardingCompletedProvider.future); // let initial build settle
    await container.read(onboardingCompletedProvider.notifier).complete();

    verify(() => repository.completeOnboarding()).called(1);
    expect(container.read(onboardingCompletedProvider).value, isTrue);
  });

  test('build() propagates repository failure as AsyncError, never leaks internal detail to UI',
      () async {
    when(() => repository.hasSeenOnboarding()).thenThrow(Exception('disk full'));

    await expectLater(
      container.read(onboardingCompletedProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(onboardingCompletedProvider).hasError, isTrue);
  });
}
