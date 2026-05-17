import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streak_service.dart';

final streakProvider = FutureProvider<int>((ref) async {
  return StreakService.getCurrentStreak();
});
