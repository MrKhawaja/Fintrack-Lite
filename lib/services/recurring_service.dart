import '../models/transaction.dart';
import '../models/recurring_rule.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class RecurringService {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  RecurringService(this._storageService);

  /// Checks all active recurring rules and creates transactions for
  /// those whose [nextDueDate] has passed. Returns the newly created
  /// transactions.
  List<Transaction> processDueRecurringRules() {
    final activeRules = _storageService.getActiveRecurringRules();
    final now = DateTime.now();
    final List<Transaction> created = [];

    for (final rule in activeRules) {
      if (rule.nextDueDate.isBefore(now) ||
          rule.nextDueDate.isAtSameMomentAs(now)) {
        // Create a transaction for this recurrence
        final transaction = Transaction(
          id: _uuid.v4(),
          amount: rule.amount,
          type: rule.type,
          categoryId: rule.categoryId,
          note: rule.note,
          date: rule.nextDueDate,
          recurringId: rule.id,
          isRecurringInstance: true,
        );

        _storageService.addTransaction(transaction);
        created.add(transaction);

        // Calculate the next due date
        final nextDate = _calculateNextDueDate(
          rule.nextDueDate,
          rule.frequency,
        );
        final updatedRule = RecurringRule(
          id: rule.id,
          amount: rule.amount,
          type: rule.type,
          categoryId: rule.categoryId,
          note: rule.note,
          frequency: rule.frequency,
          nextDueDate: nextDate,
          isActive: rule.isActive,
          createdAt: rule.createdAt,
        );

        _storageService.updateRecurringRule(updatedRule);
      }
    }

    return created;
  }

  DateTime _calculateNextDueDate(DateTime from, String frequency) {
    switch (frequency) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(from.year, from.month + 1, from.day);
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      default:
        return from.add(const Duration(days: 30)); // fallback
    }
  }
}
