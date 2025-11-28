import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:swopixer/ads/ads_variable.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:ui';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'notification_model.dart';

class NotificationService extends GetxService {
  static NotificationService get to => Get.find<NotificationService>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      tz.initializeTimeZones();

      await _initializeTimezone();

      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true,
      );

      const InitializationSettings initializationSettings =
      InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onSelectNotification,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createAndroidChannel();
      await requestPermissions();
      await _scheduleDailyNotificationsFromJson();
      await _checkPendingNotifications();

      print('NotificationService initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing: $e');
      print(stackTrace.toString());
      rethrow;
    }
  }


  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    return _notificationsPlugin.getNotificationAppLaunchDetails();
  }

  // Debugging function to check scheduled notifications
  Future<void> _checkPendingNotifications() async {
    final List<PendingNotificationRequest> pending = await _notificationsPlugin.pendingNotificationRequests();
    print('--- Pending Notifications Check ---');
    if (pending.isEmpty) {
      print('No pending notifications found.');
    } else {
      for (var p in pending) {
        print('ID: ${p.id}, Title: ${p.title}, Body: ${p.body}');
      }
    }
    print('-----------------------------------');
  }

  Future<void> _initializeTimezone() async {
    try {
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();

      String timezoneName = tzInfo.identifier;
      print('Device timezone: $timezoneName');

      // **Start of Global Timezone Mapping Logic**
      final timezoneMappings = {
        // Mapping for India: Ensures 'Asia/Calcutta' and 'IST' are treated as 'Asia/Kolkata'
        'Asia/Calcutta': 'Asia/Kolkata',
        'IST': 'Asia/Kolkata',
        // Add other common mapping exceptions here if encountered internationally
      };

      // Check if the device's reported timezone needs mapping
      if (timezoneMappings.containsKey(timezoneName)) {
        String originalTimezone = timezoneName;
        timezoneName = timezoneMappings[timezoneName]!;
        print('Mapped timezone: $originalTimezone changed to $timezoneName');
      }
      // **End of Global Timezone Mapping Logic**


      try {
        // 1. Attempt to set the local location using the standard or mapped identifier.
        tz.setLocalLocation(tz.getLocation(timezoneName));
        print('Timezone set: $timezoneName');
      } catch (e) {
        // 2. Fallback for unrecognized/non-standard IDs (like 'Asia/Calcutta').
        //    We use 'Asia/Kolkata' here to ensure the correct time is used for users in India.
        print('Timezone ID not recognized: $timezoneName, using Asia/Kolkata as fallback');
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
    } catch (e) {
      // 3. Catch errors related to fetching the timezone from the device itself.
      print('Error initializing timezone from device: $e, using Asia/Kolkata as default');
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
  }

  // Future<void> _initializeTimezone() async {
  //   try {
  //     final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
  //
  //     String timezoneName = tzInfo.identifier;
  //     print('Device timezone: $timezoneName');
  //
  //     // // India timezone mapping
  //     // final timezoneMappings = {'Asia/Calcutta': 'Asia/Kolkata', 'IST': 'Asia/Kolkata',};
  //     //
  //     // // Check if timezone needs mapping
  //     // if (timezoneMappings.containsKey(timezoneName)) {
  //     //   timezoneName = timezoneMappings[timezoneName]!;
  //     //   print('Mapped to: $timezoneName');
  //     // }
  //
  //     try {
  //       tz.setLocalLocation(tz.getLocation(timezoneName));
  //       print('Timezone set: $timezoneName');
  //     } catch (e) {
  //       print('Timezone not found: $timezoneName, using Asia/Kolkata');
  //       tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  //     }
  //   } catch (e) {
  //     print('Error initializing timezone: $e');
  //     tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  //   }
  // }


  Future<void> _createAndroidChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'flight_channel',
      'Flight Notifications',
      description: 'Daily flight notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF0000),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    try {
      if (GetPlatform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
      } else if (GetPlatform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  // Download image and save locally
  Future<String?> _downloadAndSaveImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Error', 408),
      );

      if (response.statusCode == 200) {
        final documentDirectory = await getApplicationDocumentsDirectory();
        final file = File('${documentDirectory.path}${DateTime.now().microsecond}/flight_notification.png');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      print('Error downloading image: $e');
    }
    return null;
  }

  // Schedule notifications from the JSON list
  Future<void> _scheduleDailyNotificationsFromJson() async {
    // Convert JSON to Model
    final List<FlightNotificationModel> notifications = AdsVariable.notificationJsonList.map((json) => FlightNotificationModel.fromJson(json)).toList();

    // Schedule each notification
    for (int i = 0; i < notifications.length; i++) {
      final notification = notifications[i];
      await _scheduleFlightNotification(
        id: i + 1,
        notificationModel: notification,
      );
    }

    print('${notifications.length} daily notifications scheduled from JSON');
  }

  // Schedule flight notification with model
  Future<void> _scheduleFlightNotification({
    required int id,
    required FlightNotificationModel notificationModel,
  }) async {
    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        notificationModel.hour,
        notificationModel.minute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      String? imagePath;

      if (notificationModel.imageUrl.isNotEmpty) {
        imagePath = await _downloadAndSaveImage(notificationModel.imageUrl);
      } else {
        imagePath = null;
      }


      final tzScheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

      final androidDetails = AndroidNotificationDetails(
        'flight_channel',
        'Flight Notifications',
        channelDescription: 'Daily flight notifications',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        enableLights: true,
        ledColor: const Color(0xFFFF0000),
        ledOnMs: 1000,
        ledOffMs: 500,

        styleInformation: (imagePath != null)
            ? BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          hideExpandedLargeIcon: false,
          contentTitle: notificationModel.title,
          summaryText: notificationModel.body,
        )
            : BigTextStyleInformation(notificationModel.body),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        notificationModel.title,
        notificationModel.body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('Notification #$id scheduled for ${notificationModel.hour}:${notificationModel.minute.toString().padLeft(2, '0')}');
    } catch (e, stackTrace) {
      print('Error scheduling notification: $e');
      print(stackTrace.toString());
    }
  }

  Future<bool> isNotificationPermissionGranted() async {
    try {
      if (GetPlatform.isAndroid) {
        final bool? granted = await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled();
        return granted ?? false;
      } else if (GetPlatform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final settings = await iosPlugin?.checkPermissions();
        return settings != null && (settings.isAlertEnabled || settings.isBadgeEnabled || settings.isSoundEnabled);
      }
      return false;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

// In NotificationService
  void _onSelectNotification(NotificationResponse response) {
    if (response.notificationResponseType == NotificationResponseType.selectedNotification) {
      print('Notification tapped! Payload: ${response.payload}');
    } else if (response.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
      print('Notification Action tapped: ${response.actionId}');
    }
  }
}

// Outside the NotificationService class
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (response.notificationResponseType == NotificationResponseType.selectedNotification) {
    print('Background notification tapped and app launched! Payload: ${response.payload}');
  }
}
