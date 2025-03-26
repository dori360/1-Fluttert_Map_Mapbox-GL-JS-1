// Group data model
class GroupData {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final double latitude;
  final double longitude;
  final double radius; // Radius in kilometers
  final List<String> members;
  final bool requiresSubscription;
  final int createdAt;
  
  GroupData({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.members,
    required this.requiresSubscription,
    required this.createdAt,
  });
  
  // Create from Firestore document
  factory GroupData.fromMap(String id, Map<String, dynamic> data) {
    return GroupData(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      creatorId: data['creatorId'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      radius: (data['radius'] ?? 1.0).toDouble(),
      members: List<String>.from(data['members'] ?? []),
      requiresSubscription: data['requiresSubscription'] ?? false,
      createdAt: data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'members': members,
      'requiresSubscription': requiresSubscription,
      'createdAt': createdAt,
    };
  }
}
