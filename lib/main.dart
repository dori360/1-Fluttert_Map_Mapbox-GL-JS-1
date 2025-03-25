import 'dart:html' hide VoidCallback; // Hide VoidCallback to avoid conflict
import 'dart:ui_web' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'dart:js' as js;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Firebase packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// User profile data model class
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
  
  // Convert height from cm to feet/inches if using imperial
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
  
  // Convert weight from kg to lbs if using imperial
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

  // Set up Firestore settings - crucial for preventing some errors
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  ui.platformViewRegistry.registerViewFactory('mapbox-gl-element', (int viewId) {
    final div = DivElement()
      ..id = 'mapbox-map'
      ..style.width = '100%'
      ..style.height = '100%';
    return div;
  });

  // Register a callback function for user click in JavaScript
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox & Firebase Integration',
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

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Timer? _locationUpdateTimer;
  Timer? _fetchUsersTimer;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _userLocationsSubscription;
  String? _currentUserId;
  bool _isUserLoggedIn = false;
  
  // Store user data for quick access
  Map<String, Map<String, dynamic>> _usersData = {};
  
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
        
        // Force location update when logging in
        _forceLocationUpdate();
        
        // Update location once and start fetching other users
        _updateUserLocation(); // Single update instead of starting timer
        _startFetchingUserLocations();
      } else {
        print("User logged out");
        setState(() {
          _currentUserId = null;
          _isUserLoggedIn = false;
        });
        _stopLocationUpdates();
        _stopFetchingUserLocations();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _fetchUsersTimer?.cancel();
    _userLocationsSubscription?.cancel();
    super.dispose();
  }
  
  void _forceLocationUpdate() {
    // Call the JavaScript function to force a location update
    js.context.callMethod('forceUpdateLocation');
    print("Forced location update from Dart");
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }
  
  void _startFetchingUserLocations() {
    _fetchUsersTimer?.cancel();
    _fetchUsersTimer = null;
    
    // Cancel any existing subscription
    _userLocationsSubscription?.cancel();
    
    // Set up a real-time listener for user location changes
    _userLocationsSubscription = FirebaseFirestore.instance
      .collection('user_locations')
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
              users[uid] = {
                'longitude': data['longitude'],
                'latitude': data['latitude'],
                'photoURL': data['photoURL'] ?? 'https://via.placeholder.com/40',
                'displayName': data['displayName'] ?? 'User',
                'lastUpdated': data['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
              };
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

  void _startPeriodicFetching() {
    _fetchUsersTimer?.cancel();
    // Fetch locations immediately
    _fetchUserLocations();
    // Then start periodic fetching
    _fetchUsersTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchUserLocations();
    });
  }

  void _stopFetchingUserLocations() {
    _fetchUsersTimer?.cancel();
    _fetchUsersTimer = null;
    
    // Cancel the Firestore subscription
    _userLocationsSubscription?.cancel();
    _userLocationsSubscription = null;
    
    // Clear markers
    js.context.callMethod('updateOtherUsersMarkers', [js.JsObject.jsify({})]);
  }

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
            
            // Document data structure - simpler format without GeoPoint
            final Map<String, dynamic> docData = {
              'longitude': longitude,
              'latitude': latitude,
              'photoURL': user.photoURL ?? 'https://via.placeholder.com/40',
              'displayName': user.displayName ?? 'User',
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
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

  Future<void> _fetchUserLocations() async {
    if (!_isUserLoggedIn || _currentUserId == null) return;
    
    try {
      print("Fetching user locations from Firestore");
      
      // Try method 1: Use Firestore SDK
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('user_locations')
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
              users[uid] = {
                'longitude': data['longitude'],
                'latitude': data['latitude'],
                'photoURL': data['photoURL'] ?? 'https://via.placeholder.com/40',
                'displayName': data['displayName'] ?? 'User',
                'lastUpdated': data['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
              };
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
        
        // Build the URL for Firestore REST API
        final url = 'https://firestore.googleapis.com/v1/projects/mapbox-in-javascript/databases/(default)/documents/user_locations';
        
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
          
          for (var doc in documents) {
            try {
              final String path = doc['name'];
              final String uid = path.split('/').last;
              
              // Skip current user
              if (uid == _currentUserId) continue;
              
              final fields = doc['fields'];
              
              // Only include users with valid location data
              if (fields['longitude'] != null && fields['latitude'] != null) {
                users[uid] = {
                  'longitude': double.parse(fields['longitude']['doubleValue'].toString()),
                  'latitude': double.parse(fields['latitude']['doubleValue'].toString()),
                  'photoURL': fields['photoURL']?['stringValue'] ?? 'https://via.placeholder.com/40',
                  'displayName': fields['displayName']?['stringValue'] ?? 'User',
                  'lastUpdated': int.parse(fields['lastUpdated']?['integerValue'] ?? '0'),
                };
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
          builder: (context) => Stack(
            children: [
              Positioned(
                top: kToolbarHeight,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.4, // Increased from 0.3
                child: const SignInDialog(),
              ),
            ],
          ),
        );
        break;
      case 'sign_up':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [
              Positioned(
                top: kToolbarHeight,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.4, // Increased from 0.3
                child: const SignUpDialog(),
              ),
            ],
          ),
        );
        break;
      case 'change_profile_picture':
        _uploadProfilePicture(context, "main");
        break;
      case 'sign_out':
        FirebaseAuth.instance.signOut();
        break;
    }
  }

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

  void _showUpgradeOptions(BuildContext context) {
    js.context.callMethod('closeAllPopups');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Account'),
        content: const SizedBox(
          width: 400,
          child: Text('Upgrade options will be available here.'),
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

  // Method to show user profile as a positioned dialog
  void _showUserProfile(String userId) {
    // Close any open popups before showing profile
    js.context.callMethod('closeAllPopups');
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            top: kToolbarHeight,
            right: 0,
            width: 600,
            height: MediaQuery.of(context).size.height * 0.8, // Set a fixed height
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(20),
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
        ],
      ),
    );
  }

  // Method to show messages dialog
  void _showMessagesDialog(BuildContext context) {
    // Close any open popups first
    js.context.callMethod('closeAllPopups');
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            bottom: 20,
            right: 20,
            width: 400,
            height: 500,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(20),
              child: MessagesDialog(
                onChatSelected: (userId, name, photo) {
                  // Close messages dialog and open chat
                  Navigator.of(context).pop();
                  _startChatWithUser(userId, name: name, photo: photo);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to start a chat with a user
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
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            bottom: 20,
            right: 20,
            width: 400,
            height: 500,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(20),
              child: ChatDialog(
                targetUserId: userId,
                targetUserName: targetUserName,
                targetUserPhoto: targetUserPhoto,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rimmies",
          style: TextStyle(
            fontSize: 24, // Increased from default
            fontWeight: FontWeight.bold,
          ),
        ),
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
          // Debug Panel
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User ID: ${_currentUserId ?? 'Not signed in'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text("Update My Location"),
                    onPressed: () {
                      _forceLocationUpdate();
                      _updateUserLocation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(220, 48), // Increased size
                      textStyle: const TextStyle(fontSize: 16), // Increased font size
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh Other Users"),
                    onPressed: _fetchUserLocations,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(220, 48), // Increased size
                      textStyle: const TextStyle(fontSize: 16), // Increased font size
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.code),
                    label: const Text("Print Debug Info"),
                    onPressed: () {
                      print("Current User ID: $_currentUserId");
                      print("Is User Logged In: $_isUserLoggedIn");
                      print("JS userLocation: ${js.context['userLocation']}");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(220, 48), // Increased size
                      textStyle: const TextStyle(fontSize: 16), // Increased font size
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Connection status indicator
          Positioned(
            top: 10,
            left: 10,
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                final isLoggedIn = snapshot.data != null;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isLoggedIn ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLoggedIn ? Icons.check_circle : Icons.error,
                        color: Colors.white,
                        size: 20, // Increased from 18
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isLoggedIn ? "Connected" : "Not Connected",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16, // Increased from default
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Messages button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => _showMessagesDialog(context),
              backgroundColor: Colors.blue,
              elevation: 4,
              child: const Icon(Icons.message, size: 28), // Increased size
            ),
          ),
        ],
      ),
    );
  }
}

// Class for user profile dialog
class UserProfileDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onMessageTap;
  
  const UserProfileDialog({
    super.key, 
    required this.userId,
    this.onMessageTap,
  });

  @override
  _UserProfileDialogState createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
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
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
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
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text("Loading user profile...")
          ],
        ),
      );
    }
    
    if (userData == null) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
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
    
    return Container(
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
                Text(
                  isEditing ? "Edit Profile" : displayName,
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  ),
                ),
                const Spacer(),
                if (isCurrentUser && !isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 28), // Increased size
                    tooltip: "Edit Profile",
                    onPressed: () {
                      setState(() {
                        isEditing = true;
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28), // Increased size
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: isEditing 
                    ? _buildEditProfileView()
                    : _buildProfileView(mainPhotoURL, pic1, pic2, pic3),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileView(String mainPhotoURL, String pic1, String pic2, String pic3) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photos row
        Row(
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
                      final _MapScreenState mapState = context.findAncestorStateOfType<_MapScreenState>()!;
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
                      GestureDetector(
                        onTap: isCurrentUser ? () => _uploadPicture('1') : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
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
                                  image: NetworkImage(pic1),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (isCurrentUser && profileData.additionalPictures?['1'] == null)
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
                      ),
                      // Photo slot 2
                      GestureDetector(
                        onTap: isCurrentUser ? () => _uploadPicture('2') : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
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
                                  image: NetworkImage(pic2),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (isCurrentUser && profileData.additionalPictures?['2'] == null)
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
                      ),
                      // Photo slot 3
                      GestureDetector(
                        onTap: isCurrentUser ? () => _uploadPicture('3') : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
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
                                  image: NetworkImage(pic3),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (isCurrentUser && profileData.additionalPictures?['3'] == null)
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
                      ),
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
        
        // User info and action buttons
        Row(
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
            if (!isCurrentUser)
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
  
  Widget _buildEditProfileView() {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Edit Your Profile Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
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
          const SizedBox(height: 12),
          
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
          const SizedBox(height: 12),
          
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
          const SizedBox(height: 12),
          
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
          const SizedBox(height: 12),
          
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
          const SizedBox(height: 20),
          
          // Description field
          const Text(
            "About Me",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
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
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
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

// Messages dialog
class MessagesDialog extends StatefulWidget {
  final Function(String, String, String)? onChatSelected;
  
  const MessagesDialog({super.key, this.onChatSelected});

  @override
  _MessagesDialogState createState() => _MessagesDialogState();
}

class _MessagesDialogState extends State<MessagesDialog> {
  bool isLoading = true;
  List<Map<String, dynamic>> chats = [];
  StreamSubscription? _chatsSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
  
  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }
  
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
      
      // Listen for chats where the current user is a member
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
}

// Chat dialog for direct messaging
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

  @override
  _ChatDialogState createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = true;
  StreamSubscription? _messagesSubscription;
  String chatId = '';
  
  @override
  void initState() {
    super.initState();
    _setupChat();
  }
  
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }
  
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
  
  String _formatMessageTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

// Original SignInDialog class
class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  _SignInDialogState createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _errorMessage = '';

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

  @override
  Widget build(BuildContext context) {
    return Material(
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
              const SizedBox(height: 24),
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
    );
  }
}

// Original SignUpDialog class
class SignUpDialog extends StatefulWidget {
  const SignUpDialog({super.key});

  @override
  _SignUpDialogState createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _displayName = '';
  String _errorMessage = '';

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

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}