import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction extends Equatable {
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
  final List<String> tags;

  @HiveField(6)
  final DateTime date;

  @HiveField(7)
  final String? receiptPath;

  @HiveField(8)
  final String? recurringId;

  @HiveField(9)
  final String currencyCode;

  @HiveField(10)
  final bool isRecurringInstance;

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    this.note,
    this.tags = const [],
    required this.date,
    this.receiptPath,
    this.recurringId,
    this.currencyCode = 'BDT',
    this.isRecurringInstance = false,
  });

  @override
  List<Object?> get props => [id];
}
