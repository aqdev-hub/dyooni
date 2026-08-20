import '../../local/settings/personal_data_local_datasource.dart';
import '../../models/personal_data.dart';
import 'personal_data_repository.dart';

class PersonalDataRepositoryImpl implements PersonalDataRepository {
  const PersonalDataRepositoryImpl(this._local);
  final PersonalDataLocalDataSource _local;

  @override
  Future<PersonalData> getPersonalData() async {
    final saved = await _local.get();
    return saved ?? PersonalData.dyooniDefault;
  }

  @override
  Future<void> savePersonalData(PersonalData data) => _local.save(data);
}
