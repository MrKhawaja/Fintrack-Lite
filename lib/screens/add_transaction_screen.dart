import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/transaction.dart';
import '../models/budget.dart';
import '../providers/category_provider.dart';
import '../services/calculator_service.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';

final _bdtFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
final _dateDisplayFormat = DateFormat('MMM d, yyyy');

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final CalculatorService _calculatorService = CalculatorService();
  final Uuid _uuid = const Uuid();
  final ImagePicker _imagePicker = ImagePicker();

  String _expression = '0';
  String _displayValue = '0';
  String _type = 'expense'; // 'expense' or 'income'
  String? _selectedCategoryId;
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _expressionEvaluated = false;

  // ── Tags ──
  final List<String> _tags = [];

  // ── Receipt ──
  String? _receiptPath;
  File? _receiptFile;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  //  Expression Helpers
  // ──────────────────────────────────────────────────────────────

  String _getLastNumber(String expr) {
    final match = RegExp(r'[\d.]+$').firstMatch(expr);
    return match?.group(0) ?? '0';
  }

  bool get _endsWithOperator {
    final last = _expression.characters.lastOrNull;
    return last == '+' || last == '-' || last == '*' || last == '/';
  }

  // ──────────────────────────────────────────────────────────────
  //  Keypad Handlers
  // ──────────────────────────────────────────────────────────────

  void _handleDigit(String digit) {
    setState(() {
      if (_expressionEvaluated) {
        _expression = digit;
        _displayValue = digit;
        _expressionEvaluated = false;
      } else if (_expression == '0') {
        _expression = digit;
        _displayValue = digit;
      } else {
        _expression += digit;
        _displayValue = _getLastNumber(_expression);
      }
    });
  }

  void _handleOperator(String op) {
    setState(() {
      _expressionEvaluated = false;
      if (_endsWithOperator) {
        _expression = _expression.substring(0, _expression.length - 1) + op;
      } else {
        _expression += op;
      }
    });
  }

  void _handleDecimal() {
    setState(() {
      if (_expressionEvaluated) {
        _expression = '0.';
        _displayValue = '0.';
        _expressionEvaluated = false;
        return;
      }
      final lastNumber = _getLastNumber(_expression);
      if (lastNumber.contains('.')) return;
      _expression += '.';
      _displayValue = _getLastNumber(_expression);
    });
  }

  void _handleBackspace() {
    setState(() {
      if (_expressionEvaluated) {
        _expression = '0';
        _displayValue = '0';
        _expressionEvaluated = false;
        return;
      }
      if (_expression.length <= 1) {
        _expression = '0';
        _displayValue = '0';
      } else {
        _expression = _expression.substring(0, _expression.length - 1);
        _displayValue = _getLastNumber(_expression);
      }
    });
  }

  void _handleEquals() {
    setState(() {
      try {
        final result = _calculatorService.evaluate(_expression);
        _displayValue = result.toString();
        _expression = result.toString();
        _expressionEvaluated = true;
      } catch (_) {
        _displayValue = 'Error';
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _displayValue = '0';
              _expression = '0';
              _expressionEvaluated = false;
            });
          }
        });
      }
    });
  }

  void _onKeyPressed(String key) {
    switch (key) {
      case '⌫':
        _handleBackspace();
      case '=':
        _handleEquals();
      case '+':
      case '-':
      case '*':
        _handleOperator(key);
      case '.':
        _handleDecimal();
      default:
        _handleDigit(key);
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Display Formatting
  // ──────────────────────────────────────────────────────────────

  String _formatDisplay() {
    if (_displayValue == 'Error') return 'Error';
    final parsed = double.tryParse(_displayValue);
    if (parsed != null) {
      return _bdtFormat.format(parsed);
    }
    return _displayValue;
  }

  // ──────────────────────────────────────────────────────────────
  //  Validation
  // ──────────────────────────────────────────────────────────────

  bool get _canSave {
    final amount = double.tryParse(_displayValue) ?? 0;
    return amount > 0 && _selectedCategoryId != null;
  }

  // ──────────────────────────────────────────────────────────────
  //  Tags
  // ──────────────────────────────────────────────────────────────

  void _showAddTagDialog() {
    final tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: tagController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter tag name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            _addTag(val.trim());
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addTag(tagController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addTag(String tag) {
    if (tag.isEmpty) return;
    if (!tag.startsWith('#')) {
      tag = '#$tag';
    }
    if (!_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  // ──────────────────────────────────────────────────────────────
  //  Receipt Photo
  // ──────────────────────────────────────────────────────────────

  Future<void> _showReceiptOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            if (_receiptPath != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _receiptPath = null;
                    _receiptFile = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked != null) {
        // Save to app's document directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
        final savedFile = File(p.join(appDir.path, fileName));
        await File(picked.path).copy(savedFile.path);

        setState(() {
          _receiptFile = savedFile;
          _receiptPath = savedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Save Logic
  // ──────────────────────────────────────────────────────────────

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_displayValue) ?? 0;
    if (amount <= 0) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final storage = ref.read(storageServiceProvider);

    final transaction = Transaction(
      id: _uuid.v4(),
      amount: amount,
      type: _type,
      categoryId: _selectedCategoryId!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      date: _selectedDate,
      tags: List<String>.from(_tags),
      receiptPath: _receiptPath,
    );

    try {
      await storage.addTransaction(transaction);

      // Update budget spent amount for expense transactions
      if (_type == 'expense') {
        final budget = storage.getBudgetByCategory(_selectedCategoryId!);
        if (budget != null) {
          final updatedBudget = Budget(
            id: budget.id,
            categoryId: budget.categoryId,
            month: budget.month,
            year: budget.year,
            limit: budget.limit,
            spent: budget.spent + amount,
          );
          await storage.updateBudget(updatedBudget);
        }
      }

      // Record streak
      final streakService = StreakService();
      await streakService.initialize();
      await streakService.recordLog();

      // Check budget thresholds
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.checkBudgetThresholds(storage);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transaction: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allCategories = ref.watch(allCategoriesProvider);
    final filteredCategories =
        allCategories.where((c) => c.type == _type).toList();

    final showExpression = _expression != _displayValue &&
        _expression != '0' &&
        !_expressionEvaluated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ── SECTION 1: Type Toggle ──
              _buildTypeToggle(colorScheme),

              const SizedBox(height: 16),

              // ── SECTION 2: Amount Display ──
              _buildAmountDisplay(theme, colorScheme, showExpression),

              const SizedBox(height: 8),

              // ── SECTION 3: Numeric Keypad ──
              _buildKeypad(theme, colorScheme),

              const SizedBox(height: 16),

              // ── SECTION 4: Category Picker ──
              _buildCategoryPicker(theme, colorScheme, filteredCategories),

              const SizedBox(height: 16),

              // ── SECTION 5: Note & Date ──
              _buildNoteAndDate(theme, colorScheme),

              const SizedBox(height: 12),

              // ── SECTION 6: Tags ──
              _buildTagsSection(theme, colorScheme),

              const SizedBox(height: 12),

              // ── SECTION 7: Receipt Photo ──
              _buildReceiptSection(theme, colorScheme),

              const SizedBox(height: 20),

              // ── SECTION 8: Save Button ──
              _buildSaveButton(theme, colorScheme),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 1: Type Toggle
  // ──────────────────────────────────────────────────────────────

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
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 2: Amount Display
  // ──────────────────────────────────────────────────────────────

  Widget _buildAmountDisplay(
    ThemeData theme,
    ColorScheme colorScheme,
    bool showExpression,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showExpression)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _expression,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _formatDisplay(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 44,
                color: _displayValue == 'Error'
                    ? colorScheme.error
                    : colorScheme.onSurface,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 3: Numeric Keypad
  // ──────────────────────────────────────────────────────────────

  Widget _buildKeypad(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Row 1: [7] [8] [9]
        Row(
          children: [
            _buildNumButton('7', theme, colorScheme),
            _buildNumButton('8', theme, colorScheme),
            _buildNumButton('9', theme, colorScheme),
          ],
        ),
        // Row 2: [4] [5] [6]
        Row(
          children: [
            _buildNumButton('4', theme, colorScheme),
            _buildNumButton('5', theme, colorScheme),
            _buildNumButton('6', theme, colorScheme),
          ],
        ),
        // Row 3: [1] [2] [3]
        Row(
          children: [
            _buildNumButton('1', theme, colorScheme),
            _buildNumButton('2', theme, colorScheme),
            _buildNumButton('3', theme, colorScheme),
          ],
        ),
        // Row 4: [.] [0] [⌫]
        Row(
          children: [
            _buildNumButton('.', theme, colorScheme),
            _buildNumButton('0', theme, colorScheme),
            _buildBackspaceButton(theme, colorScheme),
          ],
        ),
        // Row 5: [+] [-] [*] [=]
        Row(
          children: [
            _buildOperatorButton('+', theme, colorScheme),
            _buildOperatorButton('-', theme, colorScheme),
            _buildOperatorButton('*', theme, colorScheme),
            _buildEqualsButton(theme, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _buildNumButton(
    String label,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onKeyPressed(label),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(
    String label,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onKeyPressed(label),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme, ColorScheme colorScheme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onKeyPressed('⌫'),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Icon(
                Icons.backspace_outlined,
                size: 24,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEqualsButton(ThemeData theme, ColorScheme colorScheme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onKeyPressed('='),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(
                '=',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 4: Category Picker
  // ──────────────────────────────────────────────────────────────

  Widget _buildCategoryPicker(
    ThemeData theme,
    ColorScheme colorScheme,
    List<dynamic> categories,
  ) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No ${_type == 'expense' ? 'expense' : 'income'} categories yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                _selectedCategoryId = selected ? category.id as String : null;
              });
            },
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 5: Note & Date
  // ──────────────────────────────────────────────────────────────

  Widget _buildNoteAndDate(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            hintText: 'Add a note...',
            prefixIcon: const Icon(Icons.note_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
              });
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
                  'Date',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _dateDisplayFormat.format(_selectedDate),
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
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 6: Tags
  // ──────────────────────────────────────────────────────────────

  Widget _buildTagsSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_outline_rounded,
                size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Tags',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _showAddTagDialog,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 16, color: colorScheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      'Add Tag',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _removeTag(tag),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 7: Receipt Photo
  // ──────────────────────────────────────────────────────────────

  Widget _buildReceiptSection(ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _showReceiptOptions,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _receiptFile != null
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _receiptFile!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Receipt attached',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: colorScheme.error),
                    onPressed: () {
                      setState(() {
                        _receiptPath = null;
                        _receiptFile = null;
                      });
                    },
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    'Add Receipt Photo',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SECTION 8: Save Button
  // ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton(ThemeData theme, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _canSave ? _saveTransaction : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Save Transaction'),
      ),
    );
  }
}
