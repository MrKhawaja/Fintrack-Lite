import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// App settings state
class AppSettings {
  final String currencyCode;
  final String localeCode;
  final bool notificationsEnabled;
  final bool biometricLockEnabled;

  const AppSettings({
    this.currencyCode = 'BDT',
    this.localeCode = 'en',
    this.notificationsEnabled = true,
    this.biometricLockEnabled = false,
  });

  AppSettings copyWith({
    String? currencyCode,
    String? localeCode,
    bool? notificationsEnabled,
    bool? biometricLockEnabled,
  }) {
    return AppSettings(
      currencyCode: currencyCode ?? this.currencyCode,
      localeCode: localeCode ?? this.localeCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    );
  }
}

// Settings notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  void _load() {
    // In a full implementation, this would load from Hive/SharedPreferences
    // For now, we start with defaults that the user can change
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final storage = StorageService();
    await storage.setSetting('currencyCode', newSettings.currencyCode);
    await storage.setSetting('localeCode', newSettings.localeCode);
    await storage.setSetting(
      'notificationsEnabled',
      newSettings.notificationsEnabled,
    );
    await storage.setSetting(
      'biometricLockEnabled',
      newSettings.biometricLockEnabled,
    );
    state = newSettings;
  }

  Future<void> setCurrency(String code) async {
    final updated = state.copyWith(currencyCode: code);
    await updateSettings(updated);
  }

  Future<void> setLocale(String code) async {
    final updated = state.copyWith(localeCode: code);
    await updateSettings(updated);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});

// Convenience providers
final currencyProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).currencyCode;
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).notificationsEnabled;
});
