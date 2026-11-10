import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static const _dailyId = 50;
  static const _weeklyId = 60;
  static const _billIdStart = 100;
  static const _billIdEnd = 200;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Fall back to the package default if the platform cannot report a zone.
    }
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

  /// Schedule the daily check-in, bill reminders and weekly digest.
  /// Called on app start and whenever notification settings change.
  static Future<void> reschedule(
    FinanceSnapshot snapshot,
    AppSettings settings,
  ) async {
    if (!_initialized) return;
    await _cancelScheduled();
    final now = tz.TZDateTime.now(tz.local);
    final hour = settings.reminderHour.clamp(0, 23).toInt();
    final minute = settings.reminderMinute.clamp(0, 59).toInt();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    if (settings.dailyReminder) {
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _dailyId,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: scheduleMode,
        title: 'Daily check-in',
        body: 'Log today\'s spends and keep your streak alive.',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    if (settings.billReminders) {
      var id = _billIdStart;
      for (final bill in FinanceCalculator.bills(snapshot)) {
        if (bill.days < 0) continue;
        final reminderDate = bill.dueDate.subtract(const Duration(days: 2));
        var when = tz.TZDateTime(
          tz.local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          hour,
          minute,
        );
        if (!when.isAfter(now)) {
          if (bill.days > 2) continue;
          when = now.add(const Duration(minutes: 1));
        }
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: scheduleMode,
          title: 'Bill reminder',
          body: '${bill.name} · ${rupee(bill.amount)} ${bill.relativeLabel}',
        );
      }
    }

    if (settings.weeklyDigest) {
      final dayOffset = (7 - now.weekday) % 7; // next Sunday (weekday 7)
      final sunday = now.add(Duration(days: dayOffset));
      var when = tz.TZDateTime(
        tz.local,
        sunday.year,
        sunday.month,
        sunday.day,
        hour,
        minute,
      );
      if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
      final month = monthStart(now.toLocal());
      final flow = snapshot.flow(month);
      await _plugin.zonedSchedule(
        id: _weeklyId,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: scheduleMode,
        title: 'Weekly digest',
        body: 'Spent ${rupee(flow.expense)} · Earned ${rupee(flow.income)} this month',
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Cancels only our scheduled reminders, keeping the native SMS-review
  /// notification and one-off alerts intact.
  static Future<void> _cancelScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      final id = notification.id;
      if (id == _dailyId ||
          id == _weeklyId ||
          (id >= _billIdStart && id < _billIdEnd)) {
        await _plugin.cancel(id: id);
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
