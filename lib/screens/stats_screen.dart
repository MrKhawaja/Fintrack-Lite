import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/stats_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';

final _currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _weekOffset = 0;
  int _monthOffset = 0;
  int _selectedYear = DateTime.now().year;
  int? _selectedDayIndex;
  String? _selectedCategoryId;

  // ──────────────────────────────────────────────────────────
  //  Helpers: week / month / year computation
  // ──────────────────────────────────────────────────────────

  DateTime _getWeekStart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of the current week (Dart: weekday 1 = Monday)
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return monday.add(Duration(days: _weekOffset * 7));
  }

  ({int month, int year}) _getTargetMonth() {
    final now = DateTime.now();
    // total months since year 0 (0-indexed)
    final totalMonths = now.year * 12 + now.month - 1 + _monthOffset;
    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;
    return (month: month, year: year);
  }

  ({int minYear, int maxYear}) _getYearRange(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      final y = DateTime.now().year;
      return (minYear: y, maxYear: y);
    }
    int minY = DateTime.now().year;
    int maxY = DateTime.now().year;
    for (final t in transactions) {
      if (t.date.year < minY) minY = t.date.year;
      if (t.date.year > maxY) maxY = t.date.year;
    }
    return (minYear: minY, maxYear: maxY);
  }

  // ──────────────────────────────────────────────────────────
  //  Data builders
  // ──────────────────────────────────────────────────────────

  List<DailySpending> _buildWeekData(List<Transaction> allTransactions) {
    final weekStart = _getWeekStart();
    final data = <DailySpending>[];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final total = allTransactions
          .where(
            (t) =>
                t.type == 'expense' &&
                t.date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
                t.date.isBefore(dayEnd),
          )
          .fold<double>(0, (sum, t) => sum + t.amount);
      data.add(DailySpending(date: date, amount: total));
    }
    return data;
  }

  List<Transaction> _getDayTransactions(
    List<Transaction> allTransactions,
    DateTime date,
  ) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return allTransactions
        .where(
          (t) =>
              t.date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(dayEnd),
        )
        .toList();
  }

  double _getMonthExpense(List<Transaction> monthTransactions) {
    return monthTransactions
        .where((t) => t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  double _getMonthIncome(List<Transaction> monthTransactions) {
    return monthTransactions
        .where((t) => t.type == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  List<CategoryBreakdown> _buildMonthBreakdown(
    List<Transaction> monthTransactions,
    List<Category> categories,
  ) {
    final catMap = <String, Category>{};
    for (final c in categories) {
      catMap[c.id] = c;
    }

    final expensesByCategory = <String, double>{};
    double totalExpenses = 0;

    for (final t in monthTransactions) {
      if (t.type == 'expense') {
        expensesByCategory[t.categoryId] =
            (expensesByCategory[t.categoryId] ?? 0) + t.amount;
        totalExpenses += t.amount;
      }
    }

    final breakdown = <CategoryBreakdown>[];
    for (final entry in expensesByCategory.entries) {
      final cat = catMap[entry.key];
      breakdown.add(
        CategoryBreakdown(
          categoryId: entry.key,
          categoryName: cat?.name ?? 'Unknown',
          icon: cat?.icon ?? '💰',
          color: cat?.color ?? 0xFF000000,
          amount: entry.value,
          percentage:
              totalExpenses > 0 ? (entry.value / totalExpenses * 100) : 0.0,
        ),
      );
    }
    breakdown.sort((a, b) => b.amount.compareTo(a.amount));
    return breakdown;
  }

  List<MonthlyBreakdown> _buildYearBreakdown(
    List<Transaction> allTransactions,
    int year,
  ) {
    final breakdowns = <int, MonthlyBreakdown>{};
    for (int m = 1; m <= 12; m++) {
      breakdowns[m] = MonthlyBreakdown(month: m, income: 0, expense: 0);
    }

    for (final t in allTransactions) {
      if (t.date.year != year) continue;
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
  }

  // ──────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
                Tab(text: 'Yearly'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildWeekTab(),
                  _buildMonthTab(),
                  _buildYearTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  TAB 1: Weekly
  // ──────────────────────────────────────────────────────────

  Widget _buildWeekTab() {
    final allTransactions = ref.watch(allTransactionsProvider);
    final categories = ref.watch(allCategoriesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final weekStart = _getWeekStart();
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekData = _buildWeekData(allTransactions);
    final hasData = weekData.any((d) => d.amount > 0);
    final weekTotal = weekData.fold<double>(0, (sum, d) => sum + d.amount);

    final dateFormat = DateFormat('MMM d');
    final weekLabel =
        '${dateFormat.format(weekStart)} — ${dateFormat.format(weekEnd)}';

    // Build filtered transactions for selected day
    List<Transaction> filteredTransactions = [];
    if (_selectedDayIndex != null && _selectedDayIndex! < weekData.length) {
      filteredTransactions = _getDayTransactions(
          allTransactions, weekData[_selectedDayIndex!].date);
    }

    // Category lookup
    final catMap = <String, Category>{};
    for (final c in categories) {
      catMap[c.id] = c;
    }

    // Ensure selected index stays in range
    final safeDayIndex =
        (_selectedDayIndex != null && _selectedDayIndex! < weekData.length)
            ? _selectedDayIndex
            : null;

    return Column(
      children: [
        // Week navigation
        _buildNavigationHeader(
          label: weekLabel,
          onBack: () => setState(() {
            _weekOffset--;
            _selectedDayIndex = null;
          }),
          onForward: () => setState(() {
            _weekOffset++;
            _selectedDayIndex = null;
          }),
          canGoForward: _weekOffset < 0,
          theme: theme,
          colorScheme: colorScheme,
        ),

        // Total row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                'Total: ',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _currencyFormat.format(weekTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Chart or empty
        Expanded(
          child: hasData
              ? Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildWeekBarChart(
                        weekData,
                        safeDayIndex,
                        theme,
                        colorScheme,
                      ),
                    ),
                    if (safeDayIndex != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_dayLabels[safeDayIndex]} — ${dateFormat.format(weekData[safeDayIndex].date)}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedDayIndex = null),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      flex: 4,
                      child: safeDayIndex != null
                          ? _buildTransactionList(
                              filteredTransactions,
                              catMap,
                              theme,
                              colorScheme,
                              emptyMessage:
                                  'No transactions for ${_dayLabels[safeDayIndex]}',
                            )
                          : _buildTapHint(theme, colorScheme),
                    ),
                  ],
                )
              : _buildEmptyState(
                  icon: Icons.bar_chart_rounded,
                  message: 'No data for this week',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
        ),
      ],
    );
  }

  Widget _buildWeekBarChart(
    List<DailySpending> weekData,
    int? selectedIndex,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final maxY =
        weekData.map((d) => d.amount).fold<double>(0, (a, b) => a > b ? a : b) *
            1.2;
    final effectiveMaxY = maxY > 0 ? maxY : 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: effectiveMaxY,
          barGroups: weekData.asMap().entries.map((entry) {
            final i = entry.key;
            final day = entry.value;
            final isSelected = selectedIndex == i;

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: day.amount,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.55),
                  width: isSelected ? 20 : 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < weekData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _dayLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: colorScheme.surfaceContainerHigh,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = weekData[group.x];
                return BarTooltipItem(
                  '${_dayLabels[group.x]}\n${_currencyFormat.format(day.amount)}',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
              if (event is FlTapUpEvent && response?.spot != null) {
                final tappedIndex = response!.spot!.touchedBarGroupIndex;
                setState(() {
                  if (_selectedDayIndex == tappedIndex) {
                    _selectedDayIndex = null;
                  } else {
                    _selectedDayIndex = tappedIndex;
                  }
                });
              }
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  TAB 2: Monthly
  // ──────────────────────────────────────────────────────────

  Widget _buildMonthTab() {
    final categories = ref.watch(allCategoriesProvider);
    final target = _getTargetMonth();
    final monthTransactions = ref.watch(
      monthlyTransactionsProvider((month: target.month, year: target.year)),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalExpense = _getMonthExpense(monthTransactions);
    final totalIncome = _getMonthIncome(monthTransactions);
    final breakdown = _buildMonthBreakdown(monthTransactions, categories);
    final hasData = breakdown.isNotEmpty;

    // Category lookup
    final catMap = <String, Category>{};
    for (final c in categories) {
      catMap[c.id] = c;
    }

    // Filtered transactions for selected category
    List<Transaction> filteredTransactions = [];
    if (_selectedCategoryId != null) {
      filteredTransactions = monthTransactions
          .where((t) => t.categoryId == _selectedCategoryId)
          .toList();
    }

    final monthLabel = '${_monthNames[target.month - 1]} ${target.year}';

    return Column(
      children: [
        // Month navigation
        _buildNavigationHeader(
          label: monthLabel,
          onBack: () => setState(() {
            _monthOffset--;
            _selectedCategoryId = null;
          }),
          onForward: () => setState(() {
            _monthOffset++;
            _selectedCategoryId = null;
          }),
          canGoForward: _monthOffset < 0,
          theme: theme,
          colorScheme: colorScheme,
        ),

        // Summary row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total Spent: ${_currencyFormat.format(totalExpense)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Income: ${_currencyFormat.format(totalIncome)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Chart or empty
        Expanded(
          child: hasData
              ? Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildMonthPieChart(
                        breakdown,
                        theme,
                        colorScheme,
                      ),
                    ),
                    if (_selectedCategoryId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Filtered by category',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedCategoryId = null),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      flex: 4,
                      child: _selectedCategoryId != null
                          ? _buildTransactionList(
                              filteredTransactions,
                              catMap,
                              theme,
                              colorScheme,
                              emptyMessage: 'No transactions for this category',
                            )
                          : _buildTapHint(theme, colorScheme),
                    ),
                  ],
                )
              : _buildEmptyState(
                  icon: Icons.pie_chart_rounded,
                  message: 'No data for this month',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
        ),
      ],
    );
  }

  Widget _buildMonthPieChart(
    List<CategoryBreakdown> breakdown,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final totalSpent = breakdown.fold<double>(0, (sum, b) => sum + b.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 48,
          sectionsSpace: 2,
          sections: breakdown.map((b) {
            final isSelected = _selectedCategoryId == b.categoryId;
            final baseColor = Color(b.color);
            return PieChartSectionData(
              color: isSelected ? baseColor : baseColor.withValues(alpha: 0.8),
              value: b.amount,
              title: '${b.percentage.toStringAsFixed(1)}%',
              radius: isSelected ? 70 : 58,
              titleStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimary,
              ),
              badgeWidget: b.percentage >= 6
                  ? Text(
                      b.icon,
                      style: const TextStyle(fontSize: 16),
                    )
                  : null,
              badgePositionPercentageOffset: 70,
            );
          }).toList(),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
              if (event is FlTapUpEvent &&
                  response?.touchedSection != null &&
                  response!.touchedSection!.touchedSectionIndex >= 0) {
                final index = response.touchedSection!.touchedSectionIndex;
                if (index < breakdown.length) {
                  setState(() {
                    final tappedId = breakdown[index].categoryId;
                    if (_selectedCategoryId == tappedId) {
                      _selectedCategoryId = null;
                    } else {
                      _selectedCategoryId = tappedId;
                    }
                  });
                }
              }
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  TAB 3: Yearly
  // ──────────────────────────────────────────────────────────

  Widget _buildYearTab() {
    final allTransactions = ref.watch(allTransactionsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final yearRange = _getYearRange(allTransactions);
    final breakdown = _buildYearBreakdown(allTransactions, _selectedYear);
    final hasData = breakdown.any((m) => m.expense > 0 || m.income > 0);

    final yearTotal = breakdown.fold<double>(0, (sum, m) => sum + m.expense);
    final monthsWithData =
        breakdown.where((m) => m.expense > 0 || m.income > 0).length;
    final avgPerMonth = monthsWithData > 0 ? yearTotal / monthsWithData : 0.0;

    return Column(
      children: [
        // Year navigation
        _buildYearNavigation(
          selectedYear: _selectedYear,
          minYear: yearRange.minYear,
          maxYear: yearRange.maxYear,
          onYearChanged: (year) => setState(() => _selectedYear = year),
          theme: theme,
          colorScheme: colorScheme,
        ),

        // Summary row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${_currencyFormat.format(yearTotal)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Avg/month: ${_currencyFormat.format(avgPerMonth)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Chart or empty
        Expanded(
          child: hasData
              ? Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildYearBarChart(
                        breakdown,
                        theme,
                        colorScheme,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildYearSummaryCards(
                        breakdown,
                        theme,
                        colorScheme,
                      ),
                    ),
                  ],
                )
              : _buildEmptyState(
                  icon: Icons.show_chart_rounded,
                  message: 'No data for $_selectedYear',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
        ),
      ],
    );
  }

  Widget _buildYearBarChart(
    List<MonthlyBreakdown> breakdown,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final maxY = breakdown
            .map((m) => m.expense > m.income ? m.expense : m.income)
            .fold<double>(0, (a, b) => a > b ? a : b) *
        1.2;
    final effectiveMaxY = maxY > 0 ? maxY : 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: effectiveMaxY,
          barGroups: breakdown.map((m) {
            return BarChartGroupData(
              x: m.month - 1,
              barRods: [
                BarChartRodData(
                  toY: m.expense,
                  color: Colors.redAccent.withValues(alpha: 0.7),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: m.income,
                  color: Colors.green.withValues(alpha: 0.7),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _monthLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _monthLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: colorScheme.surfaceContainerHigh,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final m = breakdown[group.x];
                final label = rodIndex == 0 ? 'Expense' : 'Income';
                final amount = rodIndex == 0 ? m.expense : m.income;
                return BarTooltipItem(
                  '${_monthNames[m.month - 1]} $label\n${_currencyFormat.format(amount)}',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearSummaryCards(
    List<MonthlyBreakdown> breakdown,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final totalIncome = breakdown.fold<double>(0, (sum, m) => sum + m.income);
    final totalExpense = breakdown.fold<double>(0, (sum, m) => sum + m.expense);
    final balance = totalIncome - totalExpense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Income vs Expense',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.trending_down_rounded,
                  label: 'Expenses',
                  amount: totalExpense,
                  amountColor: Colors.redAccent,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  iconColor: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Income',
                  amount: totalIncome,
                  amountColor: Colors.green,
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  iconColor: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Balance',
                  amount: balance,
                  amountColor:
                      balance >= 0 ? Colors.blueAccent : Colors.redAccent,
                  backgroundColor:
                      (balance >= 0 ? Colors.blueAccent : Colors.redAccent)
                          .withValues(alpha: 0.1),
                  iconColor:
                      balance >= 0 ? Colors.blueAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Shared widgets
  // ──────────────────────────────────────────────────────────

  Widget _buildNavigationHeader({
    required String label,
    required VoidCallback onBack,
    required VoidCallback onForward,
    required bool canGoForward,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final isCurrent = !canGoForward && _weekOffset == 0 && _monthOffset == 0;
    // Actually, we just check if forward button should be enabled:
    // only disable if we're at "now" (can't go to future weeks/months)
    final showForward = _weekOffset < 0 || _monthOffset < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous',
            style: IconButton.styleFrom(
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next',
            style: IconButton.styleFrom(
              backgroundColor: canGoForward
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearNavigation({
    required int selectedYear,
    required int minYear,
    required int maxYear,
    required ValueChanged<int> onYearChanged,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: selectedYear > minYear
                ? () => onYearChanged(selectedYear - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous year',
            style: IconButton.styleFrom(
              backgroundColor: selectedYear > minYear
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$selectedYear',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: selectedYear < maxYear
                ? () => onYearChanged(selectedYear + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next year',
            style: IconButton.styleFrom(
              backgroundColor: selectedYear < maxYear
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    List<Transaction> transactions,
    Map<String, Category> categoryMap,
    ThemeData theme,
    ColorScheme colorScheme, {
    String emptyMessage = 'No transactions',
  }) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final t = sorted[index];
        final category = categoryMap[t.categoryId];
        final isIncome = t.type == 'income';
        final amountColor = isIncome ? Colors.green : Colors.redAccent;
        final amountPrefix = isIncome ? '+' : '-';
        final timeString = DateFormat('h:mm a').format(t.date);

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Color(category?.color ?? colorScheme.primary.toARGB32())
                      .withValues(alpha: 0.15),
              child: Text(
                category?.icon ?? '💰',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: Text(
              category?.name ?? 'Unknown',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              t.note != null && t.note!.isNotEmpty ? t.note! : timeString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '$amountPrefix${_currencyFormat.format(t.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  Widget _buildTapHint(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 40,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a segment to see transactions',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting the date range',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Summary Card (reused from home_screen)
// ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color amountColor;
  final Color backgroundColor;
  final Color iconColor;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.amountColor,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: amountColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              _currencyFormat.format(amount),
              style: theme.textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
