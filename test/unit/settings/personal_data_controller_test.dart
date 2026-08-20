import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/data/models/personal_data.dart';
import 'package:dyooni/data/repositories/settings/personal_data_repository.dart';
import 'package:dyooni/logic/settings/personal_data_provider.dart';

class MockPersonalDataRepository extends Mock implements PersonalDataRepository {}

void main() {
  late MockPersonalDataRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(PersonalData.dyooniDefault);
  });

  setUp(() {
    repository = MockPersonalDataRepository();
    container = ProviderContainer(
      overrides: [personalDataRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('build() returns Dyooni\'s own default identity, not a blank record', () async {
    when(() => repository.getPersonalData()).thenAnswer((_) async => PersonalData.dyooniDefault);

    final result = await container.read(personalDataProvider.future);

    expect(result.nameAr, 'ديوني');
    expect(result.nameEn, 'Dyooni');
  });

  test('save() persists the new data via the repository and updates state to it', () async {
    when(() => repository.getPersonalData()).thenAnswer((_) async => PersonalData.dyooniDefault);
    const updated = PersonalData(
      nameAr: 'أحمد',
      nameEn: 'Ahmed',
      addressAr: 'صنعاء',
      addressEn: 'Sanaa',
      phone: '0501234567',
      email: 'ahmed@example.com',
      signatureEnabled: false,
      stampEnabled: true,
    );
    when(() => repository.savePersonalData(updated)).thenAnswer((_) async {});

    await container.read(personalDataProvider.future);
    await container.read(personalDataProvider.notifier).save(updated);

    verify(() => repository.savePersonalData(updated)).called(1);
    expect(container.read(personalDataProvider).value, updated);
  });
}
