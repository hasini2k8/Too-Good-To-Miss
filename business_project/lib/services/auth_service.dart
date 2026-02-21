import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

/// Pure-Dart observable — no Flutter dependency.
class _StatsNotifier {
  final List<void Function()> _listeners = [];
  void addListener(void Function() fn) {
    if (!_listeners.contains(fn)) _listeners.add(fn);
  }
  void removeListener(void Function() fn) => _listeners.remove(fn);
  void _notify() {
    for (final fn in List.of(_listeners)) fn();
  }
}

/// Safely converts a PocketBase field to List<dynamic>.
/// PocketBase sometimes returns "" or null for uninitialized JSON array fields.
List<dynamic> _toList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value;
  if (value is String && value.trim().isEmpty) return [];
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return [];
}


class AuthService {
  static const String _usersBoxName = 'users';
  static const String _currentUserKey = 'current_user';
  static const String _sessionBoxName = 'session';
  static const String _authTokenKey = 'auth_token';

  static final PocketBase pb = PocketBase('http://127.0.0.1:8090');
  static const String _usersCollection = 'startupUsers';
  static const String _baseUrl = 'http://127.0.0.1:8090';

  static final _StatsNotifier statsVersion = _StatsNotifier();
  static void _notifyStatsChanged() => statsVersion._notify();

  static Future<void> initialize() async {
    await Hive.openBox<UserModel>(_usersBoxName);
    await Hive.openBox(_sessionBoxName);
    await _restoreAuthFromToken();
  }

  static Future<void> _restoreAuthFromToken() async {
    try {
      final sessionBox = Hive.box(_sessionBoxName);
      final token = sessionBox.get(_authTokenKey);
      if (token != null) {
        pb.authStore.save(token, null);
        if (!pb.authStore.isValid) {
          await sessionBox.delete(_authTokenKey);
          await sessionBox.delete(_currentUserKey);
        }
      }
    } catch (e) {
      print('Error restoring auth: $e');
    }
  }

  static Future<void> _syncUsersFromPocketBase() async {
    try {
      final usersBox = Hive.box<UserModel>(_usersBoxName);
      final records = await pb.collection(_usersCollection).getFullList();
      await usersBox.clear();
      for (var record in records) {
        final user = UserModel.fromJson(record.toJson());
        await usersBox.put(user.username, user);
      }
    } catch (e) {
      print('Error syncing: $e');
      final usersBox = Hive.box<UserModel>(_usersBoxName);
      if (usersBox.isEmpty) await _loadUsersFromJson();
    }
  }

  static Future<void> _loadUsersFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/users.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final usersBox = Hive.box<UserModel>(_usersBoxName);
      for (var userData in (jsonData['users'] as List)) {
        final user = UserModel.fromJson(userData);
        await usersBox.put(user.username, user);
      }
    } catch (e) {
      print('Error loading users from JSON: $e');
    }
  }

  static Future<bool> registerUser({
    required String username,
    required String password,
    required String email,
    required String userType,
  }) async {
    try {
      final body = {
        'username': username,
        'email': email,
        'emailVisibility': true,
        'password': password,
        'passwordConfirm': password,
        'userType': userType,
        'points': 0,
        'reviewsPosted': 0,
        'placesVisited': 0,
        'favorites': 0,
        'memberSince': DateTime.now().toIso8601String(),
        'bookmarkedStartups': [],
        'visitedStartups': [],
        'achievements': [],
        'visitedPlaces': [],
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/api/collections/$_usersCollection/records'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newUser = UserModel.fromJson(json.decode(response.body));
        await Hive.box<UserModel>(_usersBoxName).put(username, newUser);
        return true;
      }
      print('Registration failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('Error registering: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> loginUser({
    required String usernameOrEmail,
    required String password,
    String? recaptchaToken,
  }) async {
    try {
      String emailToUse = usernameOrEmail;
      String? username;
      if (!usernameOrEmail.contains('@')) {
        final cached = Hive.box<UserModel>(_usersBoxName).get(usernameOrEmail);
        if (cached?.email != null) {
          emailToUse = cached!.email!;
          username = usernameOrEmail;
        }
      }
      final authData = await pb
          .collection(_usersCollection)
          .authWithPassword(emailToUse, password);
      if (authData.record != null) {
        final recordUsername =
            authData.record!.data['username'] ?? username ?? emailToUse;
        final sessionBox = Hive.box(_sessionBoxName);
        await sessionBox.put(_authTokenKey, pb.authStore.token);
        await sessionBox.put(_currentUserKey, recordUsername);
        final user = UserModel.fromJson(authData.record!.toJson());
        await Hive.box<UserModel>(_usersBoxName).put(recordUsername, user);
        return user.toJson();
      }
      return null;
    } catch (e) {
      print('Login failed: $e');
      return null;
    }
  }

  // ── Always fetches fresh from PocketBase; id is guaranteed present ────────
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final sessionBox = Hive.box(_sessionBoxName);
      final currentUsername = sessionBox.get(_currentUserKey);

      if (currentUsername == null || !pb.authStore.isValid) return null;

      // Always try PocketBase first so we get the real record id
      try {
        final record = await pb
            .collection(_usersCollection)
            .getFirstListItem('username="$currentUsername"');

        // Build a MUTABLE map — record.toJson() can return const/immutable maps
        // in some SDK versions. Spread into a new map to guarantee mutability.
        final mutableJson = <String, dynamic>{...record.toJson()};

        // record.id is always populated by the PocketBase SDK — use it explicitly
        mutableJson['id'] = record.id;

        print('getCurrentUser → id=${mutableJson['id']} username=${mutableJson['username']}');

        final user = UserModel.fromJson(mutableJson);
        await Hive.box<UserModel>(_usersBoxName).put(currentUsername, user);
        return mutableJson;
      } catch (e) {
        print('PocketBase fetch failed, using cache: $e');
        final cached = Hive.box<UserModel>(_usersBoxName).get(currentUsername);
        if (cached == null) return null;
        // Also make cache result mutable
        final cachedJson = <String, dynamic>{...cached.toJson()};
        print('cached id=${cachedJson["id"]}');
        return cachedJson;
      }
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  static Future<bool> updateUser(Map<String, dynamic> updatedUser) async {
    try {
      final userId = updatedUser['id'];
      final username = updatedUser['username'];

      if (userId == null || (userId as String).isEmpty) {
        print('✗ updateUser: id is null/empty — cannot update PocketBase');
        print('  Full user map keys: ${updatedUser.keys.toList()}');
        return false;
      }
      if (username == null) {
        print('✗ updateUser: username is null');
        return false;
      }

      final updateBody = {
        'points': updatedUser['points'],
        'reviewsPosted': updatedUser['reviewsPosted'],
        'placesVisited': updatedUser['placesVisited'],
        'favorites': updatedUser['favorites'],
        'bookmarkedStartups': _toList(updatedUser['bookmarkedStartups']),
        'visitedStartups': _toList(updatedUser['visitedStartups']),
        'achievements': _toList(updatedUser['achievements']),
        'visitedPlaces': _toList(updatedUser['visitedPlaces']),
      };

      print('updateUser → PocketBase id=$userId points=${updatedUser['points']} placesVisited=${updatedUser['placesVisited']}');
      await pb.collection(_usersCollection).update(userId, body: updateBody);
      print('✓ PocketBase update OK');

      final user = UserModel.fromJson(updatedUser);
      await Hive.box<UserModel>(_usersBoxName).put(username, user);

      _notifyStatsChanged();
      return true;
    } catch (e) {
      print('✗ updateUser error: $e');
      return false;
    }
  }

  static Future<bool> incrementFavorites(String startupId) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      List<dynamic> bookmarked = _toList(user['bookmarkedStartups']);
      if (bookmarked.contains(startupId)) return true;
      bookmarked.add(startupId);
      user['bookmarkedStartups'] = bookmarked;
      user['favorites'] = (user['favorites'] ?? 0) + 1;
      user['points'] = (user['points'] ?? 0) + 5;
      return await updateUser(user);
    } catch (e) {
      print('Error incrementFavorites: $e');
      return false;
    }
  }

  static Future<bool> decrementFavorites(String startupId) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      List<dynamic> bookmarked = _toList(user['bookmarkedStartups']);
      if (!bookmarked.contains(startupId)) return true;
      bookmarked.remove(startupId);
      user['bookmarkedStartups'] = bookmarked;
      user['favorites'] = ((user['favorites'] ?? 0) - 1).clamp(0, 999999);
      user['points'] = ((user['points'] ?? 0) - 5).clamp(0, 999999);
      return await updateUser(user);
    } catch (e) {
      print('Error decrementFavorites: $e');
      return false;
    }
  }

  static Future<bool> isStartupBookmarked(String startupId) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      return _toList(user['bookmarkedStartups']).contains(startupId);
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getBookmarkedStartups() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return [];
      return _toList(user['bookmarkedStartups']).cast<String>();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> incrementReviewsPosted() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      user['reviewsPosted'] = (user['reviewsPosted'] ?? 0) + 1;
      user['points'] = (user['points'] ?? 0) + 10;
      return await updateUser(user);
    } catch (e) {
      print('Error incrementReviews: $e');
      return false;
    }
  }

  // ── Record place visit ────────────────────────────────────────────────────
static Future<int> recordPlaceVisit(String startupId) async {
  try {
    final user = await getCurrentUser();
    if (user == null) {
      print('recordPlaceVisit: no logged-in user');
      return -1;
    }

    print('recordPlaceVisit: user id=${user["id"]} username=${user["username"]} startupId=$startupId');

    final mutableUser = <String, dynamic>{...user};

    // Always increase visit count
    final currentCount = (mutableUser['placesVisited'] as int?) ?? 0;
    mutableUser['placesVisited'] = currentCount + 1;

    // Always give points
    final currentPoints = (mutableUser['points'] as int?) ?? 0;
    mutableUser['points'] = currentPoints + 2;

    print('recordPlaceVisit: saving placesVisited=${mutableUser["placesVisited"]} points=${mutableUser["points"]}');

    final success = await updateUser(mutableUser);
    if (success) {
      print('✓ recordPlaceVisit saved to PocketBase. placesVisited=${mutableUser["placesVisited"]}');
      return mutableUser['placesVisited'];
    }

    print('✗ recordPlaceVisit: updateUser returned false');
    return -1;

  } catch (e) {
    print('✗ recordPlaceVisit error: $e');
    return -1;
  }
}


  static Future<bool> hasVisitedPlace(String startupId) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      return _toList(user['visitedPlaces']).contains(startupId);
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, int>> getUserStats() async {
    try {
      final user = await getCurrentUser();
      if (user == null) {
        return {'points': 0, 'reviewsPosted': 0, 'placesVisited': 0, 'favorites': 0};
      }
      return {
        'points': user['points'] ?? 0,
        'reviewsPosted': user['reviewsPosted'] ?? 0,
        'placesVisited': user['placesVisited'] ?? 0,
        'favorites': user['favorites'] ?? 0,
      };
    } catch (e) {
      return {'points': 0, 'reviewsPosted': 0, 'placesVisited': 0, 'favorites': 0};
    }
  }

  static Future<void> logout() async {
    try {
      pb.authStore.clear();
      final sessionBox = Hive.box(_sessionBoxName);
      await sessionBox.delete(_currentUserKey);
      await sessionBox.delete(_authTokenKey);
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  static Future<bool> isLoggedIn() async =>
      pb.authStore.isValid && await getCurrentUser() != null;

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final records = await pb.collection(_usersCollection).getFullList();
      return records.map((r) => r.toJson()).toList();
    } catch (e) {
      try {
        return Hive.box<UserModel>(_usersBoxName)
            .values
            .map((u) => u.toJson())
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  static Future<void> syncWithPocketBase() async => _syncUsersFromPocketBase();
}