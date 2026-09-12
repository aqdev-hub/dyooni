import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/settings/personal_data_local_datasource.dart';
import '../../data/models/personal_data.dart';
import '../../data/repositories/settings/personal_data_repository.dart';
import '../../data/repositories/settings/personal_data_repository_impl.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

final personalDataLocalDataSourceProvider = Provider<PersonalDataLocalDataSource>(
  (ref) => PersonalDataLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final personalDataRepositoryProvider = Provider<PersonalDataRepository>(
  (ref) => PersonalDataRepositoryImpl(ref.watch(personalDataLocalDataSourceProvider)),
);

/// The saved details, or `PersonalData.dyooniDefault` if the person never customized them.
final personalDataProvider = AsyncNotifierProvider<PersonalDataController, PersonalData>(
  PersonalDataController.new,
);

class PersonalDataController extends AsyncNotifier<PersonalData> {
  @override
  Future<PersonalData> build() => ref.read(personalDataRepositoryProvider).getPersonalData();

  Future<void> save(PersonalData data) async {
    await ref.read(personalDataRepositoryProvider).savePersonalData(data);
    state = AsyncData(data);
  }
}
