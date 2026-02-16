import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthService {
  static const String _usersBoxName = 'users';
  static const String _currentUserKey = 'current_user';
  static const String _sessionBoxName = 'session';
  static const String _authTokenKey = 'auth_token';
  
  // PocketBase instance - replace with your PocketBase URL
  static final PocketBase pb = PocketBase('http://127.0.0.1:8090');
  static const String _usersCollection = 'startupUsers';
  static const String _baseUrl = 'http://127.0.0.1:8090';

  // Initialize Hive and sync with PocketBase
  static Future<void> initialize() async {
    // Open boxes
    await Hive.openBox<UserModel>(_usersBoxName);
    await Hive.openBox(_sessionBoxName);

    // Try to restore auth from saved token
    await _restoreAuthFromToken();
  }

  // Restore authentication from saved token
  static Future<void> _restoreAuthFromToken() async {
    try {
      final sessionBox = Hive.box(_sessionBoxName);
      final token = sessionBox.get(_authTokenKey);
      
      if (token != null) {
        pb.authStore.save(token, null);
        // Verify token is still valid
        if (pb.authStore.isValid) {
          // Token is valid, user is still logged in
          print('Auth restored from token');
        } else {
          // Token expired, clear it
          await sessionBox.delete(_authTokenKey);
          await sessionBox.delete(_currentUserKey);
        }
      }
    } catch (e) {
      print('Error restoring auth: $e');
    }
  }

  // Sync users from PocketBase to local Hive cache
  static Future<void> _syncUsersFromPocketBase() async {
    try {
      final usersBox = Hive.box<UserModel>(_usersBoxName);
      
      print('Attempting to fetch users from PocketBase...');
      
      // Fetch all users from PocketBase
      final records = await pb.collection(_usersCollection).getFullList();
      
      print('Fetched ${records.length} records from PocketBase');
      
      // Clear existing cache and reload
      await usersBox.clear();
      
      for (var record in records) {
        print('Processing record: ${record.toJson()}');
        final user = UserModel.fromJson(record.toJson());
        await usersBox.put(user.username, user);
        print('Cached user: ${user.username}');
      }
      
      print('Synced ${records.length} users from PocketBase');
      print('Hive box now contains ${usersBox.length} users');
    } catch (e) {
      print('Error syncing users from PocketBase: $e');
      // If sync fails, try to load from JSON as fallback
      final usersBox = Hive.box<UserModel>(_usersBoxName);
      if (usersBox.isEmpty) {
        await _loadUsersFromJson();
      }
    }
  }

  // Load users from JSON file (fallback only)
  static Future<void> _loadUsersFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/users.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> usersList = jsonData['users'];

      final usersBox = Hive.box<UserModel>(_usersBoxName);

      for (var userData in usersList) {
        final user = UserModel.fromJson(userData);
        await usersBox.put(user.username, user);
      }
      print('Loaded users from JSON fallback');
    } catch (e) {
      print('Error loading users from JSON: $e');
    }
  }

  // Register new user - USING DIRECT HTTP FOR AUTH COLLECTIONS
  static Future<bool> registerUser({
    required String username,
    required String password,
    required String email,
    required String userType,
  }) async {
    try {
      print('=== REGISTRATION ATTEMPT ===');
      print('Username: $username');
      print('Email: $email');
      print('User Type: $userType');
      
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

      print('Sending registration request...');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/collections/$_usersCollection/records'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✓ Registration successful!');
        
        final responseData = json.decode(response.body);
        final newUser = UserModel.fromJson(responseData);
        final usersBox = Hive.box<UserModel>(_usersBoxName);
        await usersBox.put(username, newUser);
        
        return true;
      } else {
        print('✗ Registration failed with status ${response.statusCode}');
        final errorData = json.decode(response.body);
        print('Error details: $errorData');
        return false;
      }
    } catch (e) {
      print('✗ Error registering user: $e');
      return false;
    }
  }

  // Login user
  static Future<Map<String, dynamic>?> loginUser({
    required String usernameOrEmail,
    required String password,
    String? recaptchaToken, // reCAPTCHA token for verification
  }) async {
    try {
      print('=== LOGIN ATTEMPT ===');
      print('Input: $usernameOrEmail');
      
      // TODO: If you want backend verification, send recaptchaToken to your backend here
      // For now, we'll just log it
      if (recaptchaToken != null) {
        print('reCAPTCHA token received: ${recaptchaToken.substring(0, 20)}...');
        // In production, verify this token on your backend before proceeding
      }
      
      String emailToUse = usernameOrEmail;
      String? username;
      
      // If input doesn't contain @, it's a username - we need to get the email
      if (!usernameOrEmail.contains('@')) {
        print('Input is username, looking up email in cache...');
        final usersBox = Hive.box<UserModel>(_usersBoxName);
        final cachedUser = usersBox.get(usernameOrEmail);
        
        if (cachedUser != null && cachedUser.email != null) {
          emailToUse = cachedUser.email!;
          username = usernameOrEmail;
          print('Found cached email: $emailToUse');
        } else {
          print('Username not in cache, treating as email');
          emailToUse = usernameOrEmail;
        }
      } else {
        print('Input is email, using directly');
        emailToUse = usernameOrEmail;
      }
      
      print('Authenticating with email: $emailToUse');
      
      // Authenticate with PocketBase using EMAIL
      final authData = await pb.collection(_usersCollection).authWithPassword(
        emailToUse,
        password,
      );
      
      if (authData.record != null) {
        print('✓ Authentication SUCCESS');
        
        // Get username from the record
        final recordUsername = authData.record!.data['username'] ?? username ?? emailToUse;
        
        // Save auth token for persistence
        final sessionBox = Hive.box(_sessionBoxName);
        await sessionBox.put(_authTokenKey, pb.authStore.token);
        await sessionBox.put(_currentUserKey, recordUsername);
        
        // Cache user locally
        final user = UserModel.fromJson(authData.record!.toJson());
        final usersBox = Hive.box<UserModel>(_usersBoxName);
        await usersBox.put(recordUsername, user);
        
        print('User logged in: $recordUsername');
        return user.toJson();
      }
      
      return null;
    } catch (e) {
      print('✗ Login failed: $e');
      return null;
    }
  }

  // Get current user
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final sessionBox = Hive.box(_sessionBoxName);
      final currentUsername = sessionBox.get(_currentUserKey);
      
      if (currentUsername != null && pb.authStore.isValid) {
        // Try to get fresh data from PocketBase first
        try {
          final record = await pb.collection(_usersCollection).getFirstListItem(
            'username="${currentUsername}"',
          );
          
          // Update local cache
          final user = UserModel.fromJson(record.toJson());
          final usersBox = Hive.box<UserModel>(_usersBoxName);
          await usersBox.put(currentUsername, user);
          
          return user.toJson();
        } catch (e) {
          // If PocketBase fails, fallback to cached version
          print('Using cached user data: $e');
          final usersBox = Hive.box<UserModel>(_usersBoxName);
          final user = usersBox.get(currentUsername);
          return user?.toJson();
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Update user data - IMPROVED WITH BETTER LOGGING
  static Future<bool> updateUser(Map<String, dynamic> updatedUser) async {
    try {
      final userId = updatedUser['id'];
      final username = updatedUser['username'];
      
      if (userId == null || username == null) {
        print('✗ Cannot update user: Missing id or username');
        return false;
      }

      print('=== UPDATING USER IN POCKETBASE ===');
      print('User ID: $userId');
      print('Username: $username');
      print('Points: ${updatedUser['points']}');
      print('Reviews Posted: ${updatedUser['reviewsPosted']}');
      print('Places Visited: ${updatedUser['placesVisited']}');
      print('Favorites: ${updatedUser['favorites']}');

      // Update in PocketBase
      final updateBody = {
        'points': updatedUser['points'],
        'reviewsPosted': updatedUser['reviewsPosted'],
        'placesVisited': updatedUser['placesVisited'],
        'favorites': updatedUser['favorites'],
        'bookmarkedStartups': updatedUser['bookmarkedStartups'] ?? [],
        'visitedStartups': updatedUser['visitedStartups'] ?? [],
        'achievements': updatedUser['achievements'] ?? [],
        'visitedPlaces': updatedUser['visitedPlaces'] ?? [],
      };

      print('Update body: $updateBody');

      await pb.collection(_usersCollection).update(
        userId,
        body: updateBody,
      );
      
      print('✓ PocketBase update successful!');
      
      // Update local cache
      final usersBox = Hive.box<UserModel>(_usersBoxName);
      final user = UserModel.fromJson(updatedUser);
      await usersBox.put(username, user);
      
      print('✓ Local cache updated!');
      
      return true;
    } catch (e) {
      print('✗ Error updating user: $e');
      return false;
    }
  }

  // Increment favorites count and add startup to bookmarked list
  static Future<bool> incrementFavorites(String startupId) async {
    try {
      print('=== INCREMENT FAVORITES ===');
      print('Startup ID: $startupId');
      
      final user = await getCurrentUser();
      if (user == null) {
        print('✗ No current user');
        return false;
      }

      // Get current bookmarked startups list
      List<dynamic> bookmarkedStartups = user['bookmarkedStartups'] ?? [];
      
      // Check if startup is already bookmarked
      if (bookmarkedStartups.contains(startupId)) {
        print('⚠ Startup already bookmarked');
        return true;
      }

      final oldFavorites = user['favorites'] ?? 0;
      final oldPoints = user['points'] ?? 0;

      // Add startup to bookmarked list
      bookmarkedStartups.add(startupId);
      user['bookmarkedStartups'] = bookmarkedStartups;
      user['favorites'] = oldFavorites + 1;
      user['points'] = oldPoints + 5;
      
      print('Added to bookmarked startups. Total: ${bookmarkedStartups.length}');
      print('Favorites: $oldFavorites → ${user['favorites']}');
      print('Points: $oldPoints → ${user['points']}');
      
      final result = await updateUser(user);
      if (result) {
        print('✓ Favorites incremented and startup bookmarked successfully!');
      }
      return result;
    } catch (e) {
      print('✗ Error incrementing favorites: $e');
      return false;
    }
  }

  // Decrement favorites count and remove startup from bookmarked list
  static Future<bool> decrementFavorites(String startupId) async {
    try {
      print('=== DECREMENT FAVORITES ===');
      print('Startup ID: $startupId');
      
      final user = await getCurrentUser();
      if (user == null) {
        print('✗ No current user');
        return false;
      }

      // Get current bookmarked startups list
      List<dynamic> bookmarkedStartups = user['bookmarkedStartups'] ?? [];
      
      // Check if startup is in bookmarked list
      if (!bookmarkedStartups.contains(startupId)) {
        print('⚠ Startup not in bookmarked list');
        return true;
      }

      final oldFavorites = user['favorites'] ?? 0;
      final oldPoints = user['points'] ?? 0;

      // Remove startup from bookmarked list
      bookmarkedStartups.remove(startupId);
      user['bookmarkedStartups'] = bookmarkedStartups;
      user['favorites'] = (oldFavorites - 1).clamp(0, 999999);
      user['points'] = (oldPoints - 5).clamp(0, 999999);
      
      print('Removed from bookmarked startups. Total: ${bookmarkedStartups.length}');
      print('Favorites: $oldFavorites → ${user['favorites']}');
      print('Points: $oldPoints → ${user['points']}');
      
      final result = await updateUser(user);
      if (result) {
        print('✓ Favorites decremented and startup unbookmarked successfully!');
      }
      return result;
    } catch (e) {
      print('✗ Error decrementing favorites: $e');
      return false;
    }
  }

  // Check if startup is bookmarked
  static Future<bool> isStartupBookmarked(String startupId) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;

      List<dynamic> bookmarkedStartups = user['bookmarkedStartups'] ?? [];
      return bookmarkedStartups.contains(startupId);
    } catch (e) {
      print('Error checking if startup is bookmarked: $e');
      return false;
    }
  }

  // Get all bookmarked startup IDs
  static Future<List<String>> getBookmarkedStartups() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return [];

      List<dynamic> bookmarkedStartups = user['bookmarkedStartups'] ?? [];
      return bookmarkedStartups.cast<String>();
    } catch (e) {
      print('Error getting bookmarked startups: $e');
      return [];
    }
  }

  // Increment reviews posted count
  static Future<bool> incrementReviewsPosted() async {
    try {
      print('=== INCREMENT REVIEWS POSTED ===');
      final user = await getCurrentUser();
      if (user == null) {
        print('✗ No current user');
        return false;
      }

      final oldReviews = user['reviewsPosted'] ?? 0;
      final oldPoints = user['points'] ?? 0;

      user['reviewsPosted'] = oldReviews + 1;
      user['points'] = oldPoints + 10;
      
      print('Reviews Posted: $oldReviews → ${user['reviewsPosted']}');
      print('Points: $oldPoints → ${user['points']}');
      
      final result = await updateUser(user);
      if (result) {
        print('✓ Reviews incremented successfully!');
      }
      return result;
    } catch (e) {
      print('✗ Error incrementing reviews: $e');
      return false;
    }
  }

  // Record place visit
  static Future<bool> recordPlaceVisit(String startupId) async {
    try {
      print('=== RECORD PLACE VISIT ===');
      print('Startup ID: $startupId');
      
      final user = await getCurrentUser();
      if (user == null) {
        print('✗ No current user');
        return false;
      }

      List<dynamic> visitedPlaces = user['visitedPlaces'] ?? [];
      
      if (!visitedPlaces.contains(startupId)) {
        visitedPlaces.add(startupId);
        user['visitedPlaces'] = visitedPlaces;
        user['placesVisited'] = visitedPlaces.length;
        user['points'] = (user['points'] ?? 0) + 2;
        
        print('Added to visited places. Total: ${visitedPlaces.length}');
        print('Points awarded: +2 (Total: ${user['points']})');
        
        final result = await updateUser(user);
        if (result) {
          print('✓ Place visit recorded successfully!');
        }
        return result;
      } else {
        print('Place already visited');
        return true;
      }
    } catch (e) {
      print('✗ Error recording place visit: $e');
      return false;
    }
  }

  // Check if place was visited
  static Future<bool> hasVisitedPlace(String startupId) async {
    try {
      final user = await getCurrentUser();
      if (user == null) return false;

      List<dynamic> visitedPlaces = user['visitedPlaces'] ?? [];
      return visitedPlaces.contains(startupId);
    } catch (e) {
      print('Error checking place visit: $e');
      return false;
    }
  }

  // Get user statistics
  static Future<Map<String, int>> getUserStats() async {
    try {
      final user = await getCurrentUser();
      if (user == null) {
        return {
          'points': 0,
          'reviewsPosted': 0,
          'placesVisited': 0,
          'favorites': 0,
        };
      }

      return {
        'points': user['points'] ?? 0,
        'reviewsPosted': user['reviewsPosted'] ?? 0,
        'placesVisited': user['placesVisited'] ?? 0,
        'favorites': user['favorites'] ?? 0,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {
        'points': 0,
        'reviewsPosted': 0,
        'placesVisited': 0,
        'favorites': 0,
      };
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      // Clear PocketBase auth
      pb.authStore.clear();
      
      // Clear session
      final sessionBox = Hive.box(_sessionBoxName);
      await sessionBox.delete(_currentUserKey);
      await sessionBox.delete(_authTokenKey);
      
      print('✓ User logged out successfully');
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return pb.authStore.isValid && await getCurrentUser() != null;
  }

  // Get all users (for admin purposes)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final records = await pb.collection(_usersCollection).getFullList();
      return records.map((record) => record.toJson()).toList();
    } catch (e) {
      print('Error getting all users from PocketBase: $e');
      // Fallback to cached users
      try {
        final usersBox = Hive.box<UserModel>(_usersBoxName);
        return usersBox.values.map((user) => user.toJson()).toList();
      } catch (e) {
        print('Error getting cached users: $e');
        return [];
      }
    }
  }

  // Manual sync method (call when needed)
  static Future<void> syncWithPocketBase() async {
    await _syncUsersFromPocketBase();
  }
}