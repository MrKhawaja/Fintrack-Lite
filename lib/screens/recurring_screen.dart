import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_rule.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';

final _bdtFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
final _dateDisplayFormat = DateFormat('d MMM yyyy');
const _uuid = Uuid();

// ──────────────────────────────────────────────────────────────
// Frequency helpers
// ──────────────────────────────────────────────────────────────

const _frequencyOptions = [
  ('daily', 'Daily'),
  ('weekly', 'Weekly'),
  ('monthly', 'Monthly'),
  ('yearly', 'Yearly'),
];

String _frequencyLabel(String frequency) {
  return _frequencyOptions
      .firstWhere((o) => o.$1 == frequency,
          orElse: () => (frequency, frequency))
      .$2;
}

Color _frequencyColor(String frequency, ColorScheme cs) {
  switch (frequency) {
    case 'daily':
      return cs.tertiary;
    case 'weekly':
      return cs.primary;
    case 'monthly':
      return cs.secondary;
    case 'yearly':
      return cs.error;
    default:
      return cs.outline;
  }
}

// ──────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  // ────────────────────────────────────────────────────────────
  // Toggle active/inactive
  // ────────────────────────────────────────────────────────────

  Future<void> _toggleActive(RecurringRule rule) async {
    final storage = ref.read(storageServiceProvider);
    final updated = RecurringRule(
      id: rule.id,
      amount: rule.amount,
      type: rule.type,
      categoryId: rule.categoryId,
      note: rule.note,
      frequency: rule.frequency,
      nextDueDate: rule.nextDueDate,
      isActive: !rule.isActive,
      createdAt: rule.createdAt,
    );
    await storage.updateRecurringRule(updated);
    // Invalidating the provider to refresh the list
    ref.invalidate(allRecurringRulesProvider);
  }

  // ────────────────────────────────────────────────────────────
  // Delete confirmation
  // ────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(RecurringRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recurring rule?'),
        content: const Text(
          'Previously created transactions will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteRecurringRule(rule.id);
      ref.invalidate(allRecurringRulesProvider);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Add / Edit dialog
  // ────────────────────────────────────────────────────────────

  Future<void> _showAddEditDialog(RecurringRule? existingRule) async {
    final isEditing = existingRule != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return _AddEditRecurringSheet(
          existingRule: existingRule,
          isEditing: isEditing,
        );
      },
    );

    // Refresh list when sheet closes (in case of save)
    if (mounted) {
      ref.invalidate(allRecurringRulesProvider);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rules = ref.watch(allRecurringRulesProvider);
    final categories = ref.watch(allCategoriesProvider);

    // Build a lookup map for categories
    final categoryMap = <String, dynamic>{};
    for (final c in categories) {
      categoryMap[c.id] = c;
    }

    if (rules.isEmpty) {
      return _buildEmptyState(theme, colorScheme);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rule = rules[index];
        final category = categoryMap[rule.categoryId];
        return _buildRecurringCard(rule, category, theme, colorScheme);
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Empty state
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No recurring transactions',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add rent, salary, subscriptions and more\nthat repeat on a schedule.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Recurring card
  // ────────────────────────────────────────────────────────────

  Widget _buildRecurringCard(
    RecurringRule rule,
    dynamic category,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isInactive = !rule.isActive;
    final catIcon = category?.icon as String? ?? '📋';
    final catName = category?.name as String? ?? 'Unknown';
    final catColor =
        category?.color != null ? Color(category.color as int) : Colors.grey;

    return Opacity(
      opacity: isInactive ? 0.5 : 1.0,
      child: Card(
        elevation: isInactive ? 0 : 2,
        shadowColor: isInactive ? Colors.transparent : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isInactive
              ? BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: leading icon + title + amount + switch ──
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: catColor.withValues(alpha: 0.15),
                    child: Text(catIcon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _bdtFormat.format(rule.amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: rule.type == 'income'
                                ? Colors.green.shade600
                                : colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active toggle
                  Switch(
                    value: rule.isActive,
                    onChanged: (_) => _toggleActive(rule),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Frequency badge + next due date ──
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _frequencyColor(rule.frequency, colorScheme)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _frequencyLabel(rule.frequency),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _frequencyColor(rule.frequency, colorScheme),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    'Next: ${_dateDisplayFormat.format(rule.nextDueDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // ── Note (if present) ──
              if (rule.note != null && rule.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rule.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 4),

              // ── Edit + Delete buttons ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildSmallIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    colorScheme: colorScheme,
                    onTap: () => _showAddEditDialog(rule),
                  ),
                  const SizedBox(width: 4),
                  _buildSmallIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    colorScheme: colorScheme,
                    iconColor: colorScheme.error,
                    onTap: () => _confirmDelete(rule),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required String tooltip,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Add / Edit Bottom Sheet (separate StatefulWidget for local state)
// ═══════════════════════════════════════════════════════════════

class _AddEditRecurringSheet extends ConsumerStatefulWidget {
  final RecurringRule? existingRule;
  final bool isEditing;

  const _AddEditRecurringSheet({
    required this.existingRule,
    required this.isEditing,
  });

  @override
  ConsumerState<_AddEditRecurringSheet> createState() =>
      _AddEditRecurringSheetState();
}

class _AddEditRecurringSheetState
    extends ConsumerState<_AddEditRecurringSheet> {
  late String _type;
  late final TextEditingController _amountController;
  late String? _selectedCategoryId;
  late String _frequency;
  late DateTime _startDate;
  late final TextEditingController _noteController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _type = rule?.type ?? 'expense';
    _amountController = TextEditingController(
      text: rule != null ? rule.amount.toStringAsFixed(0) : '',
    );
    _selectedCategoryId = rule?.categoryId;
    _frequency = rule?.frequency ?? 'monthly';
    _startDate = rule?.nextDueDate ?? DateTime.now();
    _noteController = TextEditingController(text: rule?.note ?? '');
    _isActive = rule?.isActive ?? true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // Validation
  // ────────────────────────────────────────────────────────────

  bool get _canSave {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return amount > 0 && _selectedCategoryId != null;
  }

  // ────────────────────────────────────────────────────────────
  // Save
  // ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showSnack('Please enter a valid amount greater than 0');
      return;
    }
    if (_selectedCategoryId == null) {
      _showSnack('Please select a category');
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final rule = RecurringRule(
      id: widget.existingRule?.id ?? _uuid.v4(),
      amount: amount,
      type: _type,
      categoryId: _selectedCategoryId!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      frequency: _frequency,
      nextDueDate: _startDate,
      isActive: _isActive,
      createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.isEditing) {
        await storage.updateRecurringRule(rule);
      } else {
        await storage.addRecurringRule(rule);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Failed to save: $e');
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allCategories = ref.watch(allCategoriesProvider);
    final filteredCategories =
        allCategories.where((c) => c.type == _type).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (scrollCtx, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(scrollCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                widget.isEditing
                    ? 'Edit Recurring Transaction'
                    : 'Add Recurring Transaction',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // ── SECTION 1: Type Toggle ──
              _buildTypeToggle(colorScheme),

              const SizedBox(height: 20),

              // ── SECTION 2: Amount ──
              _buildAmountField(theme, colorScheme),

              const SizedBox(height: 20),

              // ── SECTION 3: Category Picker ──
              _buildCategoryPicker(theme, colorScheme, filteredCategories),

              const SizedBox(height: 20),

              // ── SECTION 4: Frequency ──
              _buildFrequencyDropdown(theme, colorScheme),

              const SizedBox(height: 20),

              // ── SECTION 5: Start Date ──
              _buildStartDatePicker(theme, colorScheme),

              const SizedBox(height: 20),

              // ── SECTION 6: Note ──
              _buildNoteField(theme, colorScheme),

              const SizedBox(height: 20),

              // ── SECTION 7: Active Toggle ──
              _buildActiveToggle(theme, colorScheme),

              const SizedBox(height: 24),

              // ── SECTION 8: Buttons ──
              _buildActionButtons(theme, colorScheme),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 1: Type Toggle
  // ────────────────────────────────────────────────────────────

  Widget _buildTypeToggle(ColorScheme colorScheme) {
    return Center(
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment<String>(
            value: 'expense',
            label: Text('Expense'),
            icon: Icon(Icons.trending_down_rounded, size: 18),
          ),
          ButtonSegment<String>(
            value: 'income',
            label: Text('Income'),
            icon: Icon(Icons.trending_up_rounded, size: 18),
          ),
        ],
        selected: {_type},
        onSelectionChanged: (selected) {
          setState(() {
            _type = selected.first;
            _selectedCategoryId = null; // reset category on type switch
          });
        },
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 2: Amount
  // ────────────────────────────────────────────────────────────

  Widget _buildAmountField(ThemeData theme, ColorScheme colorScheme) {
    return TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
        prefixText: '৳ ',
        prefixStyle: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 3: Category Picker
  // ────────────────────────────────────────────────────────────

  Widget _buildCategoryPicker(
    ThemeData theme,
    ColorScheme colorScheme,
    List<dynamic> categories,
  ) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No ${_type == 'expense' ? 'expense' : 'income'} categories available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index] as dynamic;
              final isSelected = _selectedCategoryId == category.id;
              final catColor = Color(category.color as int);

              return ChoiceChip(
                selected: isSelected,
                showCheckmark: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isSelected
                          ? Colors.white24
                          : catColor.withValues(alpha: 0.2),
                      child: Text(
                        category.icon as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.name as String,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                selectedColor: catColor,
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                side: isSelected
                    ? BorderSide(color: catColor, width: 1.5)
                    : BorderSide(color: colorScheme.outlineVariant),
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryId =
                        selected ? category.id as String : null;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 4: Frequency
  // ────────────────────────────────────────────────────────────

  Widget _buildFrequencyDropdown(ThemeData theme, ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      initialValue: _frequency,
      decoration: InputDecoration(
        labelText: 'Frequency',
        prefixIcon: const Icon(Icons.repeat_rounded, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
      items: _frequencyOptions.map((opt) {
        return DropdownMenuItem<String>(
          value: opt.$1,
          child: Text(opt.$2),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _frequency = value);
        }
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 5: Start Date
  // ────────────────────────────────────────────────────────────

  Widget _buildStartDatePicker(ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (picked != null && mounted) {
          setState(() => _startDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              'Start Date',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              _dateDisplayFormat.format(_startDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 6: Note
  // ────────────────────────────────────────────────────────────

  Widget _buildNoteField(ThemeData theme, ColorScheme colorScheme) {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        labelText: 'Note (optional)',
        hintText: 'e.g. Monthly rent payment',
        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
      ),
      style: theme.textTheme.bodyMedium,
      maxLines: 2,
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 7: Active Toggle
  // ────────────────────────────────────────────────────────────

  Widget _buildActiveToggle(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
            size: 22,
            color: _isActive ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Active',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // SECTION 8: Action Buttons
  // ────────────────────────────────────────────────────────────

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(widget.isEditing ? 'Update' : 'Save'),
          ),
        ),
      ],
    );
  }
}
