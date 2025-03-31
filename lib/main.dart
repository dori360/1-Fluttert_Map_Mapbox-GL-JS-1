
import 'dart:html' hide VoidCallback; // Hide VoidCallback to avoid conflict
import 'dart:ui_web' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'dart:js' as js;
import 'dart:convert';
import 'dart:math' show asin, cos, sin, sqrt, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

// Firebase packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

//==============================================================================
// SECTION 1: DATA MODELS
//==============================================================================

// 1.1: User Profile Data Model
class UserProfileData {
  String? displayName;
  String? photoURL;
  int? age;
  double? height;
  double? weight;
  String? bodyType;
  String? sexuality;
  String? description;
  String? unitSystem; // 'metric' or 'imperial'
  Map<String, dynamic>? additionalPictures;

  // 1.1.1: Constructor
  UserProfileData({
    this.displayName,
    this.photoURL,
    this.age,
    this.height,
    this.weight,
    this.bodyType,
    this.sexuality,
    this.description,
    this.unitSystem = 'metric',
    this.additionalPictures,
  });

  // 1.1.2: Factory constructor from Map
  factory UserProfileData.fromMap(Map<String, dynamic>? data) {
    if (data == null) return UserProfileData();
    
    return UserProfileData(
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      age: data['age'],
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      bodyType: data['bodyType'],
      sexuality: data['sexuality'],
      description: data['description'],
      unitSystem: data['unitSystem'] ?? 'metric',
      additionalPictures: data['additional_pictures'],
    );
  }

  // 1.1.3: Convert to Map method
  Map<String, dynamic> toMap() {
    return {
      if (displayName != null) 'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      if (age != null) 'age': age,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (bodyType != null) 'bodyType': bodyType,
      if (sexuality != null) 'sexuality': sexuality,
      if (description != null) 'description': description,
      'unitSystem': unitSystem,
      if (additionalPictures != null) 'additional_pictures': additionalPictures,
    };
  }
  
  // 1.1.4: Format height method
  String getFormattedHeight() {
    if (height == null) return "Not set";
    
    if (unitSystem == 'imperial') {
      // Convert cm to inches
      final double totalInches = height! * 0.393701;
      final int feet = totalInches ~/ 12;
      final int inches = (totalInches % 12).round();
      return "$feet'$inches\"";
    } else {
      return "$height cm";
    }
  }
  
  // 1.1.5: Format weight method
  String getFormattedWeight() {
    if (weight == null) return "Not set";
    
    if (unitSystem == 'imperial') {
      // Convert kg to lbs
      final double lbs = weight! * 2.20462;
      return "${lbs.round()} lbs";
    } else {
      return "$weight kg";
    }
  }
}

//==============================================================================
// SECTION 2: MAIN APP INITIALIZATION
//==============================================================================

// 2.1: Main entry point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyD2kq-K48QpzD-z5aafs0l8DWF2YJOUmeQ",
      authDomain: "mapbox-in-javascript.firebaseapp.com",
      projectId: "mapbox-in-javascript",
      storageBucket: "mapbox-in-javascript.firebasestorage.app",
      messagingSenderId: "520540991939",
      appId: "1:520540991939:web:fcbaff9ce54d6ad285cd76",
      measurementId: "G-4Q6ZGTTFH4",
    ),
  );

  // 2.2: Configure Firestore settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 2.3: Register MapLibre view factory
  ui.platformViewRegistry.registerViewFactory('mapbox-gl-element', (int viewId) {
    final div = DivElement()
      ..id = 'mapbox-map'
      ..style.width = '100%'
      ..style.height = '100%';
    return div;
  });

  // 2.4: Register JavaScript user profile callback
  js.context['showUserProfile'] = (String userId) {
    // This will be called from JavaScript when a user marker is clicked
    print("User profile requested for: $userId");
    
    // Add the call handler to the window object
    if (js.context['appCallbacks'] == null) {
      js.context['appCallbacks'] = js.JsObject.jsify({});
    }
    
    if (js.context['appCallbacks']['handleUserClick'] != null) {
      js.context.callMethod('eval', [
        'appCallbacks.handleUserClick("$userId")'
      ]);
    }
  };

  // 2.5: Run the app
  runApp(const MyApp());
}

//==============================================================================
// SECTION 3: APP DEFINITION
//==============================================================================

// 3.1: Main App widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 3.1.1: Build method
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapLibre & Firebase Integration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      home: const MapScreen(),
    );
  }
}

//==============================================================================
// SECTION 4: MAP SCREEN 
//==============================================================================

// 4.1: Map Screen Widget
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  // 4.1.1: Create state method
  @override
  _MapScreenState createState() => _MapScreenState();
}

// 4.2: Map Screen State
class _MapScreenState extends State<MapScreen> {
  // 4.2.1: State variables
  Timer? _locationUpdateTimer;
  Timer? _fetchUsersTimer;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _userLocationsSubscription;
  String? _currentUserId;
  bool _isUserLoggedIn = false;
  
  // Store user data for quick access
  Map<String, Map<String, dynamic>> _usersData = {};
  
  // Messaging variables
  bool _hasUnreadMessages = false;
  int _unreadCount = 0;
  double _visibilityRadius = 5.0; // Default 5 miles radius
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
  // 4.2.2: Init state method
  @override
  void initState() {
    super.initState();
    
    // Register the callback for user clicks from JavaScript
    js.context['appCallbacks'] = js.JsObject.jsify({
      'handleUserClick': (String userId) {
        print("Handling user click for: $userId");
        _showUserProfile(userId);
      }
    });
    
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        print("User logged in: ${user.uid} - Email: ${user.email}");
        setState(() {
          _currentUserId = user.uid;
          _isUserLoggedIn = true;
        });
        js.context.callMethod('setCurrentUserId', [_currentUserId]);
        
        // Update online status when logging in
        _updateOnlineStatus(true);
        
        // Start listening for unread messages
        _startListeningForUnreadMessages();
        
        // Force location update when logging in
        _forceLocationUpdate();
        
        // Update location once and start fetching other users
        _updateUserLocation(); // Single update instead of starting timer
        _startFetchingUserLocations();
      } else {
        print("User logged out");
        
        // Update online status when logging out (if we had a user ID before)
        if (_currentUserId != null) {
          _updateOnlineStatus(false);
        }
        
        setState(() {
          _currentUserId = null;
          _isUserLoggedIn = false;
          _hasUnreadMessages = false;
          _unreadCount = 0;
        });
        _stopLocationUpdates();
        _stopFetchingUserLocations();
        _stopListeningForUnreadMessages();
      }
    });
  }

  // 4.2.3: Dispose method
  @override
  void dispose() {
    // Set online status to false before disposing
    _updateOnlineStatus(false);
    
    _authSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _fetchUsersTimer?.cancel();
    _userLocationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
  
  // 4.2.4: Update online status method
  Future<void> _updateOnlineStatus(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(user.uid)
            .update({
              'isOnline': isOnline,
              'lastOnline': DateTime.now().millisecondsSinceEpoch,
            });
        print("Updated online status to: $isOnline");
      } catch (e) {
        print("Error updating online status: $e");
      }
    }
  }
  
  // 4.2.5: Message listening methods
  void _startListeningForUnreadMessages() {
    _messagesSubscription?.cancel();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Listen to all chats where this user is a member
    _messagesSubscription = FirebaseFirestore.instance
        .collection('chat_messages')
        .where('members', arrayContains: currentUser.uid)
        .snapshots()
        .listen((snapshot) async {
          int totalUnread = 0;
          
          for (var doc in snapshot.docs) {
            try {
              final chatId = doc.id;
              
              // Get unread messages count for this chat
              final messagesQuery = await FirebaseFirestore.instance
                  .collection('chat_messages')
                  .doc(chatId)
                  .collection('messages')
                  .where('senderId', isNotEqualTo: currentUser.uid)
                  .where('isRead', isEqualTo: false)
                  .get();
                  
              totalUnread += messagesQuery.docs.length;
            } catch (e) {
              print("Error checking unread messages: $e");
            }
          }
          
          if (mounted) {
            setState(() {
              _unreadCount = totalUnread;
              _hasUnreadMessages = totalUnread > 0;
            });
          }
        });
  }
  
  // 4.2.6: Stop listening for unread messages
  void _stopListeningForUnreadMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }
  
  // 4.2.7: Force location update
  void _forceLocationUpdate() {
    // Call the JavaScript function to force a location update
    js.context.callMethod('forceUpdateLocation');
    print("Forced location update from Dart");
  }

  // 4.2.8: Stop location updates
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }
  
  // 4.2.9: Start fetching user locations
  void _startFetchingUserLocations() {
    _fetchUsersTimer?.cancel();
    _fetchUsersTimer = null;
    
    // Cancel any existing subscription
    _userLocationsSubscription?.cancel();
    
    // Set up a real-time listener for user location changes - only for online users
    _userLocationsSubscription = FirebaseFirestore.instance
      .collection('user_locations')
      .where('isOnline', isEqualTo: true) // Only get online users
      .snapshots()
      .listen((snapshot) {
        final Map<String, Map<String, dynamic>> users = {};
        
        print("Got ${snapshot.docs.length} user location documents (real-time)");
        for (var doc in snapshot.docs) {
          try {
            final String uid = doc.id;
            
            // Skip current user
            if (uid == _currentUserId) continue;
            
            final Map<String, dynamic> data = doc.data();
            
            // Only include users with valid location data
            if (data.containsKey('longitude') && data.containsKey('latitude')) {
              // Calculate distance to filter users within radius
              if (_currentUserId != null && data.containsKey('longitude') && data.containsKey('latitude')) {
                // Find current user document without using firstWhere
                DocumentSnapshot? currentUserDoc = null;
                for (var d in snapshot.docs) {
                  if (d.id == _currentUserId) {
                    currentUserDoc = d;
                    break;
                  }
                }
                
                if (currentUserDoc == null) {
                  continue; // Skip to next user if we can't find current user doc
                }
                
                // Cast the result to Map<String, dynamic>
                final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
                        
                if (currentUserData != null && 
                    currentUserData.containsKey('longitude') && 
                    currentUserData.containsKey('latitude')) {
                  
                  // Calculate distance between current user and this user
                  final distance = _calculateDistance(
                    currentUserData['latitude'], 
                    currentUserData['longitude'],
                    data['latitude'], 
                    data['longitude']
                  );
                          
                  // Only include user if within the visibility radius (in miles)
                  if (distance <= _visibilityRadius) {
                    users[uid] = {
                      'longitude': data['longitude'],
                      'latitude': data['latitude'],
                      'photoURL': data['photoURL'] ?? 'https://via.placeholder.com/40',
                      'displayName': data['displayName'] ?? 'User',
                      'lastUpdated': data['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
                      'distance': distance.toStringAsFixed(1), // Add distance for display
                      // Include other profile data if available
                      if (data.containsKey('age')) 'age': data['age'],
                      if (data.containsKey('height')) 'height': data['height'],
                      if (data.containsKey('weight')) 'weight': data['weight'],
                      if (data.containsKey('bodyType')) 'bodyType': data['bodyType'],
                      if (data.containsKey('sexuality')) 'sexuality': data['sexuality'],
                    };
                  }
                }
              }
            }
          } catch (e) {
            print("Error processing document ${doc.id}: $e");
          }
        }
        
        // Store users data for access in profile dialog
        _usersData = users;
        
        // Update markers via JavaScript
        js.context.callMethod('updateOtherUsersMarkers', [js.JsObject.jsify(users)]);
        print("Updated markers with ${users.length} users (real-time)");
      }, onError: (error) {
        print("Error in Firestore listener: $error");
        // Fall back to periodic updates if the listener fails
        _startPeriodicFetching();
      });
  }

  // 4.2.10: Calculate distance between coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 3958.8; // Earth radius in miles
    
    // Convert to radians
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    return earthRadius * c; // Distance in miles
  }
  
  // 4.2.11: Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // 4.2.12: Start periodic fetching (fallback)
  void _startPeriodicFetching() {
    _fetchUsersTimer?.cancel();
    // Fetch locations immediately
    _fetchUserLocations();
    // Then start periodic fetching
    _fetchUsersTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchUserLocations();
    });
  }

  // 4.2.13: Stop fetching user locations
  void _stopFetchingUserLocations() {
    _fetchUsersTimer?.cancel();
    _fetchUsersTimer = null;
    
    // Cancel the Firestore subscription
    _userLocationsSubscription?.cancel();
    _userLocationsSubscription = null;
    
    // Clear markers
    js.context.callMethod('updateOtherUsersMarkers', [js.JsObject.jsify({})]);
  }

  // 4.2.14: Update user location
  Future<void> _updateUserLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print("Current user exists: ${user.uid}");
        
        // Try to get location from JavaScript global variable
        final dynamic userLocationJS = js.context['userLocation'];
        print("Raw userLocation from JS: $userLocationJS");
        
        if (userLocationJS != null) {
          List<dynamic> location;
          
          // Handle different potential formats
          if (userLocationJS is List) {
            location = userLocationJS;
          } else {
            // Try to parse or convert if it's not a list
            print("Location is not a list, trying to convert");
            try {
              location = List<dynamic>.from(userLocationJS as List);
            } catch (e) {
              print("Failed to convert location: $e");
              // Force a location update and skip this time
              _forceLocationUpdate();
              return;
            }
          }
          
          if (location.length >= 2) {
            final longitude = location[0] as double;
            final latitude = location[1] as double;
            
            print("Saving location: [$longitude, $latitude] for user ${user.uid}");
            
            // Document data structure with online status
            final Map<String, dynamic> docData = {
              'longitude': longitude,
              'latitude': latitude,
              'photoURL': user.photoURL ?? 'https://via.placeholder.com/40',
              'displayName': user.displayName ?? 'User',
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
              'isOnline': true,
              'lastOnline': DateTime.now().millisecondsSinceEpoch,
            };
            
            // Method 1: Use the Firestore SDK
            try {
              await FirebaseFirestore.instance
                  .collection('user_locations')
                  .doc(user.uid)
                  .set(docData);
              print("Successfully updated location with SDK for user: ${user.uid}");
            } catch (e) {
              print("Error with SDK write, trying REST API: $e");
              
              // Method 2: Use REST API as fallback
              try {
                final token = await user.getIdToken();
                final url = 'https://firestore.googleapis.com/v1/projects/mapbox-in-javascript/databases/(default)/documents/user_locations/${user.uid}';
                
                // Convert the document data to Firestore format
                final firestoreData = {
                  'fields': {
                    'longitude': {'doubleValue': longitude},
                    'latitude': {'doubleValue': latitude},
                    'photoURL': {'stringValue': user.photoURL ?? 'https://via.placeholder.com/40'},
                    'displayName': {'stringValue': user.displayName ?? 'User'},
                    'lastUpdated': {'integerValue': DateTime.now().millisecondsSinceEpoch.toString()},
                    'isOnline': {'booleanValue': true},
                    'lastOnline': {'integerValue': DateTime.now().millisecondsSinceEpoch.toString()},
                  }
                };
                
                await HttpRequest.request(
                  url,
                  method: 'PATCH',
                  sendData: json.encode(firestoreData),
                  requestHeaders: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                );
                
                print("Successfully updated location with REST API for user: ${user.uid}");
              } catch (restError) {
                print("Error with REST API write: $restError");
              }
            }
          } else {
            print("Location list doesn't have enough elements: $location");
            _forceLocationUpdate();
          }
        } else {
          print("User location from JS is null - forcing update");
          _forceLocationUpdate();
        }
      } else {
        print("No authenticated user");
      }
    } catch (e) {
      print("Error in _updateUserLocation: $e");
    }
  }

  // 4.2.15: Fetch user locations
  Future<void> _fetchUserLocations() async {
    if (!_isUserLoggedIn || _currentUserId == null) return;
    
    try {
      print("Fetching user locations from Firestore");
      
      // Try method 1: Use Firestore SDK
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('user_locations')
            .where('isOnline', isEqualTo: true) // Only fetch online users
            .get();

        final Map<String, Map<String, dynamic>> users = {};
        
        print("Got ${snapshot.docs.length} user location documents");
        
        for (var doc in snapshot.docs) {
          try {
            final String uid = doc.id;
            
            // Skip current user
            if (uid == _currentUserId) continue;
            
            final Map<String, dynamic> data = doc.data();
            
            // Only include users with valid location data
            if (data.containsKey('longitude') && data.containsKey('latitude')) {
              // Get current user's location for distance calculation
              final currentUserDoc = await FirebaseFirestore.instance
                  .collection('user_locations')
                  .doc(_currentUserId)
                  .get();
                  
              if (currentUserDoc.exists) {
                final currentUserData = currentUserDoc.data();
                if (currentUserData != null && 
                    currentUserData.containsKey('longitude') && 
                    currentUserData.containsKey('latitude')) {
                  
                  // Calculate distance
                  final distance = _calculateDistance(
                    currentUserData['latitude'], 
                    currentUserData['longitude'],
                    data['latitude'], 
                    data['longitude']
                  );
                  
                  // Only include if within radius
                  if (distance <= _visibilityRadius) {
                    users[uid] = {
                      'longitude': data['longitude'],
                      'latitude': data['latitude'],
                      'photoURL': data['photoURL'] ?? 'https://via.placeholder.com/40',
                      'displayName': data['displayName'] ?? 'User',
                      'lastUpdated': data['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
                      'distance': distance.toStringAsFixed(1),
                      if (data.containsKey('age')) 'age': data['age'],
                      if (data.containsKey('height')) 'height': data['height'],
                      if (data.containsKey('weight')) 'weight': data['weight'],
                      if (data.containsKey('bodyType')) 'bodyType': data['bodyType'],
                      if (data.containsKey('sexuality')) 'sexuality': data['sexuality'],
                    };
                  }
                }
              }
            }
          } catch (e) {
            print("Error processing document ${doc.id}: $e");
          }
        }
        
        // Update markers via JavaScript
        js.context.callMethod('updateOtherUsersMarkers', [js.JsObject.jsify(users)]);
        print("Updated markers with ${users.length} users");
        
        // If we found other users, we're done
        if (users.isNotEmpty) return;
      } catch (e) {
        print("Error using Firestore SDK, trying REST API: $e");
      }
      
      // Method 2: Use a direct HTTP call to Firestore REST API
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        
        // Get an auth token
        final token = await user.getIdToken();
        
        // Build the URL for Firestore REST API with filter for online users
        final url = 'https://firestore.googleapis.com/v1/projects/mapbox-in-javascript/databases/(default)/documents/user_locations?pageSize=100';
        
        // Make the HTTP request
        final response = await HttpRequest.request(
          url,
          requestHeaders: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        
        // Parse the response
        final data = json.decode(response.responseText ?? '{}');
        if (data != null && data.containsKey('documents')) {
          final List<dynamic> documents = data['documents'];
          print("Got ${documents.length} user location documents from REST API");
          
          final Map<String, Map<String, dynamic>> users = {};
          
          // Get current user's location for distance calculation
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('user_locations')
              .doc(_currentUserId)
              .get();
              
          double? currentUserLat, currentUserLng;
          if (currentUserDoc.exists) {
            final currentUserData = currentUserDoc.data();
            if (currentUserData != null) {
              currentUserLat = currentUserData['latitude'];
              currentUserLng = currentUserData['longitude'];
            }
          }
          
          for (var doc in documents) {
            try {
              final String path = doc['name'];
              final String uid = path.split('/').last;
              
              // Skip current user
              if (uid == _currentUserId) continue;
              
              final fields = doc['fields'];
              
              // Check if user is online
              final isOnline = fields['isOnline']?['booleanValue'] == true;
              if (!isOnline) continue;
              
              // Only include users with valid location data
              if (fields['longitude'] != null && fields['latitude'] != null) {
                final double lat = double.parse(fields['latitude']['doubleValue'].toString());
                final double lng = double.parse(fields['longitude']['doubleValue'].toString());
                
                // Calculate distance if we have current user's location
                if (currentUserLat != null && currentUserLng != null) {
                  final distance = _calculateDistance(
                    currentUserLat, 
                    currentUserLng,
                    lat, 
                    lng
                  );
                  
                  // Only include if within radius
                  if (distance <= _visibilityRadius) {
                    users[uid] = {
                      'longitude': lng,
                      'latitude': lat,
                      'photoURL': fields['photoURL']?['stringValue'] ?? 'https://via.placeholder.com/40',
                      'displayName': fields['displayName']?['stringValue'] ?? 'User',
                      'lastUpdated': int.parse(fields['lastUpdated']?['integerValue'] ?? '0'),
                      'distance': distance.toStringAsFixed(1),
                    };
                  }
                }
              }
            } catch (e) {
              print("Error processing REST document: $e");
            }
          }
          
          // Update markers via JavaScript
          js.context.callMethod('updateOtherUsersMarkers', [js.JsObject.jsify(users)]);
          print("Updated markers with ${users.length} users from REST API");
        } else {
          print("No documents found in REST response: $data");
        }
      } catch (e) {
        print("Error with REST API fetch: $e");
      }
    } catch (e) {
      print("Error in _fetchUserLocations: $e");
    }
  }

  //==============================================================================
  // SECTION 5: MENU HANDLING
  //==============================================================================

  // 5.1: Handle menu selection
  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'my_profile':
        if (_currentUserId != null) {
          // Close all popups before showing profile
          js.context.callMethod('closeAllPopups');
          _showUserProfile(_currentUserId!);
        }
        break;
      case 'account_settings':
        _showAccountSettings(context);
        break;
      case 'reset_password':
        _showResetPasswordDialog(context);
        break;
      case 'upgrade':
        _showUpgradeOptions(context);
        break;
      case 'refresh_console':
        _forceLocationUpdate();
        _updateUserLocation();
        _fetchUserLocations();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Console refreshed')),
          );
        }
        break;
      case 'sign_in':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) {
            final screenSize = MediaQuery.of(context).size;
            final isSmallScreen = screenSize.width < 600;
            
            return Stack(
              children: [
                Positioned(
                  // Position from top
                  top: isSmallScreen ? 10 : kToolbarHeight,
                  // On mobile, center horizontally
                  right: isSmallScreen ? null : 0,
                  left: isSmallScreen ? 0 : null,
                  // Center horizontally on mobile
                  width: isSmallScreen
                      ? screenSize.width * 0.9  // 90% of screen width on mobile
                      : screenSize.width * 0.4, // 40% on desktop
                  // Center dialog on small screens
                  child: Center(
                    child: Material(
                      elevation: 8.0,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        // Add this class for JavaScript event handler
                        key: ValueKey<String>('flutter-dialog'),
                        child: const SignInDialog(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
        break;
      case 'sign_up':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) {
            final screenSize = MediaQuery.of(context).size;
            final isSmallScreen = screenSize.width < 600;
            
            return Stack(
              children: [
                Positioned(
                  // Position from top
                  top: isSmallScreen ? 10 : kToolbarHeight,
                  // On mobile, center horizontally
                  right: isSmallScreen ? null : 0,
                  left: isSmallScreen ? 0 : null,
                  // Center horizontally on mobile
                  width: isSmallScreen
                      ? screenSize.width * 0.9  // 90% of screen width on mobile
                      : screenSize.width * 0.4, // 40% on desktop
                  // Center dialog on small screens
                  child: Center(
                    child: Material(
                      elevation: 8.0,
                      borderRadius: BorderRadius.circular(20),
                      child: const SignUpDialog(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
        break;      
      case 'change_profile_picture':
        _uploadProfilePicture(context, "main");
        break;
      case 'manage_groups':
        _showGroupsDialog(context);
        break;
      case 'visibility_settings':
        _showVisibilitySettingsDialog(context);
        break;
      case 'sign_out':
        FirebaseAuth.instance.signOut();
        break;
    }
  }

  //==============================================================================
  // SECTION 6: DIALOG MANAGEMENT
  //==============================================================================

  // 6.1: Account settings dialog
  void _showAccountSettings(BuildContext context) {
    js.context.callMethod('closeAllPopups');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();
    final confirmDeleteController = TextEditingController();
    
    String unitSystem = 'metric';
    
    // Fetch user profile for unit system
    FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get()
        .then((doc) {
      if (doc.exists) {
        final userData = UserProfileData.fromMap(doc.data());
        unitSystem = userData.unitSystem ?? 'metric';
        
        // Update state if still mounted
        if (context.mounted) {
          setState(() {});
        }
      }
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account section header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Text(
                  'Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              
              // Email field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: false, // Email can't be changed directly
                ),
              ),
              
              // Password field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (passwordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password must be at least 6 characters')),
                          );
                          return;
                        }
                        
                        try {
                          await user.updatePassword(passwordController.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password updated successfully')),
                            );
                            passwordController.clear();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating password: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Update Password'),
                    ),
                  ],
                ),
              ),
              
              // Settings section header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue,
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              
              // Unit system setting
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Measurement Units:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Metric (cm/kg)'),
                                value: 'metric',
                                groupValue: unitSystem,
                                onChanged: (value) {
                                  setState(() {
                                    unitSystem = value!;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Imperial (ft/lbs)'),
                                value: 'imperial',
                                groupValue: unitSystem,
                                onChanged: (value) {
                                  setState(() {
                                    unitSystem = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // Save unit system to user's profile
                          await FirebaseFirestore.instance
                              .collection('user_profiles')
                              .doc(user.uid)
                              .set({
                                'unitSystem': unitSystem,
                              }, SetOptions(merge: true));
                              
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Settings saved')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving settings: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
              
              // Delete account section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red,
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This action cannot be undone. To confirm, please enter your email address:',
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmDeleteController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Email',
                        prefixIcon: Icon(Icons.warning, color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (confirmDeleteController.text != user.email) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email does not match')),
                          );
                          return;
                        }
                        
                        // Confirm with a dialog
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Account Deletion'),
                            content: const Text(
                              'Are you absolutely sure you want to delete your account? This action CANNOT be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ) ?? false;
                        
                        if (shouldDelete && context.mounted) {
                          try {
                            // Delete user data from Firestore
                            await Future.wait([
                              FirebaseFirestore.instance.collection('users').doc(user.uid).delete(),
                              FirebaseFirestore.instance.collection('user_locations').doc(user.uid).delete(),
                              FirebaseFirestore.instance.collection('user_profiles').doc(user.uid).delete(),
                            ]);
                            
                            // Delete user authentication account
                            await user.delete();
                            
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close settings dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account deleted successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting account: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Delete My Account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // 6.2: Reset password dialog
  void _showResetPasswordDialog(BuildContext context) {
    js.context.callMethod('closeAllPopups');
    
    final emailController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      emailController.text = currentUser.email ?? '';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email address. We\'ll send you a link to reset your password.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }
              
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset link sent! Check your email')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  // 6.3: Upgrade options dialog
  void _showUpgradeOptions(BuildContext context) {
    js.context.callMethod('closeAllPopups');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Premium features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Create unlimited groups'),
            const Text('• Join unlimited groups'),
            const Text('• Advanced profile features'),
            const Text('• Priority visibility on the map'),
            const SizedBox(height: 16),
            const Text('Coming soon!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription feature coming soon!')),
              );
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  // 6.4: Groups dialog
  void _showGroupsDialog(BuildContext context) {
    js.context.callMethod('closeAllPopups');
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            top: isSmallScreen ? 10 : kToolbarHeight,
            // Center on mobile, right-aligned on desktop
            right: isSmallScreen ? null : 10,
            left: isSmallScreen ? 0 : null,
            // Use almost full width on small screens
            width: isSmallScreen
                ? screenSize.width * 0.95  // 95% width on mobile
                : 400,                     // Fixed width on desktop
            // Use percentage of screen height
            height: isSmallScreen
                ? screenSize.height * 0.9  // 90% of screen height on mobile
                : MediaQuery.of(context).size.height * 0.7,  // 70% on desktop
            // Center dialog on small screens
            child: Center(
              child: Material(
                elevation: 8.0,
                borderRadius: BorderRadius.circular(20),
                child: GroupsDialog(
                  onCreateGroup: () => _showCreateGroupDialog(context),
                  onSubscribe: () => _showSubscriptionDialog(context),
                  visibilityRadius: _visibilityRadius,
                  onRadiusChanged: (value) {
                    setState(() {
                      _visibilityRadius = value;
                    });
                    // Re-fetch users when radius changes
                    _startFetchingUserLocations();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6.5: Create group dialog
  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a group name')),
                );
                return;
              }
              
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) return;
              
              // Check if user already created a group
              final userGroups = await FirebaseFirestore.instance
                  .collection('groups')
                  .where('creatorId', isEqualTo: currentUser.uid)
                  .get();
                  
              if (userGroups.docs.length >= 1) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _showSubscriptionDialog(context, 
                      message: 'You\'ve reached your limit of free groups.\nUpgrade to create more!');
                }
                return;
              }
              
              try {
                // Get current location for the group
                final locationDoc = await FirebaseFirestore.instance
                    .collection('user_locations')
                    .doc(currentUser.uid)
                    .get();
                
                double? latitude, longitude;
                if (locationDoc.exists) {
                  final data = locationDoc.data();
                  if (data != null) {
                    latitude = data['latitude'];
                    longitude = data['longitude'];
                  }
                }
                
                // Create the group
                await FirebaseFirestore.instance.collection('groups').add({
                  'name': name,
                  'description': description,
                  'creatorId': currentUser.uid,
                  'creatorName': currentUser.displayName,
                  'createdAt': FieldValue.serverTimestamp(),
                  'members': [currentUser.uid],
                  'memberCount': 1,
                  'latitude': latitude,
                  'longitude': longitude,
                });
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group created successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating group: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // 6.6: Subscription dialog
  void _showSubscriptionDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null)
              Text(
                message,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            if (message != null)
              const SizedBox(height: 16),
            const Text(
              'Premium features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Create unlimited groups'),
            const Text('• Join unlimited groups'),
            const Text('• Advanced profile features'),
            const Text('• Priority visibility on the map'),
            const SizedBox(height: 16),
            const Text('Coming soon!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription feature coming soon!')),
              );
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  // 6.7: Visibility settings dialog
  void _showVisibilitySettingsDialog(BuildContext context) {
    js.context.callMethod('closeAllPopups');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visibility Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Control who can see you on the map'),
            const SizedBox(height: 16),
            Text('Visibility radius: ${_visibilityRadius.toStringAsFixed(1)} miles'),
            Slider(
              value: _visibilityRadius,
              min: 1.0,
              max: 50.0,
              divisions: 49,
              label: _visibilityRadius.toStringAsFixed(1) + ' miles',
              onChanged: (value) {
                setState(() {
                  _visibilityRadius = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Re-fetch users when radius changes
              _startFetchingUserLocations();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // 6.8: User profile dialog
  void _showUserProfile(String userId) {
    // Close any open popups before showing profile
    js.context.callMethod('closeAllPopups');
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            top: isSmallScreen ? 10 : kToolbarHeight,
            // Center on mobile, right-aligned on desktop
            right: isSmallScreen ? null : 0,
            left: isSmallScreen ? 0 : null,
            // Use almost full width on small screens
            width: isSmallScreen
                ? screenSize.width * 0.95  // 95% width on mobile
                : 600,                    // Fixed width on desktop
            // Adapt height to screen size
            height: isSmallScreen
                ? screenSize.height * 0.9  // 90% height on mobile
                : MediaQuery.of(context).size.height * 0.8,  // 80% on desktop
            // Center dialog on small screens
            child: Center(
              child: Material(
                elevation: 8.0,
                borderRadius: BorderRadius.circular(20),
                child: NotificationListener<ScrollNotification>(
                  // This prevents scroll events from propagating to the map
                  onNotification: (notification) {
                    return true; // Prevents the notification from propagating
                  },
                  child: UserProfileDialog(
                    userId: userId,
                    onMessageTap: () {
                      // Close profile and start chat
                      Navigator.of(context).pop();
                      _startChatWithUser(userId);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      // Re-enable map interactions when dialog is closed
      js.context.callMethod('enableMapInteractions');
    });
  }

  // 6.9: Messages dialog
  void _showMessagesDialog(BuildContext context) {
    // Close any open popups first
    js.context.callMethod('closeAllPopups');
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            // For mobile, take more screen space
            bottom: isSmallScreen ? 10 : 20,
            right: isSmallScreen ? 10 : 20,
            // Set width based on screen size
            width: isSmallScreen 
                ? screenSize.width * 0.95  // 95% of screen width on mobile
                : 400,                     // Fixed width on larger screens
            // Set height based on screen size
            height: isSmallScreen 
                ? screenSize.height * 0.7  // 70% of screen height on mobile
                : 500,                     // Fixed height on larger screens
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(20),
              child: NotificationListener<ScrollNotification>(
                // This prevents scroll events from propagating to the map
                onNotification: (notification) {
                  return true; // Prevent scroll notifications from propagating
                },
                child: MessagesDialog(
                  onChatSelected: (userId, name, photo) {
                    // Close messages dialog and open chat
                    Navigator.of(context).pop();
                    _startChatWithUser(userId, name: name, photo: photo);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6.10: Start chat with user
  void _startChatWithUser(String userId, {String? name, String? photo}) {
    // Close any open popups first
    js.context.callMethod('closeAllPopups');
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Create a chat document if it doesn't exist
    final chatMembers = [currentUser.uid, userId];
    chatMembers.sort();
    final chatId = chatMembers.join('_');
    
    FirebaseFirestore.instance
        .collection('chat_messages')
        .doc(chatId)
        .set({
          'members': chatMembers,
          'created': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    
    // Get the target user's display name
    final targetUserName = name ?? _usersData[userId]?['displayName'] ?? 'User';
    final targetUserPhoto = photo ?? _usersData[userId]?['photoURL'] ?? 'https://via.placeholder.com/40';
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            // Position at bottom with small margin
            bottom: isSmallScreen ? 10 : 20,
            // Center on mobile, right-aligned on desktop
            right: isSmallScreen ? null : 20,
            left: isSmallScreen ? 0 : null,
            // Width based on screen size
            width: isSmallScreen
                ? screenSize.width * 0.95  // 95% width on mobile
                : 400,                     // Fixed width on desktop
            // Height based on screen size
            height: isSmallScreen
                ? screenSize.height * 0.8  // 80% height on mobile
                : 500,                     // Fixed height on desktop
            // Center on mobile
            child: Center(
              child: Material(
                elevation: 8.0,
                borderRadius: BorderRadius.circular(20),
                child: NotificationListener<ScrollNotification>(
                  // This prevents scroll events from propagating to the map
                  onNotification: (notification) {
                    return true; // Prevent scroll notifications from propagating
                  },
                  child: ChatDialog(
                    targetUserId: userId,
                    targetUserName: targetUserName,
                    targetUserPhoto: targetUserPhoto,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6.11: Upload profile picture
  void _uploadProfilePicture(BuildContext context, String slot) {
    final input = FileUploadInputElement()..accept = 'image/*';
    input.onChange.listen((e) async {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            // Show loading indicator
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uploading picture...')),
              );
            }
            
            final reader = FileReader();
            final completer = Completer<Uint8List>();
            reader.onLoadEnd.listen((e) {
              if (reader.readyState == FileReader.DONE) {
                completer.complete(reader.result as Uint8List);
              }
            });
            reader.readAsArrayBuffer(file);
            final data = await completer.future;

            // Different path based on the slot
            final filePath = slot == "main" 
                ? 'profile_pictures/${user.uid}/profile.jpg'
                : 'profile_pictures/${user.uid}/additional_${slot}.jpg';
            
            final storageRef = FirebaseStorage.instance.ref().child(filePath);
            final uploadTask = storageRef.putData(data);
            await uploadTask;
            final downloadUrl = await storageRef.getDownloadURL();
            
            if (slot == "main") {
              // For main profile picture, update auth profile
              await user.updateProfile(photoURL: downloadUrl);
              
              // Also update it in the user location document
              await FirebaseFirestore.instance
                  .collection('user_locations')
                  .doc(user.uid)
                  .update({
                    'photoURL': downloadUrl,
                  });
              
              // Update it in JavaScript - this ensures instant UI update
              js.context.callMethod('setProfilePicture', [downloadUrl]);
              
              // Force UI update by triggering setState
              setState(() {});
            } else {
              // For additional pictures, store in user_profiles collection
              // First, get the current document to check if it exists
              final docSnapshot = await FirebaseFirestore.instance
                  .collection('user_profiles')
                  .doc(user.uid)
                  .get();
                  
              if (docSnapshot.exists) {
                // Document exists, update the specific field
                await FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(user.uid)
                    .update({
                      'additional_pictures.$slot': downloadUrl,
                    });
              } else {
                // Document doesn't exist, create it with the initial data
                await FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(user.uid)
                    .set({
                      'additional_pictures': {
                        slot: downloadUrl,
                      }
                    });
              }
              
              // Force refresh of profile dialog if it's open
              if (context.mounted) {
                Navigator.of(context).pop();
                _showUserProfile(user.uid);
              }
            }
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Picture updated successfully')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update picture: $e')),
              );
            }
          }
        }
      }
    });
    input.click();
  }

  // 4.2.16: Build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0D1B2A), // Very dark blue, almost black
        title: const Text(
          "Rimmies",
          style: TextStyle(
            fontSize: 24, // Increased from default
            fontWeight: FontWeight.bold,
            color: Colors.white, // Add this line to make the text white
          ),
        ),
        centerTitle: true,  // Add this line
        toolbarHeight: 70, // Increased from default ~56
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              
              final user = snapshot.data;
              final photoURL = user?.photoURL;
              
              // Set profile picture in JavaScript
              if (photoURL != null) {
                js.context.callMethod('setProfilePicture', [photoURL]);
              }
              
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuSelection(context, value),
                  icon: CircleAvatar(
                    radius: 24, // Increased from 20
                    backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                    child: photoURL == null ? const Icon(Icons.account_circle, size: 48) : null,
                  ),
                  tooltip: "Show menu",
                  // Position the menu directly below the button
                  offset: const Offset(0, 0),
                  constraints: const BoxConstraints(
                    minWidth: 320, // Increased from 280
                    maxWidth: 320, // Increased from 280
                  ),
                  itemBuilder: (BuildContext context) {
                    if (user != null) {
                      return <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18, // Increased from 15
                                backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                                child: photoURL == null ? const Icon(Icons.account_circle, size: 36) : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                user.displayName ?? 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16, // Increased font size
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'my_profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("My Profile", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'change_profile_picture',
                          child: Row(
                            children: [
                              Icon(Icons.image, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Change Profile Picture", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'reset_password',
                          child: Row(
                            children: [
                              Icon(Icons.lock_reset, size: 24),
                              SizedBox(width: 10),
                              Text("Reset Password", style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'account_settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Account Settings", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'visibility_settings',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 24),
                              SizedBox(width: 10),
                              Text("Visibility Settings", style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'manage_groups',
                          child: Row(
                            children: [
                              Icon(Icons.group, size: 24),
                              SizedBox(width: 10),
                              Text("Manage Groups", style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'upgrade',
                          child: Row(
                            children: [
                              Icon(Icons.upgrade, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Upgrade", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'refresh_console',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Refresh Console", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'sign_out',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Sign Out", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                      ];
                    } else {
                      return <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'sign_in',
                          child: Row(
                            children: [
                              Icon(Icons.login, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Sign In", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'sign_up',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 24), // Increased size
                              SizedBox(width: 10),
                              Text("Sign Up", style: TextStyle(fontSize: 16)), // Increased font size
                            ],
                          ),
                        ),
                      ];
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 10), // Add some padding to the right
        ],
      ),
      body: Stack(
        children: [
          const HtmlElementView(viewType: 'mapbox-gl-element'),
          
          // Add extra buttons in a row at the bottom
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Groups button
                FloatingActionButton(
                  onPressed: () => _showGroupsDialog(context),
                  backgroundColor: Colors.purple,
                  elevation: 4,
                  mini: true,
                  heroTag: 'groups',
                  child: const Icon(Icons.group, size: 24),
                ),
                const SizedBox(height: 10),
                
                // Visibility settings button
                FloatingActionButton(
                  onPressed: () => _showVisibilitySettingsDialog(context),
                  backgroundColor: Colors.green,
                  elevation: 4,
                  mini: true,
                  heroTag: 'visibility',
                  child: const Icon(Icons.visibility, size: 24),
                ),
                const SizedBox(height: 10),
                
                // Messages button with notification badge
// Messages button with notification badge
Stack(
  clipBehavior: Clip.none,
  children: [
    FloatingActionButton(
      onPressed: () => _showMessagesDialog(context),
      backgroundColor: Colors.purple,  // Changed to match other buttons
      elevation: 4,
      mini: true,  // Made mini to match other buttons
      heroTag: 'messages',
      child: const Icon(Icons.message, size: 24),  // Reduced size to match others
    ),
    if (_hasUnreadMessages)
      Positioned(
        top: -5,
        right: -5,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          constraints: const BoxConstraints(
            minWidth: 22,
            minHeight: 22,
          ),
          child: Text(
            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
  ],
),              ],
            ),
          ),
        ],
      ),
    );
  }
}

//==============================================================================
// SECTION 7: GROUPS DIALOG
//==============================================================================

// 7.1: Groups Dialog Widget
class GroupsDialog extends StatefulWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onSubscribe;
  final double visibilityRadius;
  final ValueChanged<double> onRadiusChanged;
  
  const GroupsDialog({
    super.key,
    required this.onCreateGroup,
    required this.onSubscribe,
    required this.visibilityRadius,
    required this.onRadiusChanged,
  });

  // 7.1.1: Create state method
  @override
  _GroupsDialogState createState() => _GroupsDialogState();
}

// 7.2: Groups Dialog State
class _GroupsDialogState extends State<GroupsDialog> {
  // 7.2.1: State variables
  bool isLoading = true;
  List<Map<String, dynamic>> nearbyGroups = [];
  List<Map<String, dynamic>> myGroups = [];
  
  // 7.2.2: Init state method
  @override
  void initState() {
    super.initState();
    _loadGroups();
  }
  
  // 7.2.3: Load groups method
  Future<void> _loadGroups() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
          nearbyGroups = [];
          myGroups = [];
        });
        return;
      }
      
      // Get current user's location
      final userDoc = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(currentUser.uid)
          .get();
          
      double? userLat, userLng;
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          userLat = userData['latitude'];
          userLng = userData['longitude'];
        }
      }
      
      // Load all groups from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .get();
          
      List<Map<String, dynamic>> nearby = [];
      List<Map<String, dynamic>> mine = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Map<String, dynamic> group = {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed group',
          'description': data['description'] ?? '',
          'memberCount': data['memberCount'] ?? 0,
          'creatorId': data['creatorId'],
          'creatorName': data['creatorName'],
          'isCreator': data['creatorId'] == currentUser.uid,
          'isMember': (data['members'] as List<dynamic>?)?.contains(currentUser.uid) ?? false,
        };
        
        // Check if user is member/creator
        if (group['isCreator'] || group['isMember']) {
          mine.add(group);
        }
        
        // Check if group is within radius
        if (userLat != null && userLng != null && 
            data['latitude'] != null && data['longitude'] != null) {
          final distance = _calculateDistance(
            userLat, userLng, 
            data['latitude'], data['longitude']
          );
          
          if (distance <= widget.visibilityRadius) {
            group['distance'] = distance;
            nearby.add(group);
          }
        }
      }
      
      // Sort nearby groups by distance
      nearby.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      setState(() {
        nearbyGroups = nearby;
        myGroups = mine;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading groups: $e");
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // 7.2.4: Calculate distance method
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 3958.8; // Earth radius in miles
    
    // Convert to radians
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    return earthRadius * c; // Distance in miles
  }
  
  // 7.2.5: Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
  
  // 7.2.6: Build method
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // This prevents scroll events from propagating to the map
      onNotification: (notification) {
       // Prevent scroll notifications from propagating to parent
        return true;
      },
      // This prevents gesture events from propagating to the map
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    "Groups",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Visibility Settings
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visibility radius: ${widget.visibilityRadius.toStringAsFixed(1)} miles'),
                  Slider(
                    value: widget.visibilityRadius,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    label: widget.visibilityRadius.toStringAsFixed(1) + ' miles',
                    activeColor: Colors.purple,
                    onChanged: widget.onRadiusChanged,
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Group'),
                      onPressed: widget.onCreateGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.star),
                      label: const Text('Upgrade'),
                      onPressed: widget.onSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Tabs for My Groups and Nearby Groups
            DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                      ),
                      child: const TabBar(
                        tabs: [
                          Tab(text: 'My Groups'),
                          Tab(text: 'Nearby Groups'),
                        ],
                        labelColor: Colors.purple,
                        indicatorColor: Colors.purple,
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // My Groups tab
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : myGroups.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.group, size: 64, color: Colors.grey[400]),
                                            const SizedBox(height: 16),
                                            const Text(
                                              "You haven't joined any groups yet",
                                              style: TextStyle(fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: myGroups.length,
                                      itemBuilder: (context, index) {
                                        final group = myGroups[index];
                                        return ListTile(
                                          title: Text(
                                            group['name'],
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(group['description']),
                                          leading: CircleAvatar(
                                            child: Icon(
                                              group['isCreator'] ? Icons.star : Icons.group,
                                              color: Colors.white,
                                            ),
                                            backgroundColor: group['isCreator'] ? Colors.amber : Colors.purple,
                                          ),
                                          trailing: Text("${group['memberCount']} members"),
                                          onTap: () {
                                            // Show group details
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Group details coming soon!')),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    
                          // Nearby Groups tab
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : nearbyGroups.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                                            const SizedBox(height: 16),
                                            Text(
                                              "No groups found within ${widget.visibilityRadius.toStringAsFixed(1)} miles",
                                              style: const TextStyle(fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: nearbyGroups.length,
                                      itemBuilder: (context, index) {
                                        final group = nearbyGroups[index];
                                        final bool isMember = group['isMember'] ?? false;
                                        
                                        return ListTile(
                                          title: Text(
                                            group['name'],
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            "${group['description']}\n${group['distance'].toStringAsFixed(1)} miles away"
                                          ),
                                          isThreeLine: true,
                                          leading: CircleAvatar(
                                            child: Icon(
                                              group['isCreator'] ? Icons.star : Icons.group,
                                              color: Colors.white,
                                            ),
                                            backgroundColor: isMember ? Colors.green : Colors.grey,
                                          ),
                                          trailing: isMember 
                                              ? Icon(Icons.check_circle, color: Colors.green)
                                              : ElevatedButton(
                                                  onPressed: () {
                                                    // Join group
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Joining groups coming soon!')),
                                                    );
                                                  },
                                                  child: const Text('Join'),
                                                ),
                                          onTap: () {
                                            // Show group details
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Group details coming soon!')),
                                            );
                                          },
                                        );
                                      },
                                    ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//==============================================================================
// SECTION 8: USER PROFILE DIALOG
//==============================================================================

// 8.1: User Profile Dialog Widget
class UserProfileDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onMessageTap;
  
  const UserProfileDialog({
    super.key, 
    required this.userId,
    this.onMessageTap,
  });

  // 8.1.1: Create state method
  @override
  _UserProfileDialogState createState() => _UserProfileDialogState();
}

// 8.2: User Profile Dialog State
class _UserProfileDialogState extends State<UserProfileDialog> {
  // 8.2.1: State variables
  Map<String, dynamic>? userData;
  UserProfileData profileData = UserProfileData();
  bool isLoading = true;
  bool isCurrentUser = false;
  bool isEditing = false;
  
  // Form controllers
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final bodyTypeController = TextEditingController();
  final sexualityController = TextEditingController();
  final descriptionController = TextEditingController();
  
  // 8.2.2: Init state method
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  // 8.2.3: Dispose method
  @override
  void dispose() {
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    bodyTypeController.dispose();
    sexualityController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
  
  // 8.2.4: Load user data method
  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Check if this is the current user
      final currentUser = FirebaseAuth.instance.currentUser;
      isCurrentUser = currentUser != null && currentUser.uid == widget.userId;
      
      // Load basic user data
      final userDoc = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(widget.userId)
          .get();
          
      if (userDoc.exists) {
        userData = userDoc.data();
      }
      
      // Load profile data if available
      final profileDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(widget.userId)
          .get();
          
      if (profileDoc.exists) {
        profileData = UserProfileData.fromMap(profileDoc.data());

        
        // Update controllers
        ageController.text = profileData.age?.toString() ?? '';
        heightController.text = profileData.height?.toString() ?? '';
        weightController.text = profileData.weight?.toString() ?? '';
        bodyTypeController.text = profileData.bodyType ?? '';
sexualityController.text = profileData.sexuality ?? '';
        descriptionController.text = profileData.description ?? '';
      }
      
      // Make sure we have additional pictures from profile data
      if (profileData.additionalPictures == null && profileDoc.exists) {
        if (profileDoc.data()!.containsKey('additional_pictures')) {
          profileData.additionalPictures = profileDoc.data()!['additional_pictures'];
        } else {
          profileData.additionalPictures = {};
        }
      } else if (profileData.additionalPictures == null) {
        profileData.additionalPictures = {};
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  // 8.2.5: Upload picture method
  void _uploadPicture(String slot) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != widget.userId) return;
    
    final input = FileUploadInputElement()..accept = 'image/*';
    input.onChange.listen((e) async {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        
        try {
          final reader = FileReader();
          final completer = Completer<Uint8List>();
          reader.onLoadEnd.listen((e) {
            if (reader.readyState == FileReader.DONE) {
              completer.complete(reader.result as Uint8List);
            }
          });
          reader.readAsArrayBuffer(file);
          final data = await completer.future;

          // Upload to the appropriate slot
          final filePath = 'profile_pictures/${currentUser.uid}/additional_$slot.jpg';
          final storageRef = FirebaseStorage.instance.ref().child(filePath);
          final uploadTask = storageRef.putData(data);
          await uploadTask;
          final downloadUrl = await storageRef.getDownloadURL();
          
          // Store in Firestore
          final docSnapshot = await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(currentUser.uid)
              .get();
              
          if (docSnapshot.exists) {
            await FirebaseFirestore.instance
                .collection('user_profiles')
                .doc(currentUser.uid)
                .update({
                  'additional_pictures.$slot': downloadUrl,
                });
          } else {
            await FirebaseFirestore.instance
                .collection('user_profiles')
                .doc(currentUser.uid)
                .set({
                  'additional_pictures': {
                    slot: downloadUrl,
                  }
                });
          }
              
          // Reload data
          await _loadUserData();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Picture uploaded successfully')),
            );
          }
        } catch (e) {
          print("Error uploading additional picture: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload picture: $e')),
            );
          }
        }
      }
    });
    input.click();
  }
  
  // 8.2.6: Save profile changes method
  Future<void> _saveProfileChanges() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != widget.userId) return;
      
      // Update profile data from controllers
      profileData.age = ageController.text.isNotEmpty ? int.tryParse(ageController.text) : null;
      profileData.height = heightController.text.isNotEmpty ? double.tryParse(heightController.text) : null;
      profileData.weight = weightController.text.isNotEmpty ? double.tryParse(weightController.text) : null;
      profileData.bodyType = bodyTypeController.text.isNotEmpty ? bodyTypeController.text : null;
      profileData.sexuality = sexualityController.text.isNotEmpty ? sexualityController.text : null;
      profileData.description = descriptionController.text.isNotEmpty ? descriptionController.text : null;
      
      // Save to Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(currentUser.uid)
          .get();
      
      if (docSnapshot.exists) {
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(currentUser.uid)
            .update(profileData.toMap());
      } else {
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(currentUser.uid)
            .set(profileData.toMap());
      }
      
      // Also update display name in user_locations
      if (userData != null && userData!['displayName'] != profileData.displayName) {
        await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(currentUser.uid)
            .update({
              'displayName': profileData.displayName,
            });
      }
      
      setState(() {
        isEditing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      print("Error saving profile data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 8.2.7: Build method
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return NotificationListener<ScrollNotification>(
      // Prevent scroll events from propagating to the map
      onNotification: (notification) {
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top banner with edit button
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? "Edit Profile" : (userData?['displayName'] ?? 'User'),
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrentUser && !isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 24),
                      tooltip: "Edit Profile",
                      onPressed: () {
                        setState(() {
                          isEditing = true;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Main content - make scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isEditing 
                      ? _buildEditProfileView()
                      : _buildProfileView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 8.2.8: Build profile view
  Widget _buildProfileView() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading user profile...")
          ],
        ),
      );
    }
    
    if (userData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("User not found", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }

    final displayName = userData!['displayName'] ?? 'User';
    final mainPhotoURL = userData!['photoURL'] ?? 'https://via.placeholder.com/150';
    
    // Get additional pictures or placeholder URLs
    final pic1 = profileData.additionalPictures?['1'] ?? 'https://via.placeholder.com/150?text=Add+Photo';
    final pic2 = profileData.additionalPictures?['2'] ?? 'https://via.placeholder.com/150?text=Add+Photo';
    final pic3 = profileData.additionalPictures?['3'] ?? 'https://via.placeholder.com/150?text=Add+Photo';
    
    // Get screen size to determine layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photos section - different layout based on screen size
        isSmallScreen
            // Vertical layout for mobile
            ? Column(
                children: [
                  // Main profile picture centered on mobile
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 180, // Slightly smaller on mobile
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            image: DecorationImage(
                              image: NetworkImage(mainPhotoURL),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (isCurrentUser) const SizedBox(height: 8),
                        if (isCurrentUser)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text("Change Picture"),
                            onPressed: () {
                              Navigator.of(context).pop();
                              final _MapScreenState mapState = 
                                  context.findAncestorStateOfType<_MapScreenState>()!;
                              mapState._uploadProfilePicture(context, "main");
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Additional pictures section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Additional Photos",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Use a wrap for flexible layout
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceEvenly,
                        children: [
                          // Photo slot 1
                          _buildPhotoSlot(pic1, '1'),
                          // Photo slot 2
                          _buildPhotoSlot(pic2, '2'),
                          // Photo slot 3
                          _buildPhotoSlot(pic3, '3'),
                        ],
                      ),
                      if (isCurrentUser) const SizedBox(height: 8),
                      if (isCurrentUser)
                        const Center(
                          child: Text(
                            "Tap on a photo to add or change",
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ],
              )
            // Original horizontal layout for desktop
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main profile picture
                  Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(mainPhotoURL),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (isCurrentUser) const SizedBox(height: 8),
                      if (isCurrentUser)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text("Change Main Picture"),
                          onPressed: () {
                            Navigator.of(context).pop();
                            final _MapScreenState mapState = 
                                context.findAncestorStateOfType<_MapScreenState>()!;
                            mapState._uploadProfilePicture(context, "main");
                          },
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  // Additional pictures
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Additional Photos",
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Photo slot 1
                            _buildPhotoSlot(pic1, '1'),
                            // Photo slot 2
                            _buildPhotoSlot(pic2, '2'),
                            // Photo slot 3
                            _buildPhotoSlot(pic3, '3'),
                          ],
                        ),
                        if (isCurrentUser) const SizedBox(height: 8),
                        if (isCurrentUser)
                          const Center(
                            child: Text(
                              "Tap on a slot to add or change a photo",
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 24),
        
        // Profile information section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Profile Information",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              
              // Stats display
              _buildStatsSection(),
              
              const SizedBox(height: 20),
              
              // Description section
              if (profileData.description != null && profileData.description!.isNotEmpty) ...[
                const Text(
                  "About Me",
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    profileData.description!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // User info and action buttons - stacked vertically on mobile
        isSmallScreen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User ID: ${widget.userId}",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (userData!.containsKey('lastUpdated'))
                    Text(
                      "Last seen: ${DateTime.fromMillisecondsSinceEpoch(userData!['lastUpdated']).toLocal()}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 16),
                  // Message button full width on mobile
                  if (!isCurrentUser && widget.onMessageTap != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.message),
                        label: const Text("Message"),
                        onPressed: widget.onMessageTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "User ID: ${widget.userId}",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (userData!.containsKey('lastUpdated'))
                          Text(
                            "Last seen: ${DateTime.fromMillisecondsSinceEpoch(userData!['lastUpdated']).toLocal()}",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  
                  // Message button (only show if viewing someone else's profile)
                  if (!isCurrentUser && widget.onMessageTap != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.message),
                      label: const Text("Message"),
                      onPressed: widget.onMessageTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
      ],
    );
  }

  // 8.2.9: Build photo slot
  Widget _buildPhotoSlot(String photoUrl, String slot) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final photoSize = isSmallScreen ? 90.0 : 100.0;
    
    return GestureDetector(
      onTap: isCurrentUser ? () => _uploadPicture(slot) : null,
      child: Stack(
        children: [
          Container(
            width: photoSize,
            height: photoSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              image: DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (isCurrentUser && profileData.additionalPictures?[slot] == null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Icon(
                  Icons.add_photo_alternate,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 8.2.10: Build stats section
  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profileData.age != null)
            _buildStatRow("Age", "${profileData.age}"),
          if (profileData.height != null)
            _buildStatRow("Height", profileData.getFormattedHeight()),
          if (profileData.weight != null)
            _buildStatRow("Weight", profileData.getFormattedWeight()),
          if (profileData.bodyType != null)
            _buildStatRow("Body Type", profileData.bodyType!),
          if (profileData.sexuality != null)
            _buildStatRow("Sexuality", profileData.sexuality!),
          
          if (profileData.age == null && 
              profileData.height == null &&
              profileData.weight == null &&
              profileData.bodyType == null &&
              profileData.sexuality == null)
            const Text(
              "No profile information available",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
  
  // 8.2.11: Build stat row
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  // 8.2.12: Build edit profile view
  Widget _buildEditProfileView() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Edit Your Profile Information",
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18, 
              fontWeight: FontWeight.bold, 
              color: Colors.blue
            ),
          ),
          const SizedBox(height: 20),
          
          // Age field
          TextFormField(
            controller: ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Height field
          TextFormField(
            controller: heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.height),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Weight field
          TextFormField(
            controller: weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Body type dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Body Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            value: bodyTypeController.text.isNotEmpty ? bodyTypeController.text : null,
            hint: const Text('Select Body Type'),
            items: const [
              DropdownMenuItem(value: 'Athletic', child: Text('Athletic')),
              DropdownMenuItem(value: 'Average', child: Text('Average')),
              DropdownMenuItem(value: 'Slim', child: Text('Slim')),
              DropdownMenuItem(value: 'Muscular', child: Text('Muscular')),
              DropdownMenuItem(value: 'Curvy', child: Text('Curvy')),
            ],
            onChanged: (value) {
              if (value != null) {
                bodyTypeController.text = value;
              }
            },
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          
          // Sexuality dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Sexuality',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.favorite),
            ),
            value: sexualityController.text.isNotEmpty ? sexualityController.text : null,
            hint: const Text('Select Sexuality'),
            items: const [
              DropdownMenuItem(value: 'Straight', child: Text('Straight')),
              DropdownMenuItem(value: 'Gay', child: Text('Gay')),
              DropdownMenuItem(value: 'Bisexual', child: Text('Bisexual')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) {
                sexualityController.text = value;
              }
            },
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Description field
          Text(
            "About Me",
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16, 
              fontWeight: FontWeight.bold, 
              color: Colors.blue
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(
              hintText: 'Write something about yourself...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 5,
          ),
          
          SizedBox(height: isSmallScreen ? 20 : 24),
          
          // Action buttons - stack vertically on small screens
          isSmallScreen
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _saveProfileChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Save Changes'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                          // Reset controllers to original values
                          ageController.text = profileData.age?.toString() ?? '';
                          heightController.text = profileData.height?.toString() ?? '';
                          weightController.text = profileData.weight?.toString() ?? '';
                          bodyTypeController.text = profileData.bodyType ?? '';
                          sexualityController.text = profileData.sexuality ?? '';
                          descriptionController.text = profileData.description ?? '';
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                          // Reset controllers to original values
                          ageController.text = profileData.age?.toString() ?? '';
                          heightController.text = profileData.height?.toString() ?? '';
                          weightController.text = profileData.weight?.toString() ?? '';
                          bodyTypeController.text = profileData.bodyType ?? '';
                          sexualityController.text = profileData.sexuality ?? '';
                          descriptionController.text = profileData.description ?? '';
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveProfileChanges,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

//==============================================================================
// SECTION 9: MESSAGES DIALOG
//==============================================================================

// 9.1: Messages Dialog Widget
class MessagesDialog extends StatefulWidget {
  final Function(String, String, String)? onChatSelected;
  
  const MessagesDialog({super.key, this.onChatSelected});

  // 9.1.1: Create state method
  @override
  _MessagesDialogState createState() => _MessagesDialogState();
}

// 9.2: Messages Dialog State
class _MessagesDialogState extends State<MessagesDialog> {
  // 9.2.1: State variables
  bool isLoading = true;
  List<Map<String, dynamic>> chats = [];
  StreamSubscription? _chatsSubscription;
  
  // 9.2.2: Init state method
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
  
  // 9.2.3: Dispose method
  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }
  
  // 9.2.4: Load chats method
  Future<void> _loadChats() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
          chats = [];
        });
        return;
      }
      
      // Listen to all chats where this user is a member
      _chatsSubscription = FirebaseFirestore.instance
          .collection('chat_messages')
          .where('members', arrayContains: currentUser.uid)
          .snapshots()
          .listen((snapshot) async {
            List<Map<String, dynamic>> newChats = [];
            
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final List<dynamic> members = data['members'] ?? [];
                
                // Find the other user's ID
                final otherUserId = members.firstWhere(
                  (id) => id != currentUser.uid,
                  orElse: () => '',
                );
                
                if (otherUserId.isEmpty) continue;
                
                // Get other user's info
                final userDoc = await FirebaseFirestore.instance
                    .collection('user_locations')
                    .doc(otherUserId)
                    .get();
                
                if (!userDoc.exists) continue;
                
                final userData = userDoc.data() ?? {};
                
                // Get the most recent message
                final messagesSnapshot = await FirebaseFirestore.instance
                    .collection('chat_messages')
                    .doc(doc.id)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get();
                
                String lastMessage = 'No messages yet';
                int timestamp = DateTime.now().millisecondsSinceEpoch;
                bool isRead = true;
                
                if (messagesSnapshot.docs.isNotEmpty) {
                  final messageData = messagesSnapshot.docs.first.data();
                  lastMessage = messageData['text'] ?? '';
                  
                  if (messageData['timestamp'] != null) {
                    timestamp = messageData['timestamp'] is Timestamp
                        ? (messageData['timestamp'] as Timestamp).millisecondsSinceEpoch
                        : messageData['timestamp'];
                  }
                  
                  isRead = messageData['isRead'] ?? false;
                }
                
                newChats.add({
                  'chatId': doc.id,
                  'userId': otherUserId,
                  'displayName': userData['displayName'] ?? 'User',
                  'photoURL': userData['photoURL'] ?? 'https://via.placeholder.com/40',
                  'lastMessage': lastMessage,
                  'timestamp': timestamp,
                  'isRead': isRead,
                });
              } catch (e) {
                print("Error processing chat document: $e");
              }
            }
            
            // Sort by timestamp (newest first)
            newChats.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
            
            if (mounted) {
              setState(() {
                chats = newChats;
                isLoading = false;
              });
            }
          }, onError: (e) {
            print("Error loading chats: $e");
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          });
    } catch (e) {
      print("Error in _loadChats: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  // 9.2.5: Format timestamp method
  String _formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      // Format as date if more than a week ago
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      // Format as day of week if within a week
      final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdayNames[date.weekday - 1];
    } else if (difference.inHours > 0) {
      // Format as hours ago if within a day
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      // Format as minutes ago if within an hour
      return '${difference.inMinutes}m ago';
    } else {
      // Format as just now if within a minute
      return 'Just now';
    }
  }
  
  // 9.2.6: Build method
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  "Messages",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Message list or loading indicator
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.message, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                "No messages yet",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Click on a user's profile to start chatting",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(chat['photoURL']),
                              radius: 24,
                            ),
                            title: Text(
                              chat['displayName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              chat['lastMessage'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: !chat['isRead'] ? Colors.black : Colors.grey[600],
                                fontWeight: !chat['isRead'] ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTimestamp(chat['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (!chat['isRead'] && chat['lastMessage'] != 'No messages yet')
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (widget.onChatSelected != null) {
                                widget.onChatSelected!(
                                  chat['userId'],
                                  chat['displayName'],
                                  chat['photoURL'],
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

//==============================================================================
// SECTION 10: CHAT DIALOG
//==============================================================================

// 10.1: Chat Dialog Widget
class ChatDialog extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String targetUserPhoto;
  
  const ChatDialog({
    super.key, 
    required this.targetUserId, 
    required this.targetUserName, 
    required this.targetUserPhoto
  });

  // 10.1.1: Create state method
  @override
  _ChatDialogState createState() => _ChatDialogState();
}

// 10.2: Chat Dialog State
class _ChatDialogState extends State<ChatDialog> {
  // 10.2.1: State variables
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = true;
  StreamSubscription? _messagesSubscription;
  String chatId = '';
  
  // 10.2.2: Init state method
  @override
  void initState() {
    super.initState();
    _setupChat();
  }
  
  // 10.2.3: Dispose method
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }
  
  // 10.2.4: Setup chat method
  void _setupChat() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Create chat ID by combining both user IDs alphabetically
    final chatMembers = [currentUser.uid, widget.targetUserId];
    chatMembers.sort(); // Sort to ensure consistent chat ID regardless of who initiates
    chatId = chatMembers.join('_');
    
    // Listen for messages in this chat
    _messagesSubscription = FirebaseFirestore.instance
      .collection('chat_messages')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .listen((snapshot) {
        final newMessages = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'senderId': data['senderId'],
            'text': data['text'],
            'timestamp': data['timestamp'] is Timestamp
                ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
                : (data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
            'isRead': data['isRead'] ?? false,
          };
        }).toList();
        
        if (mounted) {
          setState(() {
            chatMessages = newMessages;
            isLoading = false;
          });
          
          // Mark messages as read if they were sent by the other user
          _markMessagesAsRead();
          
          // Scroll to bottom after receiving messages
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }, onError: (e) {
        print("Error loading messages: $e");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
  }
  
  // 10.2.5: Mark messages as read method
  void _markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Find messages from the other user that are unread
    final unreadMessages = chatMessages.where((msg) => 
      msg['senderId'] == widget.targetUserId && msg['isRead'] == false
    ).toList();
    
    if (unreadMessages.isEmpty) return;
    
    // Update each message to mark as read
    for (var msg in unreadMessages) {
      await FirebaseFirestore.instance
        .collection('chat_messages')
        .doc(chatId)
        .collection('messages')
        .doc(msg['id'])
        .update({'isRead': true});
    }
  }
  
  // 10.2.6: Send message method
  void _sendMessage() async {
    if (messageController.text.trim().isEmpty) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final messageText = messageController.text.trim();
    messageController.clear();
    
    // Create message document
    final message = {
      'senderId': currentUser.uid,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };
    
    try {
      // Add message to Firestore
      await FirebaseFirestore.instance
        .collection('chat_messages')
        .doc(chatId)
        .collection('messages')
        .add(message);
      
      // Update chat document's lastActivity field
      await FirebaseFirestore.instance
        .collection('chat_messages')
        .doc(chatId)
        .update({
          'lastActivity': FieldValue.serverTimestamp(),
        });
    } catch (e) {
      print("Error sending message: $e");
      
      // Add to local list for immediate feedback in case of error
      if (mounted) {
        setState(() {
          chatMessages.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'senderId': currentUser.uid,
            'text': messageText,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isRead': false,
          });
        });
      }
    }
  }
  
  // 10.2.7: Format message time method
  String _formatMessageTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
  
  // 10.2.8: Build method
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with user info
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.targetUserPhoto),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.targetUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Messages area
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatMessages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                "No messages yet",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Start the conversation by sending a message",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatMessages.length,
                        itemBuilder: (context, index) {
                          final message = chatMessages[index];
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final isMe = message['senderId'] == currentUser?.uid;
                          
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['text'],
                                    style: TextStyle(
                                      color: isMe ? Colors.blue[900] : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatMessageTime(message['timestamp']),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          message['isRead'] ? Icons.done_all : Icons.done,
                                          size: 14,
                                          color: message['isRead'] ? Colors.blue : Colors.grey[600],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.blue,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//==============================================================================
// SECTION 11: AUTHENTICATION DIALOGS
//==============================================================================

// 11.1: Sign In Dialog Widget
class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  // 11.1.1: Create state method
  @override
  _SignInDialogState createState() => _SignInDialogState();
}

// 11.2: Sign In Dialog State
class _SignInDialogState extends State<SignInDialog> {
  // 11.2.1: State variables
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _errorMessage = '';

  // 11.2.2: Sign in method
  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        if (context.mounted) Navigator.of(context).pop();
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An error occurred during sign-in.';
        });
      }
    }
  }

  // 11.2.3: Build method
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // This prevents scroll events from propagating to the map
      onNotification: (notification) {
        // Prevent scroll notifications from propagating to parent
        return true;
      },

      // This prevents gesture events from propagating to the map
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  "Sign In",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage, 
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  onSaved: (value) => _email = value!.trim(),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty ? 'Please enter your email.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSaved: (value) => _password = value!.trim(),
                  obscureText: true,
                  validator: (value) =>
                      value!.length < 6 ? 'Password must be at least 6 characters.' : null,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      
                      final _MapScreenState mapState = context.findAncestorStateOfType<_MapScreenState>()!;
                      mapState._showResetPasswordDialog(context);
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Sign In'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 11.3: Sign Up Dialog Widget
class SignUpDialog extends StatefulWidget {
  const SignUpDialog({super.key});

  // 11.3.1: Create state method
  @override
  _SignUpDialogState createState() => _SignUpDialogState();
}

// 11.4: Sign Up Dialog State
class _SignUpDialogState extends State<SignUpDialog> {
  // 11.4.1: State variables
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _displayName = '';
  String _errorMessage = '';

  // 11.4.2: Sign up method
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        final user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(_displayName);
          
          // Create user documents
          await Future.wait([
            FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'displayName': _displayName,
              'email': _email,
              'createdAt': FieldValue.serverTimestamp(),
            }),
            
            FirebaseFirestore.instance.collection('user_locations').doc(user.uid).set({
              'displayName': _displayName,
              'photoURL': user.photoURL ?? 'https://via.placeholder.com/40',
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
              'isOnline': true,
              'lastOnline': DateTime.now().millisecondsSinceEpoch,
            }),
            
            // Initialize user profile with default settings
            FirebaseFirestore.instance.collection('user_profiles').doc(user.uid).set({
              'displayName': _displayName,
              'unitSystem': 'metric',
            }),
          ]);
          
          if (context.mounted) Navigator.of(context).pop();
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An error occurred during sign up.';
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  // 11.4.3: Build method
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // This prevents scroll events from propagating to the map
      onNotification: (notification) {
        // Prevent scroll notifications from propagating to parent
        return true;
      },
      // This prevents gesture events from propagating to the map
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage, 
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  onSaved: (value) => _displayName = value!.trim(),
                  validator: (value) => value!.isEmpty ? 'Please enter your display name.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  onSaved: (value) => _email = value!.trim(),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty ? 'Please enter your email.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSaved: (value) => _password = value!.trim(),
                  obscureText: true,
                  validator: (value) =>
                      value!.length < 6 ? 'Password must be at least 6 characters.' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Sign Up'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

