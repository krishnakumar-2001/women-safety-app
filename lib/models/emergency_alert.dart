class EmergencyAlert {
  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final List<String> imageBase64List; // Photos from front and back cameras
  final DateTime timestamp;
  final String message;

  EmergencyAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.imageBase64List,
    required this.timestamp,
    this.message = "Emergency! Help me!",
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'images': imageBase64List, // Sending base64 for upload, or paths for update
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  factory EmergencyAlert.fromMap(Map<String, dynamic> map) {
    return EmergencyAlert(
      id: map['_id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      // Map correctly to 'imageBase64List' or 'images' depending on the server response
      imageBase64List: List<String>.from(map['imageBase64List'] ?? map['images'] ?? []),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      message: map['message'] ?? '',
    );
  }
}
