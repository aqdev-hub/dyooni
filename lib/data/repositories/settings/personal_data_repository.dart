import '../../models/personal_data.dart';

/// `logic/` imports this interface only — never the DataSource directly (see repository-di.md).
abstract class PersonalDataRepository {
  Future<PersonalData> getPersonalData();
  Future<void> savePersonalData(PersonalData data);
}
