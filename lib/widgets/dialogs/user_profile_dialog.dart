// lib/widgets/dialogs/user_profile_dialog.dart
import 'dart:html' hide VoidCallback; // Hide VoidCallback to avoid conflict
import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  
  String getFormattedHeight() {
    if (height == null) return "Not set";
    
    if (unitSystem == 'imperial') {
      final double totalInches = height! * 0.393701;
      final int feet = totalInches ~/ 12;
      final int inches = (totalInches % 12).round();
      return "$feet'$inches\"";
    } else {
      return "$height cm";
    }
  }
  
  String getFormattedWeight() {
    if (weight == null) return "Not set";
    
    if (unitSystem == 'imperial') {
      final double lbs = weight! * 2.20462;
      return "${lbs.round()} lbs";
    } else {
      return "$weight kg";
    }
  }
}

class UserProfileDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onMessageTap;
  
  const UserProfileDialog({
    Key? key, 
    required this.userId,
    this.onMessageTap,
  }) : super(key: key);

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
      return const Padding(
        padding: EdgeInsets.all(20.0),
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
                    icon: const Icon(Icons.edit, color: Colors.white, size: 28),
                    tooltip: "Edit Profile",
                    onPressed: () {
                      setState(() {
                        isEditing = true;
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
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
                      // This will be handled in the MapScreen
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
                      // Photo slots 2 and 3 would follow the same pattern
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
              
              // Stats display - placeholder
              Container(
                padding: const EdgeInsets.all(12),
                child: const Text("Profile stats would appear here"),
              ),
            ],
          ),
        ),
        
        // Action buttons for non-current users
        if (!isCurrentUser)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.message),
              label: const Text("Message"),
              onPressed: widget.onMessageTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildEditProfileView() {
    // Placeholder for the profile editing form
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Edit Your Profile Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Form fields would go here
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    isEditing = false;
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