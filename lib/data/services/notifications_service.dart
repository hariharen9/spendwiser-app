import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../models/app_settings.dart';
import '../models/bill.dart';
import '../models/finance_snapshot.dart';
import '../services/finance_calculator.dart';

/// Local notifications: bill reminders (2 days before & due date morning),
/// overdue payment escalations, daily check-in (20:00), weekly summary
/// (Sunday), and budget alerts with deep-linking payload support.
abstract final class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Holds the most recently received notification payload for deep linking.
  static final ValueNotifier<String?> pendingPayload = ValueNotifier<String?>(null);

  static const _channelId = 'spendwiser';
  static const _channelName = 'Spendwiser reminders';
  static const _dailyId = 50;
  static const _weeklyId = 60;
  static const _billIdStart = 100;
  static const _billIdEnd = 1000;
  static const _billRecordPrefix = 'billReminderSent:';
  static String? _lastSignature;
  static Future<void> _queue = Future<void>.value();

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Fall back to package default if platform cannot report a zone.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingPayload.value = payload;
        }
      },
    );

    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingPayload.value = payload;
        }
      }
    } catch (_) {}

    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
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

  static Future<void> showNow(
    String title,
    String body, {
    int id = 0,
    String? payload,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
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
  ) {
    if (!_initialized) return Future<void>.value();
    final bills = FinanceCalculator.bills(snapshot);
    final signature = _signature(settings, bills);
    if (signature == _lastSignature) return _queue;

    _lastSignature = signature;
    _queue = _queue
        .then((_) => _rescheduleNow(snapshot, settings, bills))
        .catchError((Object error) {
          if (_lastSignature == signature) _lastSignature = null;
          debugPrint('Notification reschedule failed: $error');
        });
    return _queue;
  }

  static String _signature(AppSettings settings, List<BillItem> bills) {
    final today = dateOnly(DateTime.now()).toIso8601String();
    return [
      today,
      settings.dailyReminder,
      settings.billReminders,
      settings.weeklyDigest,
      settings.reminderHour,
      settings.reminderMinute,
      for (final bill in bills)
        '${bill.kind.name}:${bill.name.trim().toLowerCase()}:'
            '${bill.amount.toStringAsFixed(2)}:${dateOnly(bill.dueDate)}:${bill.days}',
    ].join('|');
  }

  static Box<String>? get _settingsBox {
    try {
      if (Hive.isBoxOpen('settings')) return Hive.box<String>('settings');
    } catch (_) {}
    return null;
  }

  static String _billRecordKey(BillItem bill, String phase) =>
      '$_billRecordPrefix$phase:${bill.kind.name}:${bill.name.trim().toLowerCase()}:'
      '${dateOnly(bill.dueDate).toIso8601String()}';

  static Future<void> _cleanBillRecords(Box<String>? box, DateTime now) async {
    if (box == null) return;
    final cutoff = now.subtract(const Duration(days: 45));
    for (final key in box.keys.whereType<String>().toList()) {
      if (!key.startsWith(_billRecordPrefix)) continue;
      final value = box.get(key);
      final scheduled = value == null
          ? null
          : DateTime.tryParse(value)?.toLocal();
      if (scheduled == null || scheduled.isBefore(cutoff)) {
        await box.delete(key);
      }
    }
  }

  static Future<void> _rescheduleNow(
    FinanceSnapshot snapshot,
    AppSettings settings,
    List<BillItem> bills,
  ) async {
    if (!_initialized) return;
    await _cancelScheduled();
    final now = tz.TZDateTime.now(tz.local);
    final nowLocal = now.toLocal();
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

    // 1. Daily Check-in (Evening, configured time)
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
        payload: 'module:ledger',
      );
    }

    // 2. Bill & Payment Reminders (Advance, Due Today & Overdue Escalation)
    if (settings.billReminders) {
      final box = _settingsBox;
      await _cleanBillRecords(box, nowLocal);
      var advanceId = _billIdStart;
      var todayId = _billIdStart + 300;
      var overdueId = _billIdStart + 600;

      // Morning bill notification timing (09:00 AM)
      const billHour = 9;
      const billMinute = 0;

      for (final bill in bills) {
        final billPayload = switch (bill.kind) {
          BillKind.card => 'module:cards',
          BillKind.loan => 'module:debt',
          BillKind.subscription => 'module:subscriptions',
        };

        // A. Advance Reminder: 2 days before due date
        if (bill.days >= 2) {
          final recordKey = _billRecordKey(bill, 'advance');
          final previousRaw = box?.get(recordKey);
          final previous = previousRaw == null
              ? null
              : DateTime.tryParse(previousRaw)?.toLocal();

          if (previous == null || previous.isAfter(nowLocal)) {
            final reminderDate = bill.dueDate.subtract(const Duration(days: 2));
            var when = tz.TZDateTime(
              tz.local,
              reminderDate.year,
              reminderDate.month,
              reminderDate.day,
              billHour,
              billMinute,
            );
            if (!when.isAfter(now)) {
              if (bill.days == 2) {
                when = now.add(const Duration(minutes: 1));
              }
            }
            if (when.isAfter(now)) {
              await _plugin.zonedSchedule(
                id: advanceId++,
                scheduledDate: when,
                notificationDetails: _details,
                androidScheduleMode: scheduleMode,
                title: 'Bill reminder · ${bill.name}',
                body:
                    '${rupee(bill.amount)} is due in 2 days on ${dayMonth(bill.dueDate)}.',
                payload: billPayload,
              );
              await box?.put(recordKey, when.toLocal().toIso8601String());
            }
          }
        }

        // B. Due Today Reminder: Morning of the due date
        if (bill.days >= 0) {
          final recordKey = _billRecordKey(bill, 'today');
          final previousRaw = box?.get(recordKey);
          final previous = previousRaw == null
              ? null
              : DateTime.tryParse(previousRaw)?.toLocal();

          if (previous == null || previous.isAfter(nowLocal)) {
            var when = tz.TZDateTime(
              tz.local,
              bill.dueDate.year,
              bill.dueDate.month,
              bill.dueDate.day,
              billHour,
              billMinute,
            );
            if (!when.isAfter(now)) {
              if (bill.days == 0 && now.hour < 18) {
                when = now.add(const Duration(minutes: 1));
              }
            }
            if (when.isAfter(now)) {
              await _plugin.zonedSchedule(
                id: todayId++,
                scheduledDate: when,
                notificationDetails: _details,
                androidScheduleMode: scheduleMode,
                title: 'Due today · ${bill.name}',
                body:
                    '${rupee(bill.amount)} is due today. Pay before cut-off to avoid late fees.',
                payload: billPayload,
              );
              await box?.put(recordKey, when.toLocal().toIso8601String());
            }
          }
        }

        // C. Overdue Escalation: Overdue bills requiring immediate clearance
        if (bill.days < 0 && bill.days >= -14) {
          final recordKey = _billRecordKey(bill, 'overdue');
          final previousRaw = box?.get(recordKey);
          final previous = previousRaw == null
              ? null
              : DateTime.tryParse(previousRaw)?.toLocal();

          if (previous == null) {
            final when = now.add(const Duration(minutes: 1));
            await _plugin.zonedSchedule(
              id: overdueId++,
              scheduledDate: when,
              notificationDetails: _details,
              androidScheduleMode: scheduleMode,
              title: 'Overdue · ${bill.name}',
              body:
                  '${rupee(bill.amount)} was due on ${dayMonth(bill.dueDate)}. Clear immediately to protect credit score.',
              payload: billPayload,
            );
            await box?.put(recordKey, when.toLocal().toIso8601String());
          }
        }
      }
    }

    // 3. Weekly Financial Summary (Sunday Evening)
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
      await _plugin.zonedSchedule(
        id: _weeklyId,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: scheduleMode,
        title: 'Weekly financial summary',
        body: 'Review your spending trends and savings breakdown for this week in Insights.',
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'module:insights',
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
  static Future<void> budgetAlert(
    String category,
    double progress,
    int alertAt,
  ) async {
    await showNow(
      'Budget alert',
      '$category is at ${(progress * 100).round()}% (alert $alertAt%)',
      id: 999,
      payload: 'module:budgets',
    );
  }
}
