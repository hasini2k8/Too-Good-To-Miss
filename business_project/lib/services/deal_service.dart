import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/deal.dart';

class DealService {
  // Singleton pattern
  static final DealService _instance = DealService._internal();
  factory DealService() => _instance;
  DealService._internal();

  List<Deal> _allDeals = [];
  bool _isInitialized = false;

  // Initialize and load deals from JSON
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🎁 Initializing DealService...');
      
      final String jsonString = await rootBundle.loadString('assets/deals.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> dealsJson = jsonData['deals'];
      
      print('📄 Loaded ${dealsJson.length} deals from assets');
      
      // Parse deals with error handling
      _allDeals = [];
      for (var i = 0; i < dealsJson.length; i++) {
        try {
          final deal = Deal.fromJson(dealsJson[i]);
          _allDeals.add(deal);
        } catch (e) {
          print('⚠️ Error parsing deal at index $i: $e');
          print('Deal data: ${dealsJson[i]}');
        }
      }
      
      print('✅ Successfully parsed ${_allDeals.length} deals');
      
      // Debug: Print deal distribution
      final dealsByStartup = <String, int>{};
      for (var deal in _allDeals) {
        dealsByStartup[deal.startupId] = (dealsByStartup[deal.startupId] ?? 0) + 1;
      }
      
      print('📊 Deal distribution:');
      dealsByStartup.forEach((startupId, count) {
        print('  $startupId: $count deals');
      });
      
      _isInitialized = true;
      print('✅ DealService initialized successfully');
    } catch (e) {
      print('❌ Error loading deals: $e');
      _allDeals = [];
      _isInitialized = true;
    }
  }

  // Get all deals
  List<Deal> getAllDeals() {
    return List.from(_allDeals);
  }

  // Get deals for a specific startup
  List<Deal> getDealsForStartup(String startupId) {
    print('🔍 Searching deals for startupId: $startupId');
    final deals = _allDeals.where((deal) => deal.startupId == startupId).toList();
    print('✅ Found ${deals.length} deals for $startupId');
    return deals;
  }

  // Get only valid deals for a startup
  List<Deal> getValidDealsForStartup(String startupId) {
    return _allDeals
        .where((deal) => deal.startupId == startupId && deal.isValid())
        .toList();
  }

  // Get all valid deals
  List<Deal> getAllValidDeals() {
    return _allDeals.where((deal) => deal.isValid()).toList();
  }

  // Get deals expiring soon (within 7 days)
  List<Deal> getExpiringDeals({int daysThreshold = 7}) {
    return _allDeals
        .where((deal) => deal.isValid() && deal.getDaysRemaining() <= daysThreshold)
        .toList();
  }

  // Get best deals (highest discount percentage)
  List<Deal> getBestDeals({int limit = 10}) {
    final validDeals = getAllValidDeals();
    validDeals.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    return validDeals.take(limit).toList();
  }

  // Search deals by keyword
  List<Deal> searchDeals(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return _allDeals.where((deal) {
      return deal.title.toLowerCase().contains(lowerKeyword) ||
             deal.description.toLowerCase().contains(lowerKeyword) ||
             deal.startupName.toLowerCase().contains(lowerKeyword);
    }).toList();
  }

  // Get deal count for a startup
  int getDealCount(String startupId) {
    return _allDeals.where((deal) => deal.startupId == startupId).length;
  }

  // Get valid deal count for a startup
  int getValidDealCount(String startupId) {
    return _allDeals
        .where((deal) => deal.startupId == startupId && deal.isValid())
        .length;
  }
}