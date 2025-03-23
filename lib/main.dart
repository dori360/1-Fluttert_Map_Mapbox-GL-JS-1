import 'dart:html';
import 'dart:ui_web' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'dart:js' as js;
import 'dart:convert';
import 'package:flutter/material.dart';

// Firebase packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox & Firebase Integration',
      debugShowCheckedModeBanner: false,
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
  String? _currentUserId;
  bool _isUserLoggedIn = false;
  
  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        print("User logged in: ${user.uid} - Email: ${user.email}");
        setState(() {
          _currentUserId = user.uid;
          _isUserLoggedIn = true;
        });
        js.context.callMethod('setCurrentUserId', [_currentUserId]);
        
        // Force location update from JavaScript
        _forceLocationUpdate();
        
        // Start timers for location updates and fetching
        _startLocationUpdates();
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
    super.dispose();
  }
  
  void _forceLocationUpdate() {
    // Call the JavaScript function to force a location update
    js.context.callMethod('forceUpdateLocation');
    print("Forced location update from Dart");
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    // Update location immediately
    _updateUserLocation();
    // Then start periodic updates
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateUserLocation();
    });
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  void _startFetchingUserLocations() {
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
        
        // Parse the response - THIS IS THE LINE THAT NEEDS TO BE FIXED
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
      case 'sign_in':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => Stack(
            children: [
              Positioned(
                top: kToolbarHeight,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.3,
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
                width: MediaQuery.of(context).size.width * 0.3,
                child: const SignUpDialog(),
              ),
            ],
          ),
        );
        break;
      case 'change_profile_picture':
        _uploadProfilePicture(context);
        break;
      case 'sign_out':
        FirebaseAuth.instance.signOut();
        break;
    }
  }

void _uploadProfilePicture(BuildContext context) {
  final input = FileUploadInputElement()..accept = 'image/*';
  
  input.onChange.listen((e) async {
    final files = input.files;
    if (files == null || files.isEmpty) return;
    
    final file = files.first;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No authenticated user found");
      return;
    }
    
    print("Starting upload for user: ${user.uid}");
    
    try {
      // Read file
      final reader = FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoadEnd.listen((e) {
        if (reader.readyState == FileReader.DONE) {
          completer.complete(reader.result as Uint8List);
        }
      });
      reader.readAsArrayBuffer(file);
      final data = await completer.future;
      print("File size: ${data.length} bytes");
      
      // Create a direct reference to the profile picture
      final filePath = 'profile_pictures/${user.uid}.jpg';
      print("Uploading to: $filePath");
      
      // Create storage reference
      final Reference storageRef = FirebaseStorage.instance.ref().child(filePath);
      
      // Configure metadata (optional but can help)
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': user.uid},
      );
      
      // Start upload with metadata
      final uploadTask = storageRef.putData(data, metadata);
      
      // Monitor upload
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print("Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}");
      });
      
      // Wait for upload to complete
      await uploadTask;
      print("Upload completed");
      
      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();
      print("Download URL: $downloadUrl");
      
      // Update user profile
      await user.updateProfile(photoURL: downloadUrl);
      print("Updated auth profile");
      
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(user.uid)
          .update({'photoURL': downloadUrl});
      print("Updated Firestore document");
      
      // Update JavaScript
      js.context.callMethod('setProfilePicture', [downloadUrl]);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
      
    } catch (e) {
      print("ERROR: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      }
    }
  });
  
  input.click();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapbox GL JS in Flutter"),
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(color: Colors.white);
              }
              
              final user = snapshot.data;
              final photoURL = user?.photoURL;
              
              // Set profile picture in JavaScript
              if (photoURL != null) {
                js.context.callMethod('setProfilePicture', [photoURL]);
              }
              
              return PopupMenuButton<String>(
                onSelected: (value) => _handleMenuSelection(context, value),
                icon: CircleAvatar(
                  radius: 20,
                  backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                  child: photoURL == null ? const Icon(Icons.account_circle, size: 40) : null,
                ),
                tooltip: "Show menu",
                itemBuilder: (BuildContext context) {
                  if (user != null) {
                    return <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(user.displayName ?? 'User'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'change_profile_picture',
                        child: Text("Change Profile Picture"),
                      ),
                      const PopupMenuItem<String>(
                        value: 'sign_out',
                        child: Text("Sign Out"),
                      ),
                    ];
                  } else {
                    return <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'sign_in',
                        child: Text("Sign In"),
                      ),
                      const PopupMenuItem<String>(
                        value: 'sign_up',
                        child: Text("Sign Up"),
                      ),
                    ];
                  }
                },
              );
            },
          ),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
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
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text("Update My Location"),
                    onPressed: _forceLocationUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh Other Users"),
                    onPressed: _fetchUserLocations,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLoggedIn ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLoggedIn ? Icons.check_circle : Icons.error,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isLoggedIn ? "Connected" : "Not Connected",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!.trim(),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Please enter your email.' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                onSaved: (value) => _password = value!.trim(),
                obscureText: true,
                validator: (value) =>
                    value!.length < 6 ? 'Password must be at least 6 characters.' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signIn,
                child: const Text('Sign In'),
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Display Name'),
                onSaved: (value) => _displayName = value!.trim(),
                validator: (value) => value!.isEmpty ? 'Please enter your display name.' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!.trim(),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Please enter your email.' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                onSaved: (value) => _password = value!.trim(),
                obscureText: true,
                validator: (value) =>
                    value!.length < 6 ? 'Password must be at least 6 characters.' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: const Text('Sign Up'),
              ),
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