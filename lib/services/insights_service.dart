import 'dart:math';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import 'storage_service.dart';

class InsightsService {
  final StorageService _storageService;

  InsightsService(this._storageService);

  /// Generates a list of insight strings based on the user's data.
  List<String> generateInsights() {
    final List<String> insights = [];
    final transactions = _storageService.getAllTransactions();
    final now = DateTime.now();

    if (transactions.isEmpty)
      return ['Start logging transactions to see insights!'];

    // Insight 1: Biggest expense this month
    final thisMonthExpenses = transactions
        .where(
          (t) =>
              t.type == 'expense' &&
              t.date.month == now.month &&
              t.date.year == now.year,
        )
        .toList();

    if (thisMonthExpenses.isNotEmpty) {
      thisMonthExpenses.sort((a, b) => b.amount.compareTo(a.amount));
      final biggest = thisMonthExpenses.first;
      final category = _storageService.getCategoryById(biggest.categoryId);
      final catName = category?.name ?? biggest.categoryId;
      final day = DateFormat('MMM d').format(biggest.date);
      insights.add(
        'Your biggest expense was ${biggest.amount.toStringAsFixed(0)} on $catName on $day.',
      );
    }

    // Insight 2: Category spending change (this week vs last week)
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final thisWeekByCategory = _sumByCategory(
      transactions.where(
        (t) =>
            t.type == 'expense' &&
            t.date.isAfter(thisWeekStart.subtract(const Duration(seconds: 1))),
      ),
    );
    final lastWeekByCategory = _sumByCategory(
      transactions.where(
        (t) =>
            t.type == 'expense' &&
            t.date.isAfter(
              lastWeekStart.subtract(const Duration(seconds: 1)),
            ) &&
            t.date.isBefore(thisWeekStart),
      ),
    );

    String? biggestIncreaseCategory;
    double biggestIncreasePct = 0;

    for (final entry in thisWeekByCategory.entries) {
      final lastWeek = lastWeekByCategory[entry.key] ?? 0;
      if (lastWeek > 0) {
        final pct = ((entry.value - lastWeek) / lastWeek) * 100;
        if (pct > biggestIncreasePct) {
          biggestIncreasePct = pct;
          biggestIncreaseCategory = entry.key;
        }
      }
    }

    if (biggestIncreaseCategory != null && biggestIncreasePct > 0) {
      final category = _storageService.getCategoryById(
        biggestIncreaseCategory,
      );
      final catName = category?.name ?? biggestIncreaseCategory;
      insights.add(
        'You spent ${biggestIncreasePct.toStringAsFixed(0)}% more on $catName this week than last week.',
      );
    }

    // Insight 3: Savings rate this month
    final thisMonthIncome = transactions
        .where(
          (t) =>
              t.type == 'income' &&
              t.date.month == now.month &&
              t.date.year == now.year,
        )
        .fold<double>(0, (sum, t) => sum + t.amount);

    final thisMonthExpenseTotal = thisMonthExpenses.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    if (thisMonthIncome > 0) {
      final savingsPct =
          ((thisMonthIncome - thisMonthExpenseTotal) / thisMonthIncome) * 100;
      final saved = max(savingsPct, 0);
      insights.add(
        'You saved ${saved.toStringAsFixed(0)}% of your income this month.',
      );
    }

    // Insight 4: Daily average spending this month
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = min(now.day, daysInMonth);
    if (daysElapsed > 0 && thisMonthExpenseTotal > 0) {
      final dailyAvg = thisMonthExpenseTotal / daysElapsed;
      insights.add(
        'Your daily average spending this month is ${dailyAvg.toStringAsFixed(0)}.',
      );
    }

    return insights;
  }

  Map<String, double> _sumByCategory(Iterable<Transaction> transactions) {
    final map = <String, double>{};
    for (final t in transactions) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    return map;
  }
}
