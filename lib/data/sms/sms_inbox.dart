import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class SmsMessage {
  const SmsMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  final String id;
  final String sender;
  final String body;
  final DateTime receivedAt;

  factory SmsMessage.fromMap(Map<dynamic, dynamic> map) => SmsMessage(
    id: '${map['id'] ?? ''}',
    sender: '${map['sender'] ?? ''}',
    body: '${map['body'] ?? ''}',
    receivedAt: DateTime.fromMillisecondsSinceEpoch(
      (map['receivedAt'] as num?)?.toInt() ?? 0,
    ),
  );
}

/// Device-local SMS queue. Android-only; other platforms return empty data.
abstract final class SmsInbox {
  static const _channel = MethodChannel('spendwiser/sms');
  static const _events = EventChannel('spendwiser/sms_events');

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<List<SmsMessage>> pending() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getPending');
      return (raw ?? const [])
          .whereType<Map>()
          .map(SmsMessage.fromMap)
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<int> count() async {
    if (!isSupported) return 0;
    try {
      return await _channel.invokeMethod<int>('count') ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  static Future<void> remove(String id) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('remove', {'id': id});
    } on PlatformException {
      // Ignore: the item will be retried on the next refresh.
    } on MissingPluginException {
      // Ignore.
    }
  }

  static Future<void> clear() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      // Ignore.
    } on MissingPluginException {
      // Ignore.
    }
  }

  /// Debug/testing helper: inject an SMS into the local queue.
  static Future<SmsMessage?> addRaw({
    required String sender,
    required String body,
    DateTime? receivedAt,
  }) async {
    if (!isSupported) return null;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'addRaw',
        {
          'sender': sender,
          'body': body,
          'receivedAt': (receivedAt ?? DateTime.now()).millisecondsSinceEpoch,
        },
      );
      return raw == null ? null : SmsMessage.fromMap(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Stream<SmsMessage> watch() {
    if (!isSupported) return const Stream<SmsMessage>.empty();
    return _events
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => SmsMessage.fromMap(event as Map))
        .handleError((Object _) {});
  }
}
