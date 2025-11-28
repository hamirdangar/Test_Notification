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

  factory FlightNotificationModel.fromJson(Map<String, dynamic> json) {
    return FlightNotificationModel(
      hour: json['hour'] ?? 0,
      minute: json['minute'] ?? 0,
      title: json['title'] ?? "",
      body: json['body'] ?? "",
      imageUrl: (json['imageUrl'] ?? "").toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
      'imageUrl': imageUrl.isEmpty ? "" : imageUrl,
    };
  }
}
