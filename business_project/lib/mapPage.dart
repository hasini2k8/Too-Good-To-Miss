import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // ADD to pubspec.yaml: url_launcher: ^6.2.0
import 'dart:ui' as ui;
import 'dart:convert';
import '../models/startup.dart';
import '../models/deal.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../services/deal_service.dart';
import '../services/bookmark_services.dart';
import '../services/auth_service.dart';
import '../bottom_nav_bar.dart';
import '../widgets/puzzle_captcha_widget.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  List<Startup> _allStartups = [];
  List<Startup> _filteredStartups = [];
  Set<Marker> _markers = {};
  Marker? _userLocationMarker;
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _sortBy = 'Name';
  String _selectedRating = 'All';
  double _userLat = 43.6532;
  double _userLon = -79.3832;
  bool _locationPermissionGranted = false;
  String _locationStatus = 'Getting location...';

  final ReviewService _reviewService = ReviewService();
  final DealService _dealService = DealService();
  final BookmarkService _bookmarkService = BookmarkService();

  final List<String> _categories = ['All', 'Food', 'Retail', 'Technology', 'Services'];
  final List<String> _ratingFilters = ['All', '5★', '4★+', '3★+', '2★+', '1★+'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _reviewService.initialize();
    await _dealService.initialize();
    await _bookmarkService.initialize();
    await _getCurrentLocation();
    await _loadStartupsData();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _locationStatus = 'Location services disabled'; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _locationStatus = 'Location permission denied'; });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() { _locationStatus = 'Location permission denied forever'; });
        return;
      }

      setState(() { _locationStatus = 'Getting your location...'; });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLat = position.latitude;
        _userLon = position.longitude;
        _locationPermissionGranted = true;
        _locationStatus = 'Location found';
      });

      await _createUserLocationMarker();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(_userLat, _userLon)),
        );
      }
    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() { _locationStatus = 'Error getting location'; });
    }
  }

  Future<void> _loadStartupsData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/startups.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      if (!_locationPermissionGranted) {
        final userLocation = jsonData['user_location'];
        _userLat = userLocation['latitude'].toDouble();
        _userLon = userLocation['longitude'].toDouble();
      }

      final List<dynamic> startupsJson = jsonData['startups'];
      _allStartups = startupsJson.map((json) => Startup.fromJson(json)).toList();

      _applyFiltersAndSort();
      await _createMarkers();

      setState(() { _isLoading = false; });
    } catch (e) {
      print('Error loading startups data: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _applyFiltersAndSort() {
    _filteredStartups = _allStartups.filterByCategory(_selectedCategory);

    if (_selectedRating != 'All') {
      switch (_selectedRating) {
        case '5★':
          _filteredStartups = _filteredStartups.where((s) => s.rating == 5.0).toList();
          break;
        case '4★+':
          _filteredStartups = _filteredStartups.where((s) => s.rating >= 4.0).toList();
          break;
        case '3★+':
          _filteredStartups = _filteredStartups.where((s) => s.rating >= 3.0).toList();
          break;
        case '2★+':
          _filteredStartups = _filteredStartups.where((s) => s.rating >= 2.0).toList();
          break;
        case '1★+':
          _filteredStartups = _filteredStartups.where((s) => s.rating >= 1.0).toList();
          break;
      }
    }

    switch (_sortBy) {
      case 'Rating':
        _filteredStartups = _filteredStartups.sortByRating();
        break;
      case 'Reviews':
        _filteredStartups = _filteredStartups.sortByReviewCount();
        break;
      case 'Name':
      default:
        _filteredStartups = _filteredStartups.sortByName();
        break;
    }
  }

  Future<void> _createMarkers() async {
    final Set<Marker> markers = {};

    for (final startup in _filteredStartups) {
      final isBookmarked = await _bookmarkService.isBookmarked(startup.id);
      Color markerColor = _getMarkerColorForCategory(startup.category);
      if (isBookmarked) markerColor = Colors.pink;

      final BitmapDescriptor markerIcon = await _createDotMarker(markerColor);

      markers.add(
        Marker(
          markerId: MarkerId(startup.id),
          position: LatLng(startup.latitude, startup.longitude),
          icon: markerIcon,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _showStartupDetails(startup),
          infoWindow: InfoWindow(
            title: startup.name,
            snippet: '⭐ ${startup.rating} ${startup.hasActiveDeals() ? "🎁" : ""}',
          ),
        ),
      );
    }

    setState(() { _markers = markers; });
  }

  Future<BitmapDescriptor> _createDotMarker(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const size = 24.0;
    const radius = size / 2;

    canvas.drawCircle(const Offset(radius, radius), radius, strokePaint);
    canvas.drawCircle(const Offset(radius, radius), radius - 1.5, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _createUserLocationMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const size = 80.0;
    const emojiSize = 50.0;

    final glowPaint = Paint()
      ..color = const Color(0xFF1565C0).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, glowPaint);

    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), emojiSize / 2 + 3, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(size / 2, size / 2), emojiSize / 2 + 3, borderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(text: '📍', style: TextStyle(fontSize: 40)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());

    setState(() {
      _userLocationMarker = Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(_userLat, _userLon),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'You are here', snippet: 'Your current location'),
        zIndex: 999,
      );
    });
  }

  Color _getMarkerColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'retail': return Colors.blue;
      case 'technology': return Colors.purple;
      case 'services': return Colors.green;
      default: return Colors.lightBlue;
    }
  }

  void _recenterToUserLocation() async {
    setState(() { _locationStatus = 'Getting your location...'; });
    await _getCurrentLocation();

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(_userLat, _userLon), zoom: 14),
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationPermissionGranted
              ? 'Centered on your location'
              : 'Could not get your location'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showStartupDetails(Startup startup) async {
    await AuthService.recordPlaceVisit(startup.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StartupDetailsSheet(
        startup: startup,
        reviewService: _reviewService,
        dealService: _dealService,
        bookmarkService: _bookmarkService,
        userLat: _userLat,
        userLon: _userLon,
        onBookmarkChanged: () => _createMarkers(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F4F8),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_locationStatus, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_userLat, _userLon),
              zoom: 12,
            ),
            onMapCreated: (controller) { _mapController = controller; },
            markers: {
              ..._markers,
              if (_userLocationMarker != null) _userLocationMarker!,
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Top bar with filters
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_filteredStartups.length} Startups',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1565C0))),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(_locationPermissionGranted ? Icons.location_on : Icons.location_off,
                                    size: 14, color: _locationPermissionGranted ? Colors.green : Colors.orange),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _locationPermissionGranted ? 'Using your location' : 'Using default location',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1565C0)),
                                items: _categories.map((String category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Row(
                                      children: [
                                        Icon(_getCategoryIcon(category), size: 20, color: const Color(0xFF1565C0)),
                                        const SizedBox(width: 8),
                                        Text(category, style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() { _selectedCategory = newValue; _applyFiltersAndSort(); _createMarkers(); });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        // Sort dropdown removed per request (defaults to `_sortBy` = 'Name')
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRating,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1565C0)),
                          items: _ratingFilters.map((String rating) {
                            return DropdownMenuItem(
                              value: rating,
                              child: Row(
                                children: [
                                  const Icon(Icons.star, size: 20, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Text(rating == 'All' ? 'All Ratings' : rating,
                                    style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() { _selectedRating = newValue; _applyFiltersAndSort(); _createMarkers(); });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: 16, bottom: 180,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              onPressed: _recenterToUserLocation,
              backgroundColor: Colors.white,
              child: Icon(
                _locationPermissionGranted ? Icons.my_location : Icons.location_searching,
                color: const Color(0xFF1565C0),
              ),
            ),
          ),

          Positioned(
            right: 16, bottom: 100,
            child: FloatingActionButton(
              heroTag: 'bookmarks',
              onPressed: () => _showBookmarkedStartups(),
              backgroundColor: const Color(0xFF1565C0),
              child: const Icon(Icons.bookmark, color: Colors.white),
            ),
          ),

          Positioned(
            left: 16, bottom: 100,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1565C0))),
                  const SizedBox(height: 8),
                  _buildLegendItem('Food', Colors.orange),
                  _buildLegendItem('Retail', Colors.blue),
                  _buildLegendItem('Technology', Colors.purple),
                  _buildLegendItem('Services', Colors.green),
                  const Divider(height: 12),
                  _buildLegendItem('Bookmarked', Colors.pink),
                  const Divider(height: 12),
                  _buildEmojiLegendItem('You are here', '📍'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 1),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food': return Icons.restaurant;
      case 'Retail': return Icons.shopping_bag;
      case 'Technology': return Icons.computer;
      case 'Services': return Icons.spa;
      default: return Icons.category;
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildEmojiLegendItem(String label, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showBookmarkedStartups() async {
    final bookmarkedIds = await _bookmarkService.getBookmarkedIds();
    final bookmarkedStartups = _allStartups.where((s) => bookmarkedIds.contains(s.id)).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookmarkedStartupsSheet(
        startups: bookmarkedStartups,
        onStartupTap: (startup) {
          Navigator.pop(context);
          _showStartupDetails(startup);
        },
      ),
    );
  }
}

class RouteHelper {

  static Map<String, String> estimateTravelTimes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    final distanceM = Geolocator.distanceBetween(fromLat, fromLon, toLat, toLon);
    final distanceKm = distanceM / 1000;

    final driveMins = ((distanceKm * 1.35) / 40 * 60).round();
    final transitMins = ((distanceKm * 1.35) / 25 * 60).round();
    final walkMins = ((distanceKm * 1.35) / 5 * 60).round();
    final cycleMins = ((distanceKm * 1.35) / 15 * 60).round();

    String fmt(int mins) {
      if (mins < 60) return '$mins min';
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }

    return {
      'driving': fmt(driveMins),
      'transit': fmt(transitMins),
      'walking': fmt(walkMins),
      'cycling': fmt(cycleMins),
      'distanceKm': distanceKm.toStringAsFixed(1),
    };
  }

  static Future<void> openGoogleMapsDirections({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required String travelMode, 
  }) async {
    final nativeUri = Uri.parse(
      'comgooglemaps://?saddr=$fromLat,$fromLon&daddr=$toLat,$toLon&directionsmode=$travelMode',
    );
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$fromLat,$fromLon'
      '&destination=$toLat,$toLon'
      '&travelmode=$travelMode',
    );

    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}


class RouteOptionsSheet extends StatefulWidget {
  final Startup startup;
  final double userLat;
  final double userLon;

  const RouteOptionsSheet({
    super.key,
    required this.startup,
    required this.userLat,
    required this.userLon,
  });

  @override
  State<RouteOptionsSheet> createState() => _RouteOptionsSheetState();
}

class _RouteOptionsSheetState extends State<RouteOptionsSheet> {
  String _selectedMode = 'driving';
  late Map<String, String> _times;

  static const _modes = [
    {'key': 'driving',   'label': 'Drive',    'icon': Icons.directions_car,   'gmaps': 'driving'},
    {'key': 'transit',   'label': 'Transit',  'icon': Icons.directions_transit,'gmaps': 'transit'},
    {'key': 'walking',   'label': 'Walk',     'icon': Icons.directions_walk,  'gmaps': 'walking'},
    {'key': 'cycling',   'label': 'Cycle',    'icon': Icons.directions_bike,  'gmaps': 'bicycling'},
  ];

  @override
  void initState() {
    super.initState();
    _times = RouteHelper.estimateTravelTimes(
      fromLat: widget.userLat,
      fromLon: widget.userLon,
      toLat: widget.startup.latitude,
      toLon: widget.startup.longitude,
    );
  }

  void _launch() {
    final mode = _modes.firstWhere((m) => m['key'] == _selectedMode);
    RouteHelper.openGoogleMapsDirections(
      fromLat: widget.userLat,
      fromLon: widget.userLon,
      toLat: widget.startup.latitude,
      toLon: widget.startup.longitude,
      travelMode: mode['gmaps'] as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _times['distanceKm'] ?? '?';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions, color: Color(0xFF1565C0), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Directions to', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    Text(widget.startup.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$distanceKm km',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text('Choose travel mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 12),

          Row(
            children: _modes.map((mode) {
              final key = mode['key'] as String;
              final isSelected = _selectedMode == key;
              final time = _times[key] ?? '—';

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1565C0) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                      ] : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(mode['icon'] as IconData,
                          color: isSelected ? Colors.white : Colors.grey[600], size: 26),
                        const SizedBox(height: 6),
                        Text(mode['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          )),
                        const SizedBox(height: 4),
                        Text(time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white.withOpacity(0.9) : const Color(0xFF1565C0),
                          )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Times are estimates. Live traffic will be shown in Google Maps.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _launch,
              icon: const Text('🗺️', style: TextStyle(fontSize: 18)),
              label: const Text(
                'Open in Google Maps',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StartupDetailsSheet extends StatefulWidget {
  final Startup startup;
  final ReviewService reviewService;
  final DealService dealService;
  final BookmarkService bookmarkService;
  final double userLat;
  final double userLon;
  final VoidCallback onBookmarkChanged;

  const StartupDetailsSheet({
    super.key,
    required this.startup,
    required this.reviewService,
    required this.dealService,
    required this.bookmarkService,
    required this.userLat,
    required this.userLon,
    required this.onBookmarkChanged,
  });

  @override
  State<StartupDetailsSheet> createState() => _StartupDetailsSheetState();
}

class _StartupDetailsSheetState extends State<StartupDetailsSheet> {
  bool _isBookmarked = false;
  List<Review> _reviews = [];
  List<Deal> _deals = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isBookmarked = await widget.bookmarkService.isBookmarked(widget.startup.id);
    final reviews = await widget.reviewService.getReviewsForStartup(widget.startup.id);
    final deals = widget.dealService.getDealsForStartup(widget.startup.id);

    setState(() {
      _isBookmarked = isBookmarked;
      _reviews = reviews;
      _deals = deals;
    });
  }

  Future<void> _toggleBookmark() async {
    final newStatus = await widget.bookmarkService.toggleBookmark(widget.startup.id);
    setState(() { _isBookmarked = newStatus; });
    widget.onBookmarkChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBookmarked ? 'Added to bookmarks (+5 points!)' : 'Removed from bookmarks'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addReview() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to post a review')),
      );
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AddReviewDialog(
        startup: widget.startup,
        reviewService: widget.reviewService,
        username: user['username'],
        onReviewAdded: _loadData,
      ),
    );
  }

  void _showRouteOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RouteOptionsSheet(
        startup: widget.startup,
        userLat: widget.userLat,
        userLon: widget.userLon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(widget.startup.icon, style: const TextStyle(fontSize: 30))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.startup.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ...List.generate(widget.startup.getFullStars(),
                                (i) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                              if (widget.startup.hasHalfStar())
                                const Icon(Icons.star_half, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(widget.startup.getFormattedRating(),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: _isBookmarked ? const Color(0xFF1565C0) : Colors.grey,
                      ),
                      onPressed: _toggleBookmark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showRouteOptions,
                    icon: const Icon(Icons.directions, color: Colors.white, size: 20),
                    label: const Text(
                      'Get Directions',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                height: 50,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
                child: Row(
                  children: [
                    _buildTab('Info', 0),
                    _buildTab('Deals (${_deals.length})', 1),
                    _buildTab('Reviews (${_reviews.length})', 2),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_selectedTab == 0) _buildInfoTab(),
                    if (_selectedTab == 1) _buildDealsTab(),
                    if (_selectedTab == 2) _buildReviewsTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
              width: 2,
            )),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1565C0) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              )),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.startup.description,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
        const SizedBox(height: 20),
        _buildInfoRow(Icons.location_on, 'Location', widget.startup.location ?? 'N/A'),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.category, 'Category', widget.startup.category),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDealsTab() {
    if (_deals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No deals available', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return Column(children: _deals.map((deal) => _buildDealCard(deal)).toList());
  }

  Widget _buildDealCard(Deal deal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: Text(deal.getDiscountBadge(),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(deal.title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(deal.description, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.code, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(deal.code,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Valid until ${deal.getFormattedValidUntil()}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          if (deal.terms.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text('Terms: ${deal.terms}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addReview,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Write a Review (+10 points)', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_reviews.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No reviews yet', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Be the first to review!', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          )
        else
          ..._reviews.map((review) => _buildReviewCard(review)).toList(),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1565C0),
                child: Text(review.username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(review.getFormattedDate(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 16,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment,
            style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4)),
        ],
      ),
    );
  }
}

class AddReviewDialog extends StatefulWidget {
  final Startup startup;
  final ReviewService reviewService;
  final String username;
  final VoidCallback onReviewAdded;

  const AddReviewDialog({
    super.key,
    required this.startup,
    required this.reviewService,
    required this.username,
    required this.onReviewAdded,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _isVerified = false;

  Future<void> _submitReview() async {
    if (!_isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the puzzle verification'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment')),
      );
      return;
    }

    final reviewId = await widget.reviewService.generateReviewId();
    final review = Review(
      id: reviewId,
      startupId: widget.startup.id,
      username: widget.username,
      rating: _rating,
      comment: _commentController.text.trim(),
      date: DateTime.now().toIso8601String().split('T')[0],
    );

    final success = await widget.reviewService.addReview(review);
    if (success && mounted) {
      widget.onReviewAdded();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review added successfully! +10 points earned!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.rate_review, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Write a Review',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 36),
                    onPressed: () => setState(() => _rating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const Text('Comment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Share your experience with ${widget.startup.name}...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PuzzleCaptchaWidget(
                onVerified: (isVerified) => setState(() => _isVerified = isVerified),
                width: MediaQuery.of(context).size.width * 0.7,
                height: 120,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Review',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class BookmarkedStartupsSheet extends StatelessWidget {
  final List<Startup> startups;
  final Function(Startup) onStartupTap;

  const BookmarkedStartupsSheet({
    super.key,
    required this.startups,
    required this.onStartupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.bookmark, color: Color(0xFF1565C0)),
                const SizedBox(width: 12),
                Text('Bookmarked Startups (${startups.length})',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: startups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No bookmarks yet', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: startups.length,
                    itemBuilder: (context, index) {
                      final startup = startups[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(startup.icon, style: const TextStyle(fontSize: 24))),
                          ),
                          title: Text(startup.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${startup.rating}'),
                              const SizedBox(width: 8),
                              if (startup.hasActiveDeals())
                                const Icon(Icons.local_offer, color: Colors.green, size: 16),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => onStartupTap(startup),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}