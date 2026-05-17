import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import 'category_provider.dart';

// All transactions
final allTransactionsProvider = Provider<List<Transaction>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllTransactions();
});

// Today's transactions
final todayTransactionsProvider = Provider<List<Transaction>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final today = DateTime.now();
  return storage.getTransactionsByDate(today);
});

// Transactions by a specific date (family)
final transactionsByDateProvider = Provider.family<List<Transaction>, DateTime>(
  (ref, date) {
    final storage = ref.watch(storageServiceProvider);
    return storage.getTransactionsByDate(date);
  },
);

// Monthly transactions (family)
final monthlyTransactionsProvider =
    Provider.family<List<Transaction>, ({int month, int year})>((ref, params) {
      final storage = ref.watch(storageServiceProvider);
      return storage.getTransactionsByMonth(params.month, params.year);
    });

// Transactions by category (family)
final categoryTransactionsProvider = Provider.family<List<Transaction>, String>(
  (ref, categoryId) {
    final storage = ref.watch(storageServiceProvider);
    return storage.getTransactionsByCategory(categoryId);
  },
);

// Filtered transactions — supports search query, date range, category, amount range
class TransactionFilters {
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final double? minAmount;
  final double? maxAmount;
  final String? type; // 'income' or 'expense'

  const TransactionFilters({
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.categoryId,
    this.minAmount,
    this.maxAmount,
    this.type,
  });
}

final filteredTransactionsProvider =
    Provider.family<List<Transaction>, TransactionFilters>((ref, filters) {
      final all = ref.watch(allTransactionsProvider);
      final storage = ref.watch(storageServiceProvider);

      return all.where((t) {
        // Filter by type
        if (filters.type != null && t.type != filters.type) return false;

        // Filter by category
        if (filters.categoryId != null && t.categoryId != filters.categoryId) {
          return false;
        }

        // Filter by date range
        if (filters.startDate != null && t.date.isBefore(filters.startDate!)) {
          return false;
        }
        if (filters.endDate != null && t.date.isAfter(filters.endDate!)) {
          return false;
        }

        // Filter by amount range
        if (filters.minAmount != null && t.amount < filters.minAmount!) {
          return false;
        }
        if (filters.maxAmount != null && t.amount > filters.maxAmount!) {
          return false;
        }

        // Filter by search query (search note and category name)
        if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
          final query = filters.searchQuery!.toLowerCase();
          final category = storage.getCategoryById(t.categoryId);
          final catName = category?.name.toLowerCase() ?? '';
          final note = t.note?.toLowerCase() ?? '';
          if (!catName.contains(query) && !note.contains(query)) return false;
        }

        return true;
      }).toList();
    });
