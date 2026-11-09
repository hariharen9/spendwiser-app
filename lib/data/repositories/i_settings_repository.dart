import '../models/app_settings.dart';

abstract interface class ISettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
