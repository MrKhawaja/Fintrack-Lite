import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  static const List<int> presetColors = [
    0xFFE53935, // Red
    0xFFFF6F00, // Orange
    0xFFFDD835, // Yellow
    0xFF43A047, // Green
    0xFF039BE5, // Blue
    0xFF8E24AA, // Purple
    0xFFEC407A, // Pink
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFF00BCD4, // Cyan
  ];

  final _uuid = const Uuid();
  final _numberFormat = NumberFormat('#,###');

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider);
    final now = DateTime.now();
    final monthlyTxns = ref.watch(
      monthlyTransactionsProvider((month: now.month, year: now.year)),
    );
    final currentBudgets = ref.watch(currentMonthBudgetsProvider);

    final expenseCategories =
        categories.where((c) => c.type == 'expense').toList();
    final incomeCategories =
        categories.where((c) => c.type == 'income').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expenseCategories.isNotEmpty) ...[
            _buildSectionHeader('EXPENSE CATEGORIES'),
            const SizedBox(height: 8),
            ...expenseCategories.map(
              (c) => _buildCategoryCard(c, monthlyTxns, currentBudgets),
            ),
          ],
          const SizedBox(height: 24),
          if (incomeCategories.isNotEmpty) ...[
            _buildSectionHeader('INCOME CATEGORIES'),
            const SizedBox(height: 8),
            ...incomeCategories.map(
              (c) => _buildCategoryCard(c, monthlyTxns, currentBudgets),
            ),
          ],
          const SizedBox(height: 24),
          _buildAddCustomButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Section Header
  // ──────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Category Card
  // ──────────────────────────────────────────────────────────────

  Widget _buildCategoryCard(
    Category category,
    List<Transaction> monthlyTxns,
    List<Budget> currentBudgets,
  ) {
    final isExpense = category.type == 'expense';

    // Calculate spent for this category in the current month
    final spent = monthlyTxns
        .where((t) => t.categoryId == category.id && t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);

    // Find current-month budget for this category
    final budget = currentBudgets.cast<Budget?>().firstWhere(
          (b) => b?.categoryId == category.id,
          orElse: () => null,
        );

    final hasBudget = category.monthlyBudget != null || budget != null;
    final budgetLimit = budget?.limit ?? category.monthlyBudget ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar, name, spacer, edit
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(category.color),
                  radius: 20,
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (category.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit category',
                  onPressed: () => _showCategoryDialog(existing: category),
                ),
                // Delete button (custom categories only)
                if (!category.isDefault)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: Colors.red.shade400),
                    tooltip: 'Delete category',
                    onPressed: () => _showDeleteConfirmation(category),
                  ),
              ],
            ),

            // Budget section (expense categories only)
            if (isExpense) ...[
              if (hasBudget && budgetLimit > 0) ...[
                const SizedBox(height: 10),
                _buildBudgetProgress(spent, budgetLimit),
              ] else ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _showBudgetDialog(category),
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Set Budget'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Budget Progress
  // ──────────────────────────────────────────────────────────────

  Widget _buildBudgetProgress(double spent, double limit) {
    final percentage = limit > 0 ? (spent / limit * 100).clamp(0, 999) : 0.0;

    Color progressColor;
    if (percentage >= 100) {
      progressColor = Colors.red;
    } else if (percentage >= 75) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Budget: ৳${_numberFormat.format(spent.toInt())} / ৳${_numberFormat.format(limit.toInt())}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${percentage.toInt()}% spent',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Add Custom Category Button
  // ──────────────────────────────────────────────────────────────

  Widget _buildAddCustomButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showCategoryDialog(),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Add Custom Category'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Add / Edit Category Dialog
  // ──────────────────────────────────────────────────────────────

  void _showCategoryDialog({Category? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emojiController = TextEditingController(text: existing?.icon ?? '');
    final budgetController = TextEditingController(
      text: existing?.monthlyBudget != null
          ? existing!.monthlyBudget!.toInt().toString()
          : '',
    );
    int selectedColor = existing?.color ?? presetColors[0];
    String selectedType = existing?.type ?? 'expense';
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Category' : 'Add Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Groceries',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),

                    // Emoji
                    TextField(
                      controller: emojiController,
                      decoration: const InputDecoration(
                        labelText: 'Emoji Icon',
                        hintText: 'Single emoji',
                      ),
                      maxLength: 2,
                    ),
                    const SizedBox(height: 12),

                    // Color picker
                    const Text(
                      'Color',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetColors.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedColor = color);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color:
                                          Theme.of(ctx).colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Type toggle
                    Row(
                      children: [
                        const Text('Type: '),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Expense'),
                          selected: selectedType == 'expense',
                          onSelected: (_) =>
                              setDialogState(() => selectedType = 'expense'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Income'),
                          selected: selectedType == 'income',
                          onSelected: (_) =>
                              setDialogState(() => selectedType = 'income'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Monthly budget (optional)
                    TextField(
                      controller: budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Budget (optional)',
                        hintText: 'e.g. 10000',
                        helperText: 'Set a monthly spending limit',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                // Delete button (custom categories only)
                if (isEditing && !existing.isDefault)
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop(); // close dialog first
                      _showDeleteConfirmation(existing);
                    },
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final emoji = emojiController.text.trim();

                    if (name.isEmpty) {
                      _showSnackBar('Please enter a category name');
                      return;
                    }
                    if (emoji.isEmpty || emoji.characters.length > 2) {
                      _showSnackBar('Please enter a single emoji icon');
                      return;
                    }

                    final budgetText = budgetController.text.trim();
                    final monthlyBudget = budgetText.isNotEmpty
                        ? double.tryParse(budgetText)
                        : null;

                    final category = Category(
                      id: existing?.id ?? _uuid.v4(),
                      name: name,
                      icon: emoji.characters.first,
                      color: selectedColor,
                      monthlyBudget: monthlyBudget,
                      type: selectedType,
                      isDefault: existing?.isDefault ?? false,
                      createdAt: existing?.createdAt ?? DateTime.now(),
                    );

                    Navigator.of(ctx).pop();

                    try {
                      final storage = ref.read(storageServiceProvider);
                      if (isEditing) {
                        await storage.updateCategory(category);
                      } else {
                        await storage.addCategory(category);
                      }
                      ref.invalidate(allCategoriesProvider);
                      ref.invalidate(allBudgetsProvider);
                      if (mounted) {
                        _showSnackBar(
                          isEditing ? 'Category updated' : 'Category created',
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        _showSnackBar('Error: $e');
                      }
                    }
                  },
                  child: Text(isEditing ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Budget Dialog
  // ──────────────────────────────────────────────────────────────

  void _showBudgetDialog(Category category) {
    final budgetController = TextEditingController();
    final now = DateTime.now();
    final monthlyTxns = ref.read(
      monthlyTransactionsProvider((month: now.month, year: now.year)),
    );

    // Pre-fill with existing budget if any
    final currentBudgets = ref.read(currentMonthBudgetsProvider);
    final existingBudget = currentBudgets.cast<Budget?>().firstWhere(
          (b) => b?.categoryId == category.id,
          orElse: () => null,
        );
    if (existingBudget != null) {
      budgetController.text = existingBudget.limit.toInt().toString();
    } else if (category.monthlyBudget != null) {
      budgetController.text = category.monthlyBudget!.toInt().toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(category.color),
                    radius: 16,
                    child: Text(category.icon,
                        style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Budget for ${category.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Budget Limit',
                  hintText: '৳0',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final limitText = budgetController.text.trim();
                    final limit = double.tryParse(limitText);
                    if (limit == null || limit <= 0) {
                      _showSnackBar('Please enter a valid budget amount');
                      return;
                    }

                    Navigator.of(ctx).pop();

                    try {
                      final storage = ref.read(storageServiceProvider);

                      // Create or update budget record for current month
                      if (existingBudget != null) {
                        final updatedBudget = Budget(
                          id: existingBudget.id,
                          categoryId: category.id,
                          month: now.month,
                          year: now.year,
                          limit: limit,
                          spent: existingBudget.spent,
                        );
                        await storage.updateBudget(updatedBudget);
                      } else {
                        // Calculate current spent
                        final spent = monthlyTxns
                            .where((t) =>
                                t.categoryId == category.id &&
                                t.type == 'expense')
                            .fold<double>(0, (sum, t) => sum + t.amount);

                        final newBudget = Budget(
                          id: _uuid.v4(),
                          categoryId: category.id,
                          month: now.month,
                          year: now.year,
                          limit: limit,
                          spent: spent,
                        );
                        await storage.addBudget(newBudget);
                      }

                      // Also update the category's monthlyBudget
                      final updatedCategory = Category(
                        id: category.id,
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        monthlyBudget: limit,
                        type: category.type,
                        isDefault: category.isDefault,
                        createdAt: category.createdAt,
                      );
                      await storage.updateCategory(updatedCategory);

                      ref.invalidate(allCategoriesProvider);
                      ref.invalidate(allBudgetsProvider);
                      if (mounted) {
                        _showSnackBar(
                            'Budget set to ৳${_numberFormat.format(limit.toInt())}');
                      }
                    } catch (e) {
                      if (mounted) {
                        _showSnackBar('Error: $e');
                      }
                    }
                  },
                  child: const Text('Save Budget'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Delete Confirmation
  // ──────────────────────────────────────────────────────────────

  void _showDeleteConfirmation(Category category) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            'Delete ${category.name}? This will also delete all transactions in this category.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();

                try {
                  final storage = ref.read(storageServiceProvider);

                  // Delete all transactions in this category
                  final txns = storage.getTransactionsByCategory(category.id);
                  for (final t in txns) {
                    await storage.deleteTransaction(t.id);
                  }

                  // Delete any budgets for this category
                  final allBudgets = storage.getAllBudgets();
                  for (final b in allBudgets) {
                    if (b.categoryId == category.id) {
                      await storage.deleteBudget(b.id);
                    }
                  }

                  // Delete the category
                  await storage.deleteCategory(category.id);

                  ref.invalidate(allCategoriesProvider);
                  ref.invalidate(allBudgetsProvider);
                  ref.invalidate(allTransactionsProvider);
                  if (mounted) {
                    _showSnackBar('${category.name} deleted');
                  }
                } catch (e) {
                  if (mounted) {
                    _showSnackBar('Error: $e');
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Yes, Delete'),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
