import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import 'category_provider.dart';

// All budgets
final allBudgetsProvider = Provider<List<Budget>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllBudgets();
});

// Current month budgets
final currentMonthBudgetsProvider = Provider<List<Budget>>((ref) {
  final now = DateTime.now();
  final storage = ref.watch(storageServiceProvider);
  return storage.getBudgetsByMonth(now.month, now.year);
});

// Budget by category (family)
final budgetByCategoryProvider = Provider.family<Budget?, String>((
  ref,
  categoryId,
) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getBudgetByCategory(categoryId);
});

// Computed budget progress data
class BudgetProgress {
  final String categoryId;
  final String categoryName;
  final double limit;
  final double spent;
  final double remaining;
  final double percentage;

  const BudgetProgress({
    required this.categoryId,
    required this.categoryName,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.percentage,
  });
}

final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(currentMonthBudgetsProvider);
  final storage = ref.watch(storageServiceProvider);

  return budgets.map((budget) {
    final category = storage.getCategoryById(budget.categoryId);
    final remaining = budget.limit - budget.spent;
    final percentage = budget.limit > 0
        ? (budget.spent / budget.limit * 100)
        : 0.0;

    return BudgetProgress(
      categoryId: budget.categoryId,
      categoryName: category?.name ?? 'Unknown',
      limit: budget.limit,
      spent: budget.spent,
      remaining: remaining,
      percentage: percentage.clamp(0, 100),
    );
  }).toList();
});
