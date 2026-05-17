import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'recurring_rule.g.dart';

@HiveType(typeId: 2)
class RecurringRule extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String type; // 'income' or 'expense'

  @HiveField(3)
  final String categoryId;

  @HiveField(4)
  final String? note;

  @HiveField(5)
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'

  @HiveField(6)
  final DateTime nextDueDate;

  @HiveField(7)
  final bool isActive;

  @HiveField(8)
  final DateTime createdAt;

  const RecurringRule({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    this.note,
    required this.frequency,
    required this.nextDueDate,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
