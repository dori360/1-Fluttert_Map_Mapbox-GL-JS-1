import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

class MapboxMapScreen extends StatefulWidget {
  const MapboxMapScreen({super.key});

  @override
  _MapboxMapScreenState createState() => _MapboxMapScreenState();
}

class _MapboxMapScreenState extends State<MapboxMapScreen> {
  MapboxMapController? mapController;
  // Default location (San Francisco) until user location is obtained.
  LatLng _currentPosition = LatLng(37.7749, -122.4194);

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    _getUserLocation();

    // On mobile, add a dummy marker for another user.
    if (!kIsWeb) {
      _addOtherUserMarker();
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Request the current position (ensure proper location permissions).
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // On mobile, animate the camera to the user's location.
      if (!kIsWeb) {
        mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
      }
    } catch (e) {
      print("Error retrieving location: $e");
    }
  }

  void _addOtherUserMarker() {
    // Add a dummy marker for another user nearby (only on mobile).
    mapController?.addSymbol(
      SymbolOptions(
        geometry: LatLng(
          _currentPosition.latitude + 0.01,
          _currentPosition.longitude + 0.01,
        ),
        iconImage: "marker-15", // Default Mapbox icon.
        iconSize: 1.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapbox Map'),
        // Dropdown menu in the top left for sign in/up.
        leading: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'sign_in') {
              // Navigate to sign in screen.
            } else if (value == 'sign_up') {
              // Navigate to sign up screen.
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'sign_in',
              child: Text('Sign In'),
            ),
            PopupMenuItem<String>(
              value: 'sign_up',
              child: Text('Sign Up'),
            ),
          ],
          icon: Icon(Icons.menu),
        ),
      ),
      body: MapboxMap(
        accessToken: "YOUR_MAPBOX_ACCESS_TOKEN",
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14.0,
        ),
        // Disable myLocationEnabled on web to avoid the myLocationRenderMode error.
        myLocationEnabled: !kIsWeb,
      ),
      // Floating action button to re-center on the user's location.
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
