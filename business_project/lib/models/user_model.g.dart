// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 0;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      username: fields[1] as String,
      email: fields[2] as String,
      password: fields[3] as String,
      userType: fields[4] as String,
      points: fields[5] as int,
      reviewsPosted: fields[6] as int,
      placesVisited: fields[7] as int,
      favorites: fields[8] as int,
      memberSince: fields[9] as String,
      bookmarkedStartups: (fields[10] as List).cast<String>(),
      visitedStartups: (fields[11] as List).cast<String>(),
      achievements: (fields[12] as List).cast<String>(),
      visitedPlaces: (fields[13] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.password)
      ..writeByte(4)
      ..write(obj.userType)
      ..writeByte(5)
      ..write(obj.points)
      ..writeByte(6)
      ..write(obj.reviewsPosted)
      ..writeByte(7)
      ..write(obj.placesVisited)
      ..writeByte(8)
      ..write(obj.favorites)
      ..writeByte(9)
      ..write(obj.memberSince)
      ..writeByte(10)
      ..write(obj.bookmarkedStartups)
      ..writeByte(11)
      ..write(obj.visitedStartups)
      ..writeByte(12)
      ..write(obj.achievements)
      ..writeByte(13)
      ..write(obj.visitedPlaces);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}