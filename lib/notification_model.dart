// lib/models/notification_model.dart
class FlightNotificationModel {
  final int hour;
  final int minute;
  final String title;
  final String body;
  final String imageUrl;

  FlightNotificationModel({
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
    required this.imageUrl,
  });

  // JSON से convert करने के लिए
  factory FlightNotificationModel.fromJson(Map<String, dynamic> json) {
    return FlightNotificationModel(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String,
    );
  }

  // JSON में convert करने के लिए
  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
    };
  }
}




