import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String username;

  @HiveField(2)
  String email;

  @HiveField(3)
  String password;

  @HiveField(4)
  String userType;

  @HiveField(5)
  int points;

  @HiveField(6)
  int reviewsPosted;

  @HiveField(7)
  int placesVisited;

  @HiveField(8)
  int favorites;

  @HiveField(9)
  String memberSince;

  @HiveField(10)
  List<String> bookmarkedStartups;

  @HiveField(11)
  List<String> visitedStartups;

  @HiveField(12)
  List<String> achievements;

  @HiveField(13)
  List<String> visitedPlaces;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.userType,
    required this.points,
    required this.reviewsPosted,
    required this.placesVisited,
    required this.favorites,
    required this.memberSince,
    required this.bookmarkedStartups,
    required this.visitedStartups,
    required this.achievements,
    required this.visitedPlaces,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
  // Log the data to see what PocketBase is actually sending
  print("Parsing JSON: $json");

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<String> _parseList(dynamic value) {
    if (value is List) return List<String>.from(value);
    return [];
  }

  try {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      password: '', 
      // WATCH OUT: If dashboard says user_type, change this to json['user_type']
      userType: json['userType'] ?? json['user_type'] ?? 'customer',
      points: _parseInt(json['points']),
      reviewsPosted: _parseInt(json['reviewsPosted']),
      placesVisited: _parseInt(json['placesVisited']),
      favorites: _parseInt(json['favorites']),
      memberSince: json['created']?.toString() ?? json['memberSince']?.toString() ?? '',
      bookmarkedStartups: _parseList(json['bookmarkedStartups']),
      visitedStartups: _parseList(json['visitedStartups']),
      achievements: _parseList(json['achievements']),
      visitedPlaces: _parseList(json['visitedPlaces']),
    );
  } catch (e) {
    print("MODEL CRASH: One of your fields doesn't match! Error: $e");
    rethrow;
  }
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'userType': userType,
      'points': points,
      'reviewsPosted': reviewsPosted,
      'placesVisited': placesVisited,
      'favorites': favorites,
      'memberSince': memberSince,
      'bookmarkedStartups': bookmarkedStartups,
      'visitedStartups': visitedStartups,
      'achievements': achievements,
      'visitedPlaces': visitedPlaces,
    };
  }
}