import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/timezone.dart' as tz;

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    late NotificationService service;
    late MockFlutterLocalNotificationsPlugin mockPlugin;

    setUp(() {
      mockPlugin = MockFlutterLocalNotificationsPlugin();
      service = NotificationService(plugin: mockPlugin);
    });

    test('scheduleD1Notification does not crash with past date', () async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: '2000.01.01',
        endDate: '2000.01.01',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );

      await service.scheduleD1Notification(detail);
    });

    test('scheduleD1Notification schedules with future date', () async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: '2099.12.31',
        endDate: '2099.12.31',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );

      await service.scheduleD1Notification(detail);
    });

    test('scheduleD1Notification handles exceptions gracefully', () async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: 'invalid_date',
        endDate: '2099.12.31',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );

      // Should catch FormatException internally and not throw
      await service.scheduleD1Notification(detail);
    });

    test('scheduleTicketOpenNotification does not crash', () async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: '2099.01.01',
        endDate: '2099.01.01',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );

      await service.scheduleTicketOpenNotification(detail);
    });

    test('cancelNotification does not crash', () async {
      await service.cancelNotification('1');
    });

    test('notificationServiceProvider provides service', () {
      final container = ProviderContainer();
      expect(container.read(notificationServiceProvider), isNotNull);
    });
  });
}
