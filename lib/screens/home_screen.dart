import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/stats_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/insights_provider.dart';
import '../providers/streak_provider.dart';
import 'add_transaction_screen.dart';
import 'stats_screen.dart';
import 'categories_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

final _currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  // ── Search & Filter state ──
  bool _showSearch = false;
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Active quick filters
  String? _dateFilter; // 'this_week', 'this_month', 'last_month'
  String? _typeFilter; // 'expense', 'income'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatsScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _navigateToAddTransaction() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
    if (result == true) {
      _invalidateProviders();
    }
  }

  void _invalidateProviders() {
    ref.invalidate(todaySpentProvider);
    ref.invalidate(todayIncomeProvider);
    ref.invalidate(monthlyBalanceProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(weeklyChartDataProvider);
    ref.invalidate(insightsProvider);
    ref.invalidate(streakProvider);
  }

  Future<void> _onRefresh() async {
    _invalidateProviders();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  // ── Filter helpers ──

  TransactionFilters _buildFilters() {
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_dateFilter) {
      case 'this_week':
        startDate = today.subtract(Duration(days: today.weekday - 1));
        endDate = today.add(const Duration(days: 1));
      case 'this_month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = today.add(const Duration(days: 1));
      case 'last_month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = firstOfThisMonth;
      default:
        break;
    }

    // Also search by amount if the query is numeric
    double? searchAmount;
    if (_searchQuery.isNotEmpty) {
      searchAmount = double.tryParse(_searchQuery);
    }

    return TransactionFilters(
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      startDate: startDate,
      endDate: endDate,
      type: _typeFilter,
      minAmount: searchAmount,
      maxAmount: searchAmount,
    );
  }

  Map<DateTime, List<Transaction>> _groupByDate(
      List<Transaction> transactions) {
    final grouped = <DateTime, List<Transaction>>{};
    for (final t in transactions) {
      final dateKey = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(dateKey, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: grouped[k]!};
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
  }

  // ── Delete confirmation ──

  Future<void> _confirmDelete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete this '
          '${transaction.type == 'income' ? 'income' : 'expense'} '
          'of ${_currencyFormat.format(transaction.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteTransaction(transaction.id);
      _invalidateProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await storage.addTransaction(transaction);
                _invalidateProviders();
              },
            ),
          ),
        );
      }
    }
  }

  // ── Clear filters ──

  void _clearFilters() {
    setState(() {
      _dateFilter = null;
      _typeFilter = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final todaySpent = ref.watch(todaySpentProvider);
    final todayIncome = ref.watch(todayIncomeProvider);
    final monthBalance = ref.watch(monthlyBalanceProvider);
    final allTransactions = ref.watch(allTransactionsProvider);
    final weeklyData = ref.watch(weeklyChartDataProvider);
    final categories = ref.watch(allCategoriesProvider);
    final insights = ref.watch(insightsProvider);
    final streakAsync = ref.watch(streakProvider);

    // Determine which transactions to show
    final hasActiveFilters = _showSearch &&
        (_searchQuery.isNotEmpty || _dateFilter != null || _typeFilter != null);
    List<Transaction> displayTransactions;
    if (hasActiveFilters) {
      final filters = _buildFilters();
      // Manual filtering to handle amount matching nicely
      displayTransactions = allTransactions.where((t) {
        if (filters.type != null && t.type != filters.type) return false;
        if (filters.startDate != null && t.date.isBefore(filters.startDate!)) {
          return false;
        }
        if (filters.endDate != null) {
          final endDay = DateTime(filters.endDate!.year, filters.endDate!.month,
              filters.endDate!.day);
          if (t.date.isAfter(endDay
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)))) {
            return false;
          }
        }
        if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
          final query = filters.searchQuery!.toLowerCase();
          final category =
              ref.read(storageServiceProvider).getCategoryById(t.categoryId);
          final catName = category?.name.toLowerCase() ?? '';
          final note = t.note?.toLowerCase() ?? '';

          // Check if query is a number for amount matching
          final amountMatch =
              double.tryParse(query) != null && t.amount == double.parse(query);

          if (!catName.contains(query) &&
              !note.contains(query) &&
              !amountMatch) {
            return false;
          }
        }
        return true;
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } else {
      final sortedTransactions = List<Transaction>.from(allTransactions)
        ..sort((a, b) => b.date.compareTo(a.date));
      displayTransactions = sortedTransactions.take(20).toList();
    }

    // Build category lookup
    final categoryMap = <String, Category>{};
    for (final c in categories) {
      categoryMap[c.id] = c;
    }

    final grouped = _groupByDate(displayTransactions);
    final hasWeeklyData = weeklyData.any((d) => d.amount > 0);
    final streakCount = streakAsync.valueOrNull ?? 0;
    final hasActiveFilter = hasActiveFilters ||
        (_showSearch &&
            (_dateFilter != null ||
                _searchQuery.isNotEmpty ||
                _typeFilter != null));

    final tabTitles = [
      'FinTrack Lite',
      'Statistics',
      'Categories & Budgets',
      'Recurring Transactions'
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[_currentIndex]),
        centerTitle: true,
        leading: _currentIndex != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Home',
                onPressed: () => _onTabTapped(0),
              )
            : null,
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: Icon(_showSearch
                      ? Icons.search_off_rounded
                      : Icons.search_rounded),
                  tooltip: _showSearch ? 'Close search' : 'Search',
                  onPressed: () {
                    setState(() {
                      if (_showSearch) {
                        _showSearch = false;
                        _showFilters = false;
                        _searchController.clear();
                        _searchQuery = '';
                        _dateFilter = null;
                        _typeFilter = null;
                      } else {
                        _showSearch = true;
                      }
                    });
                  },
                ),
                if (_showSearch)
                  IconButton(
                    icon: Icon(_showFilters
                        ? Icons.filter_list_off_rounded
                        : Icons.filter_list_rounded),
                    tooltip: _showFilters ? 'Hide filters' : 'Show filters',
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'Settings',
                  onPressed: _navigateToSettings,
                ),
              ]
            : null,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Index 0: Home tab
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Streak Chip ──
                if (streakCount > 0)
                  SliverToBoxAdapter(
                    child: _buildStreakChip(streakCount, theme, colorScheme),
                  ),

                // ── Balance Summary Cards ──
                SliverToBoxAdapter(
                  child: _buildBalanceCards(todaySpent, todayIncome,
                      monthBalance, colorScheme, theme),
                ),

                // ── Search Bar (if search mode) ──
                if (_showSearch)
                  SliverToBoxAdapter(
                    child: _buildSearchBar(theme, colorScheme),
                  ),

                // ── Filter Chips (if expanded) ──
                if (_showSearch && _showFilters)
                  SliverToBoxAdapter(
                    child: _buildFilterChips(theme, colorScheme),
                  ),

                // ── Active filter indicator ──
                if (hasActiveFilter)
                  SliverToBoxAdapter(
                    child: _buildActiveFilterBar(theme),
                  ),

                // ── Insights Cards ──
                if (!_showSearch)
                  SliverToBoxAdapter(
                    child: _buildInsightsSection(insights, theme, colorScheme),
                  ),

                // ── Weekly Mini Chart ──
                if (!_showSearch && hasWeeklyData)
                  SliverToBoxAdapter(
                    child: _buildWeeklyChart(weeklyData, theme),
                  ),

                // ── Recent / Filtered Header ──
                SliverToBoxAdapter(
                  child: _buildRecentHeader(theme, hasActiveFilter),
                ),

                // ── Transaction List or Empty State ──
                if (displayTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(
                      theme,
                      colorScheme,
                      hasActiveFilter
                          ? 'No transactions match your filters'
                          : 'No transactions yet',
                      hasActiveFilter
                          ? 'Try adjusting your search or filters'
                          : 'Tap + to add one!',
                    ),
                  )
                else
                  ...grouped.entries.expand((entry) => [
                        SliverToBoxAdapter(
                          child: _buildDateHeader(
                              _formatDateHeader(entry.key), theme),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildTransactionTile(
                              entry.value[index],
                              categoryMap,
                              theme,
                              colorScheme,
                            ),
                            childCount: entry.value.length,
                          ),
                        ),
                      ]),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
          // Index 1: Stats
          const StatsScreen(),
          // Index 2: Categories
          const CategoriesScreen(),
          // Index 3: Recurring
          const RecurringScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddTransaction,
              icon: const Icon(Icons.add_rounded, size: 28),
              label: const Text('Add'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 4,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_rounded),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_rounded),
            selectedIcon: Icon(Icons.repeat_rounded),
            label: 'Recurring',
          ),
        ],
      ),
    );
  }

  // ──────────────────────
  //  Streak Chip
  // ──────────────────────

  Widget _buildStreakChip(int count, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                '$count day streak',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────
  //  Search Bar
  // ──────────────────────

  Widget _buildSearchBar(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search by note, category, or amount...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  // ──────────────────────
  //  Filter Chips
  // ──────────────────────

  Widget _buildFilterChips(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Date filter chips
          FilterChip(
            label: const Text('This Week'),
            selected: _dateFilter == 'this_week',
            onSelected: (v) {
              setState(() {
                _dateFilter = v ? 'this_week' : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          FilterChip(
            label: const Text('This Month'),
            selected: _dateFilter == 'this_month',
            onSelected: (v) {
              setState(() {
                _dateFilter = v ? 'this_month' : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          FilterChip(
            label: const Text('Last Month'),
            selected: _dateFilter == 'last_month',
            onSelected: (v) {
              setState(() {
                _dateFilter = v ? 'last_month' : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          // Type filter chips
          FilterChip(
            label: const Text('Expense'),
            selected: _typeFilter == 'expense',
            selectedColor: Colors.redAccent.withValues(alpha: 0.2),
            onSelected: (v) {
              setState(() {
                _typeFilter = v ? 'expense' : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          FilterChip(
            label: const Text('Income'),
            selected: _typeFilter == 'income',
            selectedColor: Colors.green.withValues(alpha: 0.2),
            onSelected: (v) {
              setState(() {
                _typeFilter = v ? 'income' : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ──────────────────────
  //  Active Filter Bar
  // ──────────────────────

  Widget _buildActiveFilterBar(ThemeData theme) {
    final parts = <String>[];
    if (_dateFilter != null) {
      switch (_dateFilter) {
        case 'this_week':
          parts.add('This Week');
          break;
        case 'this_month':
          parts.add('This Month');
          break;
        case 'last_month':
          parts.add('Last Month');
          break;
      }
    }
    if (_typeFilter != null) {
      parts.add(_typeFilter == 'expense' ? 'Expenses' : 'Income');
    }
    if (_searchQuery.isNotEmpty) parts.add('"$_searchQuery"');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.filter_alt_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered: ${parts.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_rounded, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────
  //  Insights Section
  // ──────────────────────

  Widget _buildInsightsSection(
      List<String> insights, ThemeData theme, ColorScheme colorScheme) {
    if (insights.isEmpty) return const SizedBox.shrink();

    // Hide the "Start logging" placeholder insight
    final displayInsights = insights
        .where((s) =>
            s != 'Start logging transactions to see insights!' && s.isNotEmpty)
        .take(2)
        .toList();

    if (displayInsights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    size: 18, color: Colors.amber.shade700),
                const SizedBox(width: 6),
                Text(
                  'Weekly Insights',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...displayInsights.map((insight) => _buildInsightCard(
                insight,
                theme,
                displayInsights.indexOf(insight),
              )),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String insight, ThemeData theme, int index) {
    final bgColor = index == 0 ? Colors.amber : Colors.teal;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: bgColor.withValues(alpha: 0.3),
        ),
      ),
      color: bgColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_rounded,
              color: bgColor.shade700,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                insight,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────
  //  Balance Summary Cards
  // ──────────────────────

  Widget _buildBalanceCards(
    double spent,
    double income,
    double balance,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.trending_down_rounded,
              label: 'Today Spent',
              amount: spent,
              amountColor: Colors.redAccent,
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              iconColor: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: Icons.trending_up_rounded,
              label: 'Today Income',
              amount: income,
              amountColor: Colors.green,
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              iconColor: Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Month Balance',
              amount: balance,
              amountColor: balance >= 0 ? Colors.blueAccent : Colors.redAccent,
              backgroundColor:
                  (balance >= 0 ? Colors.blueAccent : Colors.redAccent)
                      .withValues(alpha: 0.1),
              iconColor: balance >= 0 ? Colors.blueAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────
  //  Weekly Mini Chart
  // ──────────────────────

  Widget _buildWeeklyChart(List<DailySpending> data, ThemeData theme) {
    final maxY =
        data.map((d) => d.amount).reduce((a, b) => a > b ? a : b) * 1.2;
    final effectiveMaxY = maxY > 0 ? maxY : 100.0;

    return GestureDetector(
      onTap: _navigateToStats,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This Week',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: effectiveMaxY,
                    barGroups: data.asMap().entries.map((entry) {
                      final i = entry.key;
                      final day = entry.value;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: day.amount,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.75),
                            width: 14,
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
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < data.length) {
                              final wd = data[index].date.weekday;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _dayLabels[wd - 1],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
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
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final day = data[group.x];
                          return BarTooltipItem(
                            '${_dayLabels[day.date.weekday - 1]}\n${_currencyFormat.format(day.amount)}',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────
  //  Recent Header
  // ──────────────────────

  Widget _buildRecentHeader(ThemeData theme, bool isFiltered) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isFiltered ? 'Filtered Results' : 'Recent Transactions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isFiltered)
            TextButton(
              onPressed: _navigateToStats,
              child: const Text('See All'),
            ),
        ],
      ),
    );
  }

  // ──────────────────────
  //  Date Group Header
  // ──────────────────────

  Widget _buildDateHeader(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ──────────────────────
  //  Transaction Tile
  // ──────────────────────

  Widget _buildTransactionTile(
    Transaction transaction,
    Map<String, Category> categoryMap,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final category = categoryMap[transaction.categoryId];
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome ? Colors.green : Colors.redAccent;
    final amountPrefix = isIncome ? '+' : '-';
    final timeString = DateFormat('h:mm a').format(transaction.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _confirmDelete(transaction),
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
              transaction.note != null && transaction.note!.isNotEmpty
                  ? transaction.note!
                  : timeString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '$amountPrefix${_currencyFormat.format(transaction.amount)}',
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
        ),
      ),
    );
  }

  // ──────────────────────
  //  Empty State
  // ──────────────────────

  Widget _buildEmptyState(
      ThemeData theme, ColorScheme colorScheme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 72,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────
//  Summary Card Widget
// ────────────────────────

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
