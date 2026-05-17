// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringRuleAdapter extends TypeAdapter<RecurringRule> {
  @override
  final int typeId = 2;

  @override
  RecurringRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringRule(
      id: fields[0] as String,
      amount: fields[1] as double,
      type: fields[2] as String,
      categoryId: fields[3] as String,
      note: fields[4] as String?,
      frequency: fields[5] as String,
      nextDueDate: fields[6] as DateTime,
      isActive: fields[7] as bool,
      createdAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringRule obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.nextDueDate)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
