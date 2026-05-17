import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

class StreakService {
  static const String _streakCountKey = 'streak_count';
  static const String _lastLogDateKey = 'last_log_date';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Returns the current streak count.
  int get streakCount => _prefs?.getInt(_streakCountKey) ?? 0;

  /// Returns the last log date as a [DateTime], or null if never logged.
  DateTime? get lastLogDate {
    final dateStr = _prefs?.getString(_lastLogDateKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Static helper: checks and updates the streak on app start.
  /// Resets streak if the user missed a day. Returns the current streak count.
  static Future<int> checkAndUpdateStreak(StorageService storageService) async {
    final service = StreakService();
    await service.initialize();

    final lastDate = service.lastLogDate;
    if (lastDate != null) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final lastDateOnly =
          DateTime(lastDate.year, lastDate.month, lastDate.day);
      final difference = todayDate.difference(lastDateOnly).inDays;
      if (difference > 1) {
        await service.resetStreak();
      }
    }
    return service.streakCount;
  }

  /// Returns the current streak count statically (after initializing).
  static Future<int> getCurrentStreak() async {
    final service = StreakService();
    await service.initialize();
    return service.streakCount;
  }

  /// Call this whenever the user logs a transaction.
  /// Updates the streak count accordingly.
  Future<void> recordLog() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = lastLogDate;

    if (lastDate == null) {
      // First log ever
      await _prefs?.setInt(_streakCountKey, 1);
      await _prefs?.setString(_lastLogDateKey, todayDate.toIso8601String());
      return;
    }

    final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);

    if (todayDate == lastDateOnly) {
      // Already logged today, no change
      return;
    }

    final difference = todayDate.difference(lastDateOnly).inDays;

    if (difference == 1) {
      // Consecutive day
      await _prefs?.setInt(_streakCountKey, streakCount + 1);
    } else {
      // Streak broken, start over
      await _prefs?.setInt(_streakCountKey, 1);
    }

    await _prefs?.setString(_lastLogDateKey, todayDate.toIso8601String());
  }

  /// Resets the streak to 0.
  Future<void> resetStreak() async {
    await _prefs?.setInt(_streakCountKey, 0);
    await _prefs?.setString(_lastLogDateKey, DateTime.now().toIso8601String());
  }
}
