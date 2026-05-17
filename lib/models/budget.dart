import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 3)
class Budget extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String categoryId;

  @HiveField(2)
  final int month; // 1-12

  @HiveField(3)
  final int year;

  @HiveField(4)
  final double limit;

  @HiveField(5)
  final double spent;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.limit,
    this.spent = 0.0,
  });

  @override
  List<Object?> get props => [id];
}
