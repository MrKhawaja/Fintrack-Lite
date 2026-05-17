import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

class NotificationService {
  static const String _notifiedThresholdsKey = 'notified_thresholds';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);
  }

  /// Checks all category budgets against current month spending.
  /// Sends a notification when a category crosses 75% or 100%.
  /// Only notifies once per threshold per category per month.
  Future<void> checkBudgetThresholds(StorageService storage) async {
    final prefs = await SharedPreferences.getInstance();
    final budgets = storage.getAllBudgets();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month}';

    // Load already-notified thresholds
    final notifiedJson = prefs.getString(_notifiedThresholdsKey);
    Map<String, List<String>> notified;
    if (notifiedJson != null) {
      notified = Map<String, List<String>>.from(
        (RegExp(r'([^:]+):([^;]+)').allMatches(notifiedJson)).fold(
          <String, List<String>>{},
          (map, m) {
            final catId = m.group(1)!;
            final thresholds = m.group(2)!.split(',');
            map[catId] = thresholds;
            return map;
          },
        ),
      );
      // Only keep current month entries
      notified.removeWhere((key, value) => !key.startsWith(monthKey));
    } else {
      notified = {};
    }

    for (final budget in budgets) {
      if (budget.month != now.month || budget.year != now.year) continue;
      if (budget.limit <= 0) continue;

      final percentage = (budget.spent / budget.limit * 100).clamp(0, 200);
      final category = storage.getCategoryById(budget.categoryId);
      final catName = category?.name ?? budget.categoryId;
      final notifiedKey = '$monthKey:${budget.categoryId}';
      final alreadyNotified = notified[notifiedKey] ?? [];

      // Check 100% threshold
      if (percentage >= 100 && !alreadyNotified.contains('100')) {
        await _showNotification(
          'Budget Exceeded!',
          '$catName budget is at ${percentage.toStringAsFixed(0)}%! You\'ve spent ${budget.spent.toStringAsFixed(0)} of ${budget.limit.toStringAsFixed(0)}.',
        );
        alreadyNotified.add('100');
      }
      // Check 75% threshold
      else if (percentage >= 75 && !alreadyNotified.contains('75')) {
        await _showNotification(
          'Budget Alert',
          '$catName budget is at ${percentage.toStringAsFixed(0)}%! Watch your spending.',
        );
        alreadyNotified.add('75');
      }

      if (alreadyNotified.isNotEmpty) {
        notified[notifiedKey] = alreadyNotified;
      }
    }

    // Persist notified thresholds
    if (notified.isNotEmpty) {
      final serialized = notified.entries
          .map((e) => '${e.key}:${e.value.join(',')}')
          .join(';');
      await prefs.setString(_notifiedThresholdsKey, serialized);
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget thresholds',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }
}
