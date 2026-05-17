import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_provider.dart';
import 'category_provider.dart';

// Today's total expenses
final todaySpentProvider = Provider<double>((ref) {
  final transactions = ref.watch(todayTransactionsProvider);
  return transactions
      .where((t) => t.type == 'expense')
      .fold<double>(0, (sum, t) => sum + t.amount);
});

// Today's total income
final todayIncomeProvider = Provider<double>((ref) {
  final transactions = ref.watch(todayTransactionsProvider);
  return transactions
      .where((t) => t.type == 'income')
      .fold<double>(0, (sum, t) => sum + t.amount);
});

// Monthly balance (income - expenses) for current month
final monthlyBalanceProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final transactions = ref.watch(
    monthlyTransactionsProvider((month: now.month, year: now.year)),
  );

  final income = transactions
      .where((t) => t.type == 'income')
      .fold<double>(0, (sum, t) => sum + t.amount);
  final expense = transactions
      .where((t) => t.type == 'expense')
      .fold<double>(0, (sum, t) => sum + t.amount);

  return income - expense;
});

// Last 7 days spending data for bar chart
class DailySpending {
  final DateTime date;
  final double amount;
  const DailySpending({required this.date, required this.amount});
}

final weeklyChartDataProvider = Provider<List<DailySpending>>((ref) {
  final transactions = ref.watch(allTransactionsProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Generate last 7 days
  final List<DailySpending> data = [];
  for (int i = 6; i >= 0; i--) {
    final date = today.subtract(Duration(days: i));
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayTotal = transactions
        .where(
          (t) =>
              t.type == 'expense' &&
              t.date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(dayEnd),
        )
        .fold<double>(0, (sum, t) => sum + t.amount);

    data.add(DailySpending(date: date, amount: dayTotal));
  }

  return data;
});

// Category-wise spending for current month (pie chart data)
class CategoryBreakdown {
  final String categoryId;
  final String categoryName;
  final String icon;
  final int color;
  final double amount;
  final double percentage;

  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
  });
}

final monthlyCategoryBreakdownProvider = Provider<List<CategoryBreakdown>>((
  ref,
) {
  final now = DateTime.now();
  final transactions = ref.watch(
    monthlyTransactionsProvider((month: now.month, year: now.year)),
  );
  final storage = ref.watch(storageServiceProvider);

  final expensesByCategory = <String, double>{};
  double totalExpenses = 0;

  for (final t in transactions) {
    if (t.type == 'expense') {
      expensesByCategory[t.categoryId] =
          (expensesByCategory[t.categoryId] ?? 0) + t.amount;
      totalExpenses += t.amount;
    }
  }

  final breakdown = <CategoryBreakdown>[];
  for (final entry in expensesByCategory.entries) {
    final category = storage.getCategoryById(entry.key);
    breakdown.add(
      CategoryBreakdown(
        categoryId: entry.key,
        categoryName: category?.name ?? 'Unknown',
        icon: category?.icon ?? '💰',
        color: category?.color ?? 0xFF000000,
        amount: entry.value,
        percentage:
            totalExpenses > 0 ? (entry.value / totalExpenses * 100) : 0.0,
      ),
    );
  }

  // Sort by amount descending
  breakdown.sort((a, b) => b.amount.compareTo(a.amount));
  return breakdown;
});

// Month-wise spending/income for current year
class MonthlyBreakdown {
  final int month;
  final double income;
  final double expense;
  const MonthlyBreakdown({
    required this.month,
    required this.income,
    required this.expense,
  });
}

final yearlyMonthlyBreakdownProvider = Provider<List<MonthlyBreakdown>>((ref) {
  final now = DateTime.now();
  final transactions = ref.watch(allTransactionsProvider);

  final breakdowns = <int, MonthlyBreakdown>{};

  for (int m = 1; m <= 12; m++) {
    breakdowns[m] = MonthlyBreakdown(month: m, income: 0, expense: 0);
  }

  for (final t in transactions) {
    if (t.date.year != now.year) continue;
    final current = breakdowns[t.date.month]!;
    if (t.type == 'income') {
      breakdowns[t.date.month] = MonthlyBreakdown(
        month: t.date.month,
        income: current.income + t.amount,
        expense: current.expense,
      );
    } else {
      breakdowns[t.date.month] = MonthlyBreakdown(
        month: t.date.month,
        income: current.income,
        expense: current.expense + t.amount,
      );
    }
  }

  return breakdowns.values.toList();
});
