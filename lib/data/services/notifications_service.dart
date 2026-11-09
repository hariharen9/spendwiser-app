import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../models/app_settings.dart';
import '../models/finance_snapshot.dart';
import '../services/finance_calculator.dart';

/// Local notifications: bill reminders (2 days before due), weekly digest
/// (Sunday 20:00), and budget alerts (fired imperatively from the add-
/// transaction sheet when an envelope crosses its alert level).
abstract final class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'spendwiser';
  static const _channelName = 'Spendwiser reminders';

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> showNow(String title, String body, {int id = 0}) async {
    if (!_initialized) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Schedule bill reminders + weekly digest from the current snapshot.
  /// Called on app start and whenever notification settings change.
  static Future<void> reschedule(FinanceSnapshot snapshot, AppSettings settings) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    var id = 100;

    if (settings.billReminders) {
      for (final bill in FinanceCalculator.bills(snapshot)) {
        if (bill.days < 0 || bill.days > 3) continue;
        final when = tz.TZDateTime(
          tz.local,
          bill.dueDate.year,
          bill.dueDate.month,
          bill.dueDate.day,
          9,
        );
        if (when.isBefore(now)) continue;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Bill reminder',
          body: '${bill.name} · ${rupee(bill.amount)} ${bill.relativeLabel}',
        );
      }
    }

    if (settings.weeklyDigest) {
      var dayOffset = (7 - now.weekday) % 7; // next Sunday (weekday 7)
      if (dayOffset == 0 && now.hour >= 20) dayOffset = 7;
      final sunday = now.add(Duration(days: dayOffset));
      final when = tz.TZDateTime(
        tz.local,
        sunday.year,
        sunday.month,
        sunday.day,
        20,
      );
      if (when.isAfter(now)) {
        final month = monthStart(now.toLocal());
        final flow = snapshot.flow(month);
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Weekly digest',
          body: 'Spent ${rupee(flow.expense)} · Earned ${rupee(flow.income)} this month',
        );
      }
    }
  }

  /// Fired when a new expense pushes an envelope over its alert level.
  /// Mirrors the in-app toast in AddTransactionSheet.
  static Future<void> budgetAlert(String category, double progress, int alertAt) async {
    await showNow(
      'Budget alert',
      '$category is at ${(progress * 100).round()}% (alert $alertAt%)',
      id: 999,
    );
  }
}
