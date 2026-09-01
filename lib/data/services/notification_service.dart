import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:u_art/data/models/performance.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin}) 
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;
    
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _plugin.initialize(settings: initializationSettings);
    
    if (!kIsWeb) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    }
    
    _initialized = true;
  }

  Future<void> cancelNotification(String id) async {
    final notificationId = id.hashCode;
    await _plugin.cancel(id: notificationId);
  }

  Future<void> scheduleD1Notification(PerformanceDetail detail) async {
    await initialize();
    
    try {
      final dateFormat = DateFormat('yyyy.MM.dd');
      final startDate = dateFormat.parse(detail.startDate);
      
      final scheduledDate = startDate.subtract(const Duration(days: 1)).add(const Duration(hours: 10));
      
      if (scheduledDate.isBefore(DateTime.now())) {
        return;
      }

      final notificationId = detail.id.hashCode;

      await _plugin.zonedSchedule(
        id: notificationId,
        title: '다가오는 공연 알림',
        body: '내일 [${detail.title}] 공연이 시작됩니다! 잊지 마세요.',
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'uart_d1_notifications',
            'D-1 공연 알림',
            channelDescription: '찜한 공연이 다가올 때 알려줍니다.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: \$e');
    }
  }

  Future<void> scheduleTicketOpenNotification(PerformanceDetail detail) async {
    await initialize();
    
    final scheduledDate = DateTime.now().add(const Duration(seconds: 5));
    final notificationId = '${detail.id}_ticket'.hashCode;

    await _plugin.zonedSchedule(
      id: notificationId,
      title: '티켓 오픈 알림',
      body: '[${detail.title}] 티켓팅이 곧 시작됩니다. 준비하세요!',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'uart_ticket_notifications',
          '티켓 오픈 알림',
          channelDescription: '찜한 공연의 티켓 오픈 시간을 알려줍니다.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
