import 'deal.dart';
import 'dart:math';

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final int points;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.points,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      category: json['category'],
      points: json['points'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'points': points,
    };
  }
}

class Startup {
  final String id;
  final String name;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String category;
  final double rating;
  final int reviewCount;
  final String icon;
  final List<Deal> deals;
  final List<MenuItem> menu;

  Startup({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.icon,
    required this.deals,
    this.menu = const [],
  });

  factory Startup.fromJson(Map<String, dynamic> json) {
    return Startup(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      location: json['location'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      category: json['category'],
      rating: json['rating'].toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      icon: json['icon'],
      deals: json['deals'] != null
          ? (json['deals'] as List).map((deal) => Deal.fromJson(deal)).toList()
          : [],
      menu: json['menu'] != null
          ? (json['menu'] as List).map((item) => MenuItem.fromJson(item)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'rating': rating,
      'reviewCount': reviewCount,
      'icon': icon,
      'deals': deals.map((deal) => deal.toJson()).toList(),
      'menu': menu.map((item) => item.toJson()).toList(),
    };
  }

  // Get only valid deals
  List<Deal> getValidDeals() {
    return deals.where((deal) => deal.isValid()).toList();
  }

  // Check if startup has any active deals
  bool hasActiveDeals() {
    return getValidDeals().isNotEmpty;
  }

  // Get rating as stars
  int getFullStars() {
    return rating.floor();
  }

  bool hasHalfStar() {
    return (rating - rating.floor()) >= 0.5;
  }

  // Get formatted rating string
  String getFormattedRating() {
    return '${rating.toStringAsFixed(1)} (${reviewCount} reviews)';
  }

  // Calculate distance from a point
  double calculateDistance(double lat, double lon) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        (0.5 * (1 - cos((latitude - lat) * p))) +
        cos(lat * p) * cos(latitude * p) * (1 - cos((longitude - lon) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Menu-related methods
  bool hasMenu() {
    return menu.isNotEmpty;
  }

  List<String> getMenuCategories() {
    return menu.map((item) => item.category).toSet().toList();
  }

  List<MenuItem> getMenuByCategory(String category) {
    return menu.where((item) => item.category == category).toList();
  }

  Map<String, List<MenuItem>> getGroupedMenu() {
    final Map<String, List<MenuItem>> grouped = {};
    for (var item in menu) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }
    return grouped;
  }
}

// Extension for sorting
extension StartupSorting on List<Startup> {
  List<Startup> sortByRating({bool descending = true}) {
    final sorted = List<Startup>.from(this);
    sorted.sort((a, b) => descending
        ? b.rating.compareTo(a.rating)
        : a.rating.compareTo(b.rating));
    return sorted;
  }

  List<Startup> sortByReviewCount({bool descending = true}) {
    final sorted = List<Startup>.from(this);
    sorted.sort((a, b) => descending
        ? b.reviewCount.compareTo(a.reviewCount)
        : a.reviewCount.compareTo(b.reviewCount));
    return sorted;
  }

  List<Startup> sortByName({bool ascending = true}) {
    final sorted = List<Startup>.from(this);
    sorted.sort((a, b) =>
        ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
    return sorted;
  }

  List<Startup> filterByCategory(String category) {
    if (category == 'All') return this;
    return where((startup) => startup.category == category).toList();
  }

  List<Startup> filterByMinRating(double minRating) {
    return where((startup) => startup.rating >= minRating).toList();
  }

  List<Startup> withActiveDeals() {
    return where((startup) => startup.hasActiveDeals()).toList();
  }

  List<Startup> withMenu() {
    return where((startup) => startup.hasMenu()).toList();
  }
}