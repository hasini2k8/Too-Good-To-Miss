import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'models/startup.dart';
import 'bottom_nav_bar.dart';
import 'services/auth_service.dart';
import 'startup_detail_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _points = 1978;
  String _selectedCategory = 'All';
  double userLat = 43.6532;
  double userLon = -79.3832;
  double searchRadiusKm = 50;
  List<Startup> allStartups = [];
  bool isLoading = true;
  String userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    loadStartupsData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      setState(() {
        userName = user['username'] ?? 'User';
        _points = user['points'] ?? 0;
      });
    }
  }

  Future<void> loadStartupsData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/startups.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final userLocation = jsonData['user_location'];
      userLat = userLocation['latitude'].toDouble();
      userLon = userLocation['longitude'].toDouble();
      searchRadiusKm = jsonData['search_radius_km'].toDouble();

      final List<dynamic> startupsJson = jsonData['startups'];
      allStartups = startupsJson.map((json) => Startup.fromJson(json)).toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading startups data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  List<Startup> getFilteredStartups() {
    return allStartups.where((startup) {
      final distance = calculateDistance(
        userLat,
        userLon,
        startup.latitude,
        startup.longitude,
      );
      final withinRange = distance <= searchRadiusKm;
      final matchesCategory =
          _selectedCategory == 'All' || startup.category == _selectedCategory;
      return withinRange && matchesCategory;
    }).toList();
  }

  void _navigateToStartupDetail(Startup startup) {
    final distance = calculateDistance(
      userLat,
      userLon,
      startup.latitude,
      startup.longitude,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartupDetailPage(
          startup: startup,
          distance: distance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F4F8),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filteredStartups = getFilteredStartups();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good day $userName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_points pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.purple[200],
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Featured Startups!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: Colors.grey[800],
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildCategoryChip('All'),
                            _buildCategoryChip('Food'),
                            _buildCategoryChip('Retail'),
                            _buildCategoryChip('Technology'),
                            _buildCategoryChip('Services'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredStartups.isEmpty
                            ? Center(
                                child: Text(
                                  'No startups found in this category',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredStartups.length,
                                itemBuilder: (context, index) {
                                  return _buildStartupCard(
                                      filteredStartups[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 0),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: const Color(0xFF1565C0),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStartupCard(Startup startup) {
    final distance = calculateDistance(
      userLat,
      userLon,
      startup.latitude,
      startup.longitude,
    );

    return GestureDetector(
      onTap: () => _navigateToStartupDetail(startup),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          startup.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                        startup.rating.floor(),
                        (index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    startup.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${distance.toStringAsFixed(1)} km away',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.white.withOpacity(0.9),
                child: Center(
                  child: Text(
                    startup.icon,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}