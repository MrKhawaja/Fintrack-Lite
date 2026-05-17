import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 0)
class Category extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String icon; // emoji string
  
  @HiveField(3)
  final int color; // Color.value
  
  @HiveField(4)
  final double? monthlyBudget;
  
  @HiveField(5)
  final String type; // 'income' or 'expense'
  
  @HiveField(6)
  final bool isDefault;
  
  @HiveField(7)
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.monthlyBudget,
    required this.type,
    this.isDefault = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}