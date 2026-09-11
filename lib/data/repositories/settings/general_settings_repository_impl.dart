import '../../local/settings/general_settings_local_datasource.dart';
import '../../models/general_settings.dart';
import 'general_settings_repository.dart';

class GeneralSettingsRepositoryImpl implements GeneralSettingsRepository {
  const GeneralSettingsRepositoryImpl(this._local);
  final GeneralSettingsLocalDataSource _local;

  @override
  Future<GeneralSettings?> get() => _local.get();

  @override
  Future<void> save(GeneralSettings settings) => _local.save(settings);
}
