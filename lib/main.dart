import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.init();
  Get.put(notificationService);

  // 🚀 Check if the app was launched by tapping a notification
  final NotificationAppLaunchDetails? notificationLaunchDetails = await notificationService.getNotificationAppLaunchDetails();

  // Pass the details to MyApp
  runApp(MyApp(
    initialLaunchDetails: notificationLaunchDetails,
  ));
}

// Update MyApp to receive and handle the details
class MyApp extends StatelessWidget {
  final NotificationAppLaunchDetails? initialLaunchDetails;

  const MyApp({Key? key, this.initialLaunchDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if a notification launched the app
    if (initialLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload = initialLaunchDetails!.notificationResponse?.payload;
      print('App launched by notification tap. Payload: $payload');
      Fluttertoast.showToast(msg: "App launched by notification tap. Payload.");
    }

    return GetMaterialApp(
      title: 'Flight Notification',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:  HomeScreen(),
    );
  }
}



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key,});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Flight Notifications')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_active, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final granted = await NotificationService.to.isNotificationPermissionGranted();
                if (granted) {
                  Get.snackbar(
                    'Notification',
                    'Notifications are enabled!',
                    snackPosition: SnackPosition.BOTTOM,
                  );

                } else {
                  Get.snackbar(
                    'Permission',
                    'Please enable notifications in settings',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
              child: const Text('Check Permission'),
            ),
          ],
        ),
      ),
    );
  }
}
