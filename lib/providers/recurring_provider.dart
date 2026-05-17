import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recurring_rule.dart';
import 'category_provider.dart';

// All recurring rules
final allRecurringRulesProvider = Provider<List<RecurringRule>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getAllRecurringRules();
});

// Active recurring rules only
final activeRecurringRulesProvider = Provider<List<RecurringRule>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getActiveRecurringRules();
});
