import '../../models/general_settings.dart';

/// `logic/` يستورد هذه الواجهة فقط — لا يستورد DataSource مباشرة أبدًا (انظر repository-di.md
/// وباقي الـ Repositories في هذا المشروع لنفس النمط).
abstract class GeneralSettingsRepository {
  Future<GeneralSettings?> get();
  Future<void> save(GeneralSettings settings);
}
