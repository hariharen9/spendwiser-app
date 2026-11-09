import '../models/app_settings.dart';
import '../repositories/i_settings_repository.dart';

class MockSettingsRepository implements ISettingsRepository {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}
