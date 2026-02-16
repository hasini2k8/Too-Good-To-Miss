import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class BookmarkService {
  static const String _bookmarksKey = 'bookmarked_startups';
  
  // Singleton pattern
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  Set<String> _bookmarkedIds = {};
  bool _isInitialized = false;

  // Initialize and load bookmarks
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // First, try to load from AuthService (PocketBase) if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        final bookmarksFromAuth = await AuthService.getBookmarkedStartups();
        _bookmarkedIds = bookmarksFromAuth.toSet();
        print('✅ BookmarkService initialized from PocketBase with ${_bookmarkedIds.length} bookmarks');
      } else {
        // Fallback to SharedPreferences for non-logged-in users
        final prefs = await SharedPreferences.getInstance();
        final String? bookmarksJson = prefs.getString(_bookmarksKey);
        
        if (bookmarksJson != null) {
          final List<dynamic> bookmarksList = json.decode(bookmarksJson);
          _bookmarkedIds = bookmarksList.cast<String>().toSet();
        }
        print('✅ BookmarkService initialized from SharedPreferences with ${_bookmarkedIds.length} bookmarks');
      }
      
      _isInitialized = true;
    } catch (e) {
      print('Error loading bookmarks: $e');
      _bookmarkedIds = {};
      _isInitialized = true;
    }
  }

  // Sync local bookmarks with PocketBase when user logs in
  Future<void> syncWithAuth() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        final bookmarksFromAuth = await AuthService.getBookmarkedStartups();
        _bookmarkedIds = bookmarksFromAuth.toSet();
        await _saveBookmarks();
        print('🔄 Synced bookmarks with PocketBase: ${_bookmarkedIds.length} bookmarks');
      }
    } catch (e) {
      print('Error syncing bookmarks with auth: $e');
    }
  }

  // Check if a startup is bookmarked
  Future<bool> isBookmarked(String startupId) async {
    await initialize();
    return _bookmarkedIds.contains(startupId);
  }

  // Toggle bookmark status and update user stats
  Future<bool> toggleBookmark(String startupId) async {
    await initialize();

    try {
      bool wasBookmarked = _bookmarkedIds.contains(startupId);
      
      if (wasBookmarked) {
        _bookmarkedIds.remove(startupId);
        await AuthService.decrementFavorites(startupId); // Pass startup ID
        print('📌 Removed bookmark for $startupId');
      } else {
        _bookmarkedIds.add(startupId);
        await AuthService.incrementFavorites(startupId); // Pass startup ID
        print('📌 Added bookmark for $startupId');
      }
      
      await _saveBookmarks();
      return _bookmarkedIds.contains(startupId);
    } catch (e) {
      print('Error toggling bookmark: $e');
      return false;
    }
  }

  // Add bookmark and update user stats
  Future<bool> addBookmark(String startupId) async {
    await initialize();

    try {
      if (!_bookmarkedIds.contains(startupId)) {
        _bookmarkedIds.add(startupId);
        await AuthService.incrementFavorites(startupId); // Pass startup ID
        await _saveBookmarks();
        print('📌 Added bookmark for $startupId');
      }
      return true;
    } catch (e) {
      print('Error adding bookmark: $e');
      return false;
    }
  }

  // Remove bookmark and update user stats
  Future<bool> removeBookmark(String startupId) async {
    await initialize();

    try {
      if (_bookmarkedIds.contains(startupId)) {
        _bookmarkedIds.remove(startupId);
        await AuthService.decrementFavorites(startupId); // Pass startup ID
        await _saveBookmarks();
        print('📌 Removed bookmark for $startupId');
      }
      return true;
    } catch (e) {
      print('Error removing bookmark: $e');
      return false;
    }
  }

  // Get all bookmarked startup IDs
  Future<List<String>> getBookmarkedIds() async {
    await initialize();
    return _bookmarkedIds.toList();
  }

  // Get bookmark count
  Future<int> getBookmarkCount() async {
    await initialize();
    return _bookmarkedIds.length;
  }

  // Clear all bookmarks
  Future<bool> clearAllBookmarks() async {
    await initialize();

    try {
      // Store IDs before clearing
      List<String> idsToRemove = _bookmarkedIds.toList();
      
      // Clear local set
      _bookmarkedIds.clear();
      await _saveBookmarks();
      
      // Update user stats - decrement for all removed bookmarks
      for (String startupId in idsToRemove) {
        await AuthService.decrementFavorites(startupId); // Pass each startup ID
      }
      
      print('🗑️ Cleared ${idsToRemove.length} bookmarks');
      return true;
    } catch (e) {
      print('Error clearing bookmarks: $e');
      return false;
    }
  }

  // Save bookmarks to local storage
  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksList = _bookmarkedIds.toList();
      await prefs.setString(_bookmarksKey, json.encode(bookmarksList));
      print('💾 Saved ${bookmarksList.length} bookmarks to local storage');
    } catch (e) {
      print('Error saving bookmarks: $e');
    }
  }

  // Export bookmarks as JSON string (for backup)
  Future<String> exportBookmarks() async {
    await initialize();
    return json.encode(_bookmarkedIds.toList());
  }

  // Import bookmarks from JSON string (for restore)
  Future<bool> importBookmarks(String bookmarksJson) async {
    try {
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      final Set<String> newBookmarks = bookmarksList.cast<String>().toSet();
      
      // Get current bookmarks to compare
      await initialize();
      final Set<String> addedBookmarks = newBookmarks.difference(_bookmarkedIds);
      final Set<String> removedBookmarks = _bookmarkedIds.difference(newBookmarks);
      
      // Update local set
      _bookmarkedIds = newBookmarks;
      await _saveBookmarks();
      
      // Update AuthService for each change
      for (String startupId in addedBookmarks) {
        await AuthService.incrementFavorites(startupId);
      }
      for (String startupId in removedBookmarks) {
        await AuthService.decrementFavorites(startupId);
      }
      
      print('📥 Imported ${newBookmarks.length} bookmarks (+${addedBookmarks.length}, -${removedBookmarks.length})');
      return true;
    } catch (e) {
      print('Error importing bookmarks: $e');
      return false;
    }
  }

  // Refresh bookmarks from PocketBase (useful after login)
  Future<void> refreshFromPocketBase() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        final bookmarksFromAuth = await AuthService.getBookmarkedStartups();
        _bookmarkedIds = bookmarksFromAuth.toSet();
        await _saveBookmarks();
        print('🔄 Refreshed ${_bookmarkedIds.length} bookmarks from PocketBase');
      }
    } catch (e) {
      print('Error refreshing bookmarks from PocketBase: $e');
    }
  }

  // Get bookmarks that are not synced with PocketBase
  Future<List<String>> getUnsyncedBookmarks() async {
    try {
      await initialize();
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) return [];

      final bookmarksFromAuth = await AuthService.getBookmarkedStartups();
      final authSet = bookmarksFromAuth.toSet();
      
      // Find bookmarks in local but not in PocketBase
      final unsynced = _bookmarkedIds.difference(authSet).toList();
      print('📊 Found ${unsynced.length} unsynced bookmarks');
      return unsynced;
    } catch (e) {
      print('Error checking unsynced bookmarks: $e');
      return [];
    }
  }
}