import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapTestPage extends StatelessWidget {
  const MapTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Test'),
        backgroundColor: Colors.blue,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(43.6532, -79.3832), // Toronto
          zoom: 14,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}