// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 1;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      amount: fields[1] as double,
      type: fields[2] as String,
      categoryId: fields[3] as String,
      note: fields[4] as String?,
      tags: (fields[5] as List).cast<String>(),
      date: fields[6] as DateTime,
      receiptPath: fields[7] as String?,
      recurringId: fields[8] as String?,
      currencyCode: fields[9] as String,
      isRecurringInstance: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.receiptPath)
      ..writeByte(8)
      ..write(obj.recurringId)
      ..writeByte(9)
      ..write(obj.currencyCode)
      ..writeByte(10)
      ..write(obj.isRecurringInstance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
