 /*
 1st Version 
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Example',
      home: MapboxMapScreen(),
    );
  }
}

class MapboxMapScreen extends StatefulWidget {
  @override
  _MapboxMapScreenState createState() => _MapboxMapScreenState();
}

class _MapboxMapScreenState extends State<MapboxMapScreen> {
  MapboxMapController? mapController;
  // Default location (San Francisco) until the user location is obtained.
  LatLng _currentPosition = LatLng(37.7749, -122.4194);

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    _getUserLocation();
    _addOtherUserMarker();
  }

  Future<void> _getUserLocation() async {
    // Ensure you handle location permissions appropriately.
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  void _addOtherUserMarker() {
    // Adds a dummy marker for another user.
    mapController?.addSymbol(SymbolOptions(
      geometry: LatLng(_currentPosition.latitude + 0.01,
          _currentPosition.longitude + 0.01),
      iconImage: "marker-15", // default icon from Mapbox
      iconSize: 1.5,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapbox Map'),
        // Drop-down menu in the top left for sign in/up.
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
        accessToken: "pk.eyJ1IjoiZGFtb3NzIiwiYSI6ImNtNnRyZzk5MTA2NzkyaXExN2EyNTR1dWsifQ.UdaXenvYULYz6lkQbLU1hg",
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14.0,
        ),
        myLocationEnabled: true,
      ),
      // Floating action button to re-center on the user's location.
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.my_location),
        onPressed: _getUserLocation,
      ),
    );
  }
}
*/


/*
2nd Version 
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String mapboxAccessToken = "pk.eyJ1IjoiZGFtb3NzIiwiYSI6ImNtNnRyZzk5MTA2NzkyaXExN2EyNTR1dWsifQ.UdaXenvYULYz6lkQbLU1hg";
  late MapboxMapController mapController;

  // Default starting location (San Francisco)
  final LatLng initialLocation = LatLng(37.7749, -122.4194);

  // Called when the Mapbox map is created.
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;

    // Optionally, add a marker at the initial location
    mapController.addSymbol(
      SymbolOptions(
        geometry: initialLocation,
        iconImage: "assets/marker.png", // Ensure this asset is declared in pubspec.yaml
        iconSize: 1.5,
      ),
    );
  }

  /// Retrieves the current device location and animates the camera to that position.
  Future<void> _goToMyLocation() async {
    try {
      // Get the current position with high accuracy.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng myLocation = LatLng(position.latitude, position.longitude);

      // Animate the camera to the current location with a zoom level of 15.0.
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: myLocation,
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      // Handle errors (e.g., location permission denied)
      print('Error retrieving location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Mapbox Example")),
      body: MapboxMap(
        accessToken: mapboxAccessToken,
        initialCameraPosition: CameraPosition(target: initialLocation, zoom: 12.0),
        onMapCreated: _onMapCreated,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
*/

 /*
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String mapboxAccessToken = "pk.eyJ1IjoiZGFtb3NzIiwiYSI6ImNtNnRyZzk5MTA2NzkyaXExN2EyNTR1dWsifQ.UdaXenvYULYz6lkQbLU1hg";
  late MapboxMapController mapController;

  // Default starting location (San Francisco)
  final LatLng initialLocation = LatLng(37.7749, -122.4194);

  // Reference to the circle marking the user's location.
  Circle? _myLocationCircle;

  /// Called when the Mapbox map is created.
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;

    // Optionally, add a marker at the initial location.
    mapController.addSymbol(
      SymbolOptions(
        geometry: initialLocation,
        iconImage: "assets/marker.png", // Ensure this asset is declared in pubspec.yaml.
        iconSize: 1.5,
      ),
    );
  }

  /// Retrieves the current location, updates the location circle,
  /// and animates the camera in two smooth steps.
  Future<void> _goToMyLocation() async {
    try {
      // Get the current device location with high accuracy.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng myLocation = LatLng(position.latitude, position.longitude);

      // Add or update a circle overlay marking the current location.
      if (_myLocationCircle == null) {
        _myLocationCircle = await mapController.addCircle(
          CircleOptions(
            geometry: myLocation,
            circleRadius: 8.0,       // Adjust radius as needed.
            circleColor: "#007AFF",  // A blue color.
            circleOpacity: 0.5,
          ),
        );
      } else {
        mapController.updateCircle(
          _myLocationCircle!,
          CircleOptions(geometry: myLocation),
        );
      }

      // First step: animate the camera to center on your location with an assumed zoom level (12.0).
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: myLocation,
            zoom: 12.0,
          ),
        ),
      );

      // Short delay for a smoother transition.
      await Future.delayed(Duration(milliseconds: 300));

      // Second step: animate to a higher (zoomed in) level (16.0).
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: myLocation,
            zoom: 16.0,
          ),
        ),
      );
    } catch (e) {
      // Handle errors (e.g., location permission denied).
      print('Error retrieving location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Mapbox Example")),
      body: MapboxMap(
        accessToken: mapboxAccessToken,
        initialCameraPosition: CameraPosition(target: initialLocation, zoom: 12.0),
        onMapCreated: _onMapCreated,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
*/


////////////////////////////////////////////////////////////////////////////////
///
///
////* 
//3rd version 
// Last working version 
/* 

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mapbox Web Example',
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String mapboxAccessToken =
      "pk.eyJ1IjoiZGFtb3NzIiwiYSI6ImNtNnRyZzk5MTA2NzkyaXExN2EyNTR1dWsifQ.UdaXenvYULYz6lkQbLU1hg";
  MapboxMapController? mapController;
  LatLng? _currentLocation;
  bool _isMapCreated = false;

  // For mobile: we'll use a circle overlay.
  Circle? _locationCircle;
  // For web: we'll use a symbol with our loaded image.
  Symbol? _userLocationSymbol;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  /// Fetches the user's current location.
  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      LatLng newLocation =
          LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = newLocation;
      });
      // If the map is already created, add or update the overlay.
      if (_isMapCreated) {
        if (kIsWeb) {
          if (_userLocationSymbol == null) {
            await _addUserLocationSymbol(newLocation);
          } else {
            await _updateUserLocationSymbol(newLocation);
          }
        } else {
          if (_locationCircle == null) {
            await _addLocationCircle(newLocation);
          } else {
            await _updateLocationCircle(newLocation);
          }
        }
      }
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  /// For web: loads the image asset and adds it to the map style.
  Future<void> _loadUserLocationImage() async {
    final ByteData bytes =
        await rootBundle.load('assets/user_location_web.png');
    final Uint8List imageData = bytes.buffer.asUint8List();
    await mapController?.addImage("user_location_web", imageData);
  }

  /// Called when the Mapbox map is created.
  void _onMapCreated(MapboxMapController controller) async {
    mapController = controller;
    _isMapCreated = true;
    if (kIsWeb) {
      // On web, load the image asset into the map style.
      await _loadUserLocationImage();
      if (_currentLocation != null) {
        _addUserLocationSymbol(_currentLocation!);
      }
    } else {
      if (_currentLocation != null) {
        _addLocationCircle(_currentLocation!);
      }
    }
  }

  /// For mobile: adds a circle overlay with a blue fill and white outline.
  Future<void> _addLocationCircle(LatLng location) async {
    _locationCircle = await mapController!.addCircle(
      CircleOptions(
        geometry: location,
        circleRadius: 30.0,           // Size of the circle.
        circleColor: "#007AFF",        // Blue fill color.
        circleOpacity: 1.0,            // Fully opaque fill.
        circleStrokeWidth: 3.0,        // Stroke width.
        circleStrokeColor: "#FFFFFF",  // White stroke color.
        circleStrokeOpacity: 1.0,      // Fully opaque stroke.
      ),
    );
  }

  /// For mobile: updates the circle overlay's position.
  Future<void> _updateLocationCircle(LatLng location) async {
    if (_locationCircle != null) {
      await mapController!.updateCircle(
        _locationCircle!,
        CircleOptions(geometry: location),
      );
    }
  }

  /// For web: adds a symbol using the loaded image.
  Future<void> _addUserLocationSymbol(LatLng location) async {
    _userLocationSymbol = await mapController!.addSymbol(
      SymbolOptions(
        geometry: location,
        iconImage: "user_location_web", // Reference the loaded image.
        iconSize: 1.0,
        iconAnchor: "center",
      ),
    );
  }

  /// For web: updates the symbol's position.
  Future<void> _updateUserLocationSymbol(LatLng location) async {
    if (_userLocationSymbol != null) {
      await mapController!.updateSymbol(
        _userLocationSymbol!,
        SymbolOptions(geometry: location),
      );
    }
  }

  /// Retrieves the current location, updates the overlay, and animates the camera.
  Future<void> _goToMyLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation =
          LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = myLocation;
      });
      if (kIsWeb) {
        await _updateUserLocationSymbol(myLocation);
      } else {
        await _updateLocationCircle(myLocation);
      }
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: myLocation, zoom: 12.0),
        ),
      );
      await Future.delayed(Duration(milliseconds: 300));
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: myLocation, zoom: 16.0),
        ),
      );
    } catch (e) {
      print("Error retrieving location on button press: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Mapbox Web Example")),
      body: MapboxMap(
        accessToken: mapboxAccessToken,
        initialCameraPosition: CameraPosition(
          target: _currentLocation!,
          zoom: 16.0,
        ),
        onMapCreated: _onMapCreated,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}

*/


////////////////////////////////////////////////////////////////////////////////
// In this version I am trying to add a circle aroudn the location of each cutomer in which the image will be place. Which can't seem to work on flutter web. 
// Steps tried : 
//1- Add flutter web Javascript in web/html 
// 2- added pic assets in assets folder 
//



/*  4th version 
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

class MapboxMapScreen extends StatefulWidget {
  @override
  _MapboxMapScreenState createState() => _MapboxMapScreenState();
}

class _MapboxMapScreenState extends State<MapboxMapScreen> {
  MapboxMapController? mapController;
  // Default location (San Francisco) until the user location is obtained.
  LatLng _currentPosition = LatLng(37.7749, -122.4194);

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    _getUserLocation();
    // Only add extra markers on mobile.
    if (!kIsWeb) {
      _addOtherUserMarker();
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Request location permission and get the user's current position.
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      // Only animate the camera on mobile.
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

  // Build the Mapbox widget conditionally based on platform.
  Widget _buildMap() {
    if (kIsWeb) {
      return MapboxMap(
        accessToken: "YOUR_MAPBOX_ACCESS_TOKEN",
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14.0,
        ),
        // Do not include myLocationEnabled on web.
      );
    } else {
      return MapboxMap(
        accessToken: "YOUR_MAPBOX_ACCESS_TOKEN",
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14.0,
        ),
        myLocationEnabled: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapbox Map'),
        // Dropdown menu for sign in/up.
        leading: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'sign_in') {
              // Navigate to sign in.
            } else if (value == 'sign_up') {
              // Navigate to sign up.
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
      body: _buildMap(),
      // Floating action button to refresh location.
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.my_location),
        onPressed: _getUserLocation,
      ),
    );
  }
}
 */


//5th version  : working but no circle 
/* 
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mapbox Web Example',
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Replace with your valid Mapbox access token.
  static const String mapboxAccessToken =
      "pk.eyJ1IjoiZGFtb3NzIiwiYSI6ImNtNnRyZzk5MTA2NzkyaXExN2EyNTR1dWsifQ.UdaXenvYULYz6lkQbLU1hg";
  MapboxMapController? mapController;
  LatLng? _currentLocation;
  bool _isMapCreated = false;
  bool _isStyleLoaded = false;

  static const String _geoJsonSourceId = "location-source";
  static const String _geoJsonLayerId = "location-layer";

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  /// Fetches the user's current location.
  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      LatLng newLocation = LatLng(position.latitude, position.longitude);
      print("Fetched location: $newLocation");
      setState(() {
        _currentLocation = newLocation;
      });
      // If the map is already created and style loaded, update the GeoJSON source.
      if (_isMapCreated && _isStyleLoaded) {
        await _updateLocationOnMap(newLocation);
      }
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  /// Called when the Mapbox map is created.
  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    _isMapCreated = true;
  }

  /// Called when the map's style has finished loading.
  void _onStyleLoaded() async {
    _isStyleLoaded = true;
    if (_currentLocation != null) {
      await _addGeoJsonCircle(_currentLocation!);
    }
  }

  /// Adds a GeoJSON source and circle layer to mark the location.
  Future<void> _addGeoJsonCircle(LatLng location) async {
    if (mapController == null) return;

    // Create the GeoJSON data.
    Map<String, dynamic> geoJsonData = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [location.longitude, location.latitude]
          },
          "properties": {}
        }
      ]
    };

    try {
      // Add the GeoJSON source.
      await mapController!.addSource(
        _geoJsonSourceId,
        GeojsonSourceProperties(data: geoJsonData),
      );
      // Add the circle layer.
      await mapController!.addLayer(
        _geoJsonLayerId, // layerId
        _geoJsonSourceId, // sourceId
        CircleLayerProperties(
          circleRadius: 15, // Adjust for desired size.
          circleColor: "#007AFF", // Blue fill.
          circleOpacity: 1.0, // Fully visible.
          circleStrokeWidth: 3, // Stroke width.
          circleStrokeColor: "#FFFFFF", // White outline.
        ),
        belowLayerId: null,
      );
    } catch (e) {
      print("Error adding geojson circle: $e");
    }
  }

  /// Updates the existing GeoJSON source with a new location.
  Future<void> _updateLocationOnMap(LatLng location) async {
    if (mapController == null) return;

    Map<String, dynamic> updatedGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [location.longitude, location.latitude]
          },
          "properties": {}
        }
      ]
    };

    try {
      await mapController!.setGeoJsonSource(_geoJsonSourceId, updatedGeoJson);
    } catch (e) {
      print("Error updating geojson source: $e");
      // If updating fails, remove and re-add the source.
      try {
        await mapController!.removeSource(_geoJsonSourceId);
      } catch (ex) {
        print("Error removing source: $ex");
      }
      await _addGeoJsonCircle(location);
    }
  }

  /// Button action: fetch the current location, update the source, and animate the camera.
  Future<void> _goToMyLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation = LatLng(position.latitude, position.longitude);
      print("Button location: $myLocation");
      setState(() {
        _currentLocation = myLocation;
      });
      if (_isMapCreated && _isStyleLoaded) {
        await _updateLocationOnMap(myLocation);
      }
      // Animate the camera in two steps for a smoother transition.
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: myLocation, zoom: 12.0),
        ),
      );
      await Future.delayed(Duration(milliseconds: 300));
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: myLocation, zoom: 16.0),
        ),
      );
    } catch (e) {
      print("Error retrieving location on button press: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Mapbox Web Example")),
      body: MapboxMap(
        accessToken: mapboxAccessToken,
        initialCameraPosition: CameraPosition(
          target: _currentLocation!,
          zoom: 16.0,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}

 */

///////////////////////////////////////////////
///


import 'dart:html';
import 'dart:ui_web' as ui;  // Import from dart:ui_web to avoid deprecation warnings.
import 'package:flutter/material.dart';

void main() {
  // Register a view factory that creates a <div> with id 'mapbox-map'
  ui.platformViewRegistry.registerViewFactory('mapbox-gl-element', (int viewId) {
    final div = DivElement()
      ..id = 'mapbox-map'
      ..style.width = '100%'
      ..style.height = '100%';
    return div;
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox GL JS Integration',
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapbox GL JS in Flutter")),
      body: HtmlElementView(viewType: 'mapbox-gl-element'),
    );
  }
} 