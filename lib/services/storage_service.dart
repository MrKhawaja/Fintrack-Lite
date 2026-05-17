import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/recurring_rule.dart';
import '../models/budget.dart';

class StorageService {
  static const String _categoriesBox = 'categories';
  static const String _transactionsBox = 'transactions';
  static const String _recurringRulesBox = 'recurringRules';
  static const String _budgetsBox = 'budgets';
  static const String _settingsBox = 'settings';

  final Uuid _uuid = const Uuid();

  // ──────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await Hive.openBox<Category>(_categoriesBox);
    await Hive.openBox<Transaction>(_transactionsBox);
    await Hive.openBox<RecurringRule>(_recurringRulesBox);
    await Hive.openBox<Budget>(_budgetsBox);
    await Hive.openBox(_settingsBox);
    await seedDefaultCategories();
  }

  // ──────────────────────────────────────────────────────────────
  // Box getters
  // ──────────────────────────────────────────────────────────────

  Box<Category> get categoriesBox => Hive.box<Category>(_categoriesBox);
  Box<Transaction> get transactionsBox =>
      Hive.box<Transaction>(_transactionsBox);
  Box<RecurringRule> get recurringRulesBox =>
      Hive.box<RecurringRule>(_recurringRulesBox);
  Box<Budget> get budgetsBox => Hive.box<Budget>(_budgetsBox);
  Box get settingsBox => Hive.box(_settingsBox);

  // ──────────────────────────────────────────────────────────────
  // Categories CRUD
  // ──────────────────────────────────────────────────────────────

  List<Category> getAllCategories() {
    return categoriesBox.values.toList();
  }

  List<Category> getExpenseCategories() {
    return categoriesBox.values.where((c) => c.type == 'expense').toList();
  }

  List<Category> getIncomeCategories() {
    return categoriesBox.values.where((c) => c.type == 'income').toList();
  }

  Category? getCategoryById(String id) {
    return categoriesBox.get(id);
  }

  Future<void> addCategory(Category category) async {
    await categoriesBox.put(category.id, category);
  }

  Future<void> updateCategory(Category category) async {
    await categoriesBox.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    await categoriesBox.delete(id);
  }

  Future<void> seedDefaultCategories() async {
    if (categoriesBox.isNotEmpty) return;

    final now = DateTime.now();

    // Default expense categories
    final expenseCategories = [
      Category(
        id: _uuid.v4(),
        name: 'Food',
        icon: '🍔',
        color: Colors.orange.toARGB32(),
        type: 'expense',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Transport',
        icon: '🚗',
        color: Colors.blue.toARGB32(),
        type: 'expense',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Bills',
        icon: '🧾',
        color: Colors.red.toARGB32(),
        type: 'expense',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Shopping',
        icon: '🛍️',
        color: Colors.purple.toARGB32(),
        type: 'expense',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Entertainment',
        icon: '🎬',
        color: Colors.pink.toARGB32(),
        type: 'expense',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Health',
        icon: '💊',
        color: Colors.green.toARGB32(),
        type: 'expense',
        isDefault: true,
        createdAt: now,
      ),
    ];

    // Default income categories
    final incomeCategories = [
      Category(
        id: _uuid.v4(),
        name: 'Salary',
        icon: '💰',
        color: Colors.green.shade700.toARGB32(),
        type: 'income',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Freelance',
        icon: '💻',
        color: Colors.cyan.toARGB32(),
        type: 'income',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Investment',
        icon: '📈',
        color: Colors.teal.toARGB32(),
        type: 'income',
        isDefault: true,
        createdAt: now,
      ),
      Category(
        id: _uuid.v4(),
        name: 'Gift',
        icon: '🎁',
        color: Colors.amber.toARGB32(),
        type: 'income',
        isDefault: true,
        createdAt: now,
      ),
    ];

    for (final cat in [...expenseCategories, ...incomeCategories]) {
      await categoriesBox.put(cat.id, cat);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Transactions CRUD
  // ──────────────────────────────────────────────────────────────

  List<Transaction> getAllTransactions() {
    return transactionsBox.values.toList();
  }

  Transaction? getTransactionById(String id) {
    return transactionsBox.get(id);
  }

  List<Transaction> getTransactionsByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return transactionsBox.values
        .where(
          (t) =>
              t.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(endOfDay),
        )
        .toList();
  }

  List<Transaction> getTransactionsByMonth(int month, int year) {
    return transactionsBox.values
        .where((t) => t.date.month == month && t.date.year == year)
        .toList();
  }

  List<Transaction> getTransactionsByCategory(String categoryId) {
    return transactionsBox.values
        .where((t) => t.categoryId == categoryId)
        .toList();
  }

  Future<void> addTransaction(Transaction transaction) async {
    await transactionsBox.put(transaction.id, transaction);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await transactionsBox.put(transaction.id, transaction);
  }

  Future<void> deleteTransaction(String id) async {
    await transactionsBox.delete(id);
  }

  // ──────────────────────────────────────────────────────────────
  // Recurring Rules CRUD
  // ──────────────────────────────────────────────────────────────

  List<RecurringRule> getAllRecurringRules() {
    return recurringRulesBox.values.toList();
  }

  List<RecurringRule> getActiveRecurringRules() {
    return recurringRulesBox.values.where((r) => r.isActive).toList();
  }

  RecurringRule? getRecurringRuleById(String id) {
    return recurringRulesBox.get(id);
  }

  Future<void> addRecurringRule(RecurringRule rule) async {
    await recurringRulesBox.put(rule.id, rule);
  }

  Future<void> updateRecurringRule(RecurringRule rule) async {
    await recurringRulesBox.put(rule.id, rule);
  }

  Future<void> deleteRecurringRule(String id) async {
    await recurringRulesBox.delete(id);
  }

  // ──────────────────────────────────────────────────────────────
  // Budgets CRUD
  // ──────────────────────────────────────────────────────────────

  List<Budget> getAllBudgets() {
    return budgetsBox.values.toList();
  }

  List<Budget> getBudgetsByMonth(int month, int year) {
    return budgetsBox.values
        .where((b) => b.month == month && b.year == year)
        .toList();
  }

  Budget? getBudgetByCategory(String categoryId) {
    return budgetsBox.values.cast<Budget?>().firstWhere(
          (b) => b?.categoryId == categoryId,
          orElse: () => null,
        );
  }

  Future<void> addBudget(Budget budget) async {
    await budgetsBox.put(budget.id, budget);
  }

  Future<void> updateBudget(Budget budget) async {
    await budgetsBox.put(budget.id, budget);
  }

  Future<void> deleteBudget(String id) async {
    await budgetsBox.delete(id);
  }

  // ──────────────────────────────────────────────────────────────
  // Settings
  // ──────────────────────────────────────────────────────────────

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> setSetting(String key, dynamic value) async {
    await settingsBox.put(key, value);
  }
}
