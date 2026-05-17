import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/insights_service.dart';
import 'category_provider.dart';

final insightsProvider = Provider<List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final insightsService = InsightsService(storage);
  return insightsService.generateInsights();
});
