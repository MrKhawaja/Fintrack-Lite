import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/storage_service.dart';

// Singleton storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// All categories
final allCategoriesProvider = Provider<List<Category>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllCategories();
});

// Expense categories only
final expenseCategoriesProvider = Provider<List<Category>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getExpenseCategories();
});

// Income categories only
final incomeCategoriesProvider = Provider<List<Category>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getIncomeCategories();
});

// Single category by ID (family provider)
final categoryByIdProvider = Provider.family<Category?, String>((ref, id) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getCategoryById(id);
});
