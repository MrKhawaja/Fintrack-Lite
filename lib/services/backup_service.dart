import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/recurring_rule.dart';
import '../models/budget.dart';

class BackupService {
  /// Creates a full backup of all Hive boxes as a JSON file.
  /// Returns the path to the created backup file, or null on failure.
  Future<String?> createBackup({required String directoryPath}) async {
    try {
      final categoriesBox = Hive.box<Category>('categories');
      final transactionsBox = Hive.box<Transaction>('transactions');
      final recurringRulesBox = Hive.box<RecurringRule>('recurringRules');
      final budgetsBox = Hive.box<Budget>('budgets');
      final settingsBox = Hive.box('settings');

      final backup = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'categories': categoriesBox.values
            .map((c) => _categoryToJson(c))
            .toList(),
        'transactions': transactionsBox.values
            .map((t) => _transactionToJson(t))
            .toList(),
        'recurringRules': recurringRulesBox.values
            .map((r) => _recurringRuleToJson(r))
            .toList(),
        'budgets': budgetsBox.values.map((b) => _budgetToJson(b)).toList(),
        'settings': Map<String, dynamic>.from(
          settingsBox.toMap().cast<String, dynamic>(),
        ),
      };

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'fintrack_backup_$timestamp.json';
      final filePath = '$directoryPath/$fileName';
      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backup),
      );

      return filePath;
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      return null;
    }
  }

  /// Restores data from a JSON backup file.
  /// This replaces all current data.
  Future<bool> restoreBackup(File file) async {
    try {
      final content = await file.readAsString();
      final backup = jsonDecode(content) as Map<String, dynamic>;

      if (backup['version'] != 1) {
        debugPrint('Unsupported backup version: ${backup['version']}');
        return false;
      }

      final categoriesBox = Hive.box<Category>('categories');
      final transactionsBox = Hive.box<Transaction>('transactions');
      final recurringRulesBox = Hive.box<RecurringRule>('recurringRules');
      final budgetsBox = Hive.box<Budget>('budgets');
      final settingsBox = Hive.box('settings');

      // Clear all existing data
      await categoriesBox.clear();
      await transactionsBox.clear();
      await recurringRulesBox.clear();
      await budgetsBox.clear();
      await settingsBox.clear();

      // Restore categories
      for (final c in (backup['categories'] as List<dynamic>)) {
        final cat = _categoryFromJson(c as Map<String, dynamic>);
        await categoriesBox.put(cat.id, cat);
      }

      // Restore transactions
      for (final t in (backup['transactions'] as List<dynamic>)) {
        final tx = _transactionFromJson(t as Map<String, dynamic>);
        await transactionsBox.put(tx.id, tx);
      }

      // Restore recurring rules
      for (final r in (backup['recurringRules'] as List<dynamic>)) {
        final rule = _recurringRuleFromJson(r as Map<String, dynamic>);
        await recurringRulesBox.put(rule.id, rule);
      }

      // Restore budgets
      for (final b in (backup['budgets'] as List<dynamic>)) {
        final budget = _budgetFromJson(b as Map<String, dynamic>);
        await budgetsBox.put(budget.id, budget);
      }

      // Restore settings
      final settings = backup['settings'] as Map<String, dynamic>? ?? {};
      await settingsBox.putAll(settings);

      return true;
    } catch (e) {
      debugPrint('Backup restore failed: $e');
      return false;
    }
  }

  // ────────── Serialization helpers ──────────

  Map<String, dynamic> _categoryToJson(Category c) => {
    'id': c.id,
    'name': c.name,
    'icon': c.icon,
    'color': c.color,
    'monthlyBudget': c.monthlyBudget,
    'type': c.type,
    'isDefault': c.isDefault,
    'createdAt': c.createdAt.toIso8601String(),
  };

  Category _categoryFromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as int,
    monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble(),
    type: json['type'] as String,
    isDefault: json['isDefault'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> _transactionToJson(Transaction t) => {
    'id': t.id,
    'amount': t.amount,
    'type': t.type,
    'categoryId': t.categoryId,
    'note': t.note,
    'tags': t.tags,
    'date': t.date.toIso8601String(),
    'receiptPath': t.receiptPath,
    'recurringId': t.recurringId,
    'currencyCode': t.currencyCode,
    'isRecurringInstance': t.isRecurringInstance,
  };

  Transaction _transactionFromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: json['type'] as String,
    categoryId: json['categoryId'] as String,
    note: json['note'] as String?,
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    date: DateTime.parse(json['date'] as String),
    receiptPath: json['receiptPath'] as String?,
    recurringId: json['recurringId'] as String?,
    currencyCode: json['currencyCode'] as String? ?? 'BDT',
    isRecurringInstance: json['isRecurringInstance'] as bool? ?? false,
  );

  Map<String, dynamic> _recurringRuleToJson(RecurringRule r) => {
    'id': r.id,
    'amount': r.amount,
    'type': r.type,
    'categoryId': r.categoryId,
    'note': r.note,
    'frequency': r.frequency,
    'nextDueDate': r.nextDueDate.toIso8601String(),
    'isActive': r.isActive,
    'createdAt': r.createdAt.toIso8601String(),
  };

  RecurringRule _recurringRuleFromJson(Map<String, dynamic> json) =>
      RecurringRule(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: json['type'] as String,
        categoryId: json['categoryId'] as String,
        note: json['note'] as String?,
        frequency: json['frequency'] as String,
        nextDueDate: DateTime.parse(json['nextDueDate'] as String),
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> _budgetToJson(Budget b) => {
    'id': b.id,
    'categoryId': b.categoryId,
    'month': b.month,
    'year': b.year,
    'limit': b.limit,
    'spent': b.spent,
  };

  Budget _budgetFromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    month: json['month'] as int,
    year: json['year'] as int,
    limit: (json['limit'] as num).toDouble(),
    spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
  );
}
