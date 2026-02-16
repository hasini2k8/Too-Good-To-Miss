import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/review.dart';
import 'auth_service.dart';

class ReviewService {
  static const String _reviewsKey = 'user_reviews';
  
  // Singleton pattern
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  List<Review> _cachedReviews = [];
  bool _isInitialized = false;

  // Load reviews from both assets and local storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Initializing ReviewService...');
      
      // Load default reviews from assets
      final String jsonString = await rootBundle.loadString('assets/reviews.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> reviewsJson = jsonData['reviews'];
      
      print('📄 Loaded ${reviewsJson.length} reviews from assets');
      
      // Parse reviews with error handling
      _cachedReviews = [];
      for (var i = 0; i < reviewsJson.length; i++) {
        try {
          final review = Review.fromJson(reviewsJson[i]);
          _cachedReviews.add(review);
        } catch (e) {
          print('⚠️ Error parsing review at index $i: $e');
        }
      }
      
      print('✅ Successfully parsed ${_cachedReviews.length} default reviews');

      // Load user-added reviews from local storage
      final prefs = await SharedPreferences.getInstance();
      final String? userReviewsJson = prefs.getString(_reviewsKey);
      if (userReviewsJson != null) {
        try {
          final List<dynamic> userReviews = json.decode(userReviewsJson);
          print('📱 Found ${userReviews.length} user reviews in SharedPreferences');
          
          for (var userReview in userReviews) {
            try {
              _cachedReviews.add(Review.fromJson(userReview));
            } catch (e) {
              print('⚠️ Error parsing user review: $e');
            }
          }
        } catch (e) {
          print('⚠️ Error loading user reviews: $e');
        }
      }

      _isInitialized = true;
      print('✅ ReviewService initialized with ${_cachedReviews.length} total reviews');
    } catch (e) {
      print('❌ Error initializing reviews: $e');
      _cachedReviews = [];
      _isInitialized = true;
    }
  }

  // Get all reviews
  Future<List<Review>> getAllReviews() async {
    await initialize();
    return List.from(_cachedReviews);
  }

  // Get reviews for a specific startup
  Future<List<Review>> getReviewsForStartup(String startupId) async {
    await initialize();
    
    final reviews = _cachedReviews
        .where((review) => review.startupId == startupId)
        .toList();
    
    print('🔍 Found ${reviews.length} reviews for startup $startupId');
    return reviews;
  }

  // Add a new review and update user stats
  Future<bool> addReview(Review review) async {
    await initialize();

    try {
      print('➕ Adding new review for startup: ${review.startupId}');
      
      _cachedReviews.add(review);
      await _saveUserReviews();
      
      // Update user statistics
      await AuthService.incrementReviewsPosted();
      
      print('✅ Review added successfully and user stats updated');
      return true;
    } catch (e) {
      print('❌ Error adding review: $e');
      return false;
    }
  }

  // Calculate average rating for a startup
  Future<double> getAverageRating(String startupId) async {
    final reviews = await getReviewsForStartup(startupId);
    if (reviews.isEmpty) return 0.0;

    final totalRating = reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return totalRating / reviews.length;
  }

  // Get review count for a startup
  Future<int> getReviewCount(String startupId) async {
    final reviews = await getReviewsForStartup(startupId);
    return reviews.length;
  }

  // Get reviews by current user
  Future<List<Review>> getUserReviews() async {
    await initialize();
    
    final user = await AuthService.getCurrentUser();
    if (user == null) return [];
    
    final username = user['username'];
    return _cachedReviews
        .where((review) => review.username == username)
        .toList();
  }

  // Save user-added reviews to local storage
  Future<void> _saveUserReviews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Filter only user-added reviews (those not from assets)
      final userReviews = _cachedReviews
          .where((review) => review.id.startsWith('user_review_'))
          .toList();
      
      print('💾 Saving ${userReviews.length} user reviews to SharedPreferences');
      
      final reviewsJson = userReviews.map((review) => review.toJson()).toList();
      await prefs.setString(_reviewsKey, json.encode(reviewsJson));
      
      print('✅ User reviews saved successfully');
    } catch (e) {
      print('❌ Error saving reviews: $e');
    }
  }

  // Generate unique review ID with current username
  Future<String> generateReviewId() async {
    final user = await AuthService.getCurrentUser();
    final username = user?['username'] ?? 'user';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'user_review_${username}_$timestamp';
  }

  // Delete a review (only user's own reviews) and update stats
  Future<bool> deleteReview(String reviewId) async {
    await initialize();

    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return false;
      
      // Find the review
      final review = _cachedReviews.firstWhere(
        (r) => r.id == reviewId,
        orElse: () => throw Exception('Review not found'),
      );
      
      // Check if user owns this review
      if (review.username != user['username']) {
        print('❌ User cannot delete reviews they did not write');
        return false;
      }
      
      print('🗑️ Deleting review: $reviewId');
      _cachedReviews.removeWhere((review) => review.id == reviewId);
      await _saveUserReviews();
      
      // Decrement user stats
      final updatedUser = await AuthService.getCurrentUser();
      if (updatedUser != null) {
        updatedUser['reviewsPosted'] = ((updatedUser['reviewsPosted'] ?? 0) - 1).clamp(0, 999999);
        updatedUser['points'] = ((updatedUser['points'] ?? 0) - 10).clamp(0, 999999);
        await AuthService.updateUser(updatedUser);
      }
      
      print('✅ Review deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting review: $e');
      return false;
    }
  }

  // Get reviews sorted by date (newest first)
  Future<List<Review>> getReviewsSortedByDate(String startupId) async {
    final reviews = await getReviewsForStartup(startupId);
    reviews.sort((a, b) => b.date.compareTo(a.date));
    return reviews;
  }

  // Get reviews sorted by rating (highest first)
  Future<List<Review>> getReviewsSortedByRating(String startupId) async {
    final reviews = await getReviewsForStartup(startupId);
    reviews.sort((a, b) => b.rating.compareTo(a.rating));
    return reviews;
  }
}