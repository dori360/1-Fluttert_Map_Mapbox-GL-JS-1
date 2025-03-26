// Group UI components and functionality

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:js/js.dart';
import 'group_model.dart';

class GroupsDialog extends StatefulWidget {
  const GroupsDialog({super.key});

  @override
  _GroupsDialogState createState() => _GroupsDialogState();
}

class _GroupsDialogState extends State<GroupsDialog> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  List<GroupData> nearbyGroups = [];
  List<GroupData> myGroups = [];
  bool hasCreatedGroup = false;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroups();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadGroups() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      // Check if user has created a group
      final createdGroupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('creatorId', isEqualTo: currentUser.uid)
          .get();
      
      hasCreatedGroup = createdGroupsSnapshot.docs.isNotEmpty;
      
      // Get user's current location
      final userLocationDoc = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(currentUser.uid)
          .get();
      
      if (!userLocationDoc.exists) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      final userData = userLocationDoc.data() ?? {};
      final userLat = userData['latitude'] as double?;
      final userLng = userData['longitude'] as double?;
      
      if (userLat == null || userLng == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      // Load all groups
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .get();
      
      final allGroups = groupsSnapshot.docs.map((doc) => 
          GroupData.fromMap(doc.id, doc.data())).toList();
      
      // Filter nearby groups based on distance
      nearbyGroups = allGroups.where((group) {
        // Calculate distance between user and group
        final distance = _calculateDistance(
          userLat, userLng, 
          group.latitude, group.longitude
        );
        
        // Include group if user is within its radius
        return distance <= group.radius;
      }).toList();
      
      // Filter groups where user is a member
      myGroups = allGroups.where((group) => 
          group.members.contains(currentUser.uid) || 
          group.creatorId == currentUser.uid
      ).toList();
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error loading groups: $e");
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Simple distance calculation (approximate)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = 
        (dLat / 2).sin() * (dLat / 2).sin() +
        (dLon / 2).sin() * (dLon / 2).sin() * lat1.cos() * lat2.cos();
    final c = 2 * a.sqrt().atan2((1 - a).sqrt());
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
  
  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final radiusController = TextEditingController(text: '5.0');
    bool requiresSubscription = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                const SizedBox(height: 16),
                TextField(
                  controller: radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Radius (km)',
                    border: OutlineInputBorder(),
                    helperText: 'Area covered by this group',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Require Subscription'),
                  subtitle: const Text('Members need to subscribe to join'),
                  value: requiresSubscription,
                  onChanged: (value) {
                    setState(() {
                      requiresSubscription = value;
                    });
                  },
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
                final radiusText = radiusController.text.trim();
                
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
                  return;
                }
                
                double radius;
                try {
                  radius = double.parse(radiusText);
                  if (radius <= 0) throw FormatException();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid radius')),
                  );
                  return;
                }
                
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;
                
                // Get user's current location
                final userLocationDoc = await FirebaseFirestore.instance
                    .collection('user_locations')
                    .doc(currentUser.uid)
                    .get();
                
                if (!userLocationDoc.exists) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Location not available')),
                    );
                  }
                  return;
                }
                
                final userData = userLocationDoc.data() ?? {};
                final userLat = userData['latitude'] as double?;
                final userLng = userData['longitude'] as double?;
                
                if (userLat == null || userLng == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Location not available')),
                    );
                  }
                  return;
                }
                
                // Create new group
                final newGroup = {
                  'name': name,
                  'description': description,
                  'creatorId': currentUser.uid,
                  'latitude': userLat,
                  'longitude': userLng,
                  'radius': radius,
                  'members': [currentUser.uid],
                  'requiresSubscription': requiresSubscription,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                };
                
                try {
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .add(newGroup);
                  
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _loadGroups(); // Refresh groups list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group created successfully')),
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
      ),
    );
  }
  
  void _showGroupDetails(GroupData group) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final bool isCreator = group.creatorId == currentUser.uid;
    final bool isMember = group.members.contains(currentUser.uid);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.description),
            const SizedBox(height: 16),
            Text('Area radius: ${group.radius} km'),
            const SizedBox(height: 8),
            Text('Members: ${group.members.length}'),
            const SizedBox(height: 8),
            if (group.requiresSubscription)
              const Text('This group requires subscription',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!isMember)
            ElevatedButton(
              onPressed: () async {
                if (group.requiresSubscription) {
                  _showSubscriptionDialog(group);
                } else {
                  // Join group directly
                  try {
                    await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(group.id)
                        .update({
                          'members': FieldValue.arrayUnion([currentUser.uid])
                        });
                    
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _loadGroups(); // Refresh groups list
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Joined group successfully')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error joining group: $e')),
                      );
                    }
                  }
                }
              },
              child: Text(group.requiresSubscription ? 'Subscribe' : 'Join'),
            ),
          if (isMember && !isCreator)
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(group.id)
                      .update({
                        'members': FieldValue.arrayRemove([currentUser.uid])
                      });
                  
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _loadGroups(); // Refresh groups list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Left group successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error leaving group: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Leave'),
            ),
          if (isCreator)
            ElevatedButton(
              onPressed: () async {
                // Confirm deletion
                if (context.mounted) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Group'),
                      content: const Text('Are you sure you want to delete this group?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(group.id)
                          .delete();
                      
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        _loadGroups(); // Refresh groups list
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Group deleted successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting group: $e')),
                        );
                      }
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }
  
  void _showSubscriptionDialog(GroupData group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe to Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To join "${group.name}", you need to subscribe.'),
    <response clipped><NOTE>To save on context only part of this file has been shown to you. You should retry this tool after you have searched inside the file with `grep -n` in order to find the line numbers of what you are looking for.</NOTE>