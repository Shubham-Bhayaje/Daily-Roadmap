import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class ReminderItem {
  final int id;
  String label;
  int hour;
  int minute;
  bool isEnabled;

  ReminderItem({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
  });

  String formatTime(BuildContext context) {
    final tod = TimeOfDay(hour: hour, minute: minute);
    return tod.format(context);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'isEnabled': isEnabled,
      };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
        id: json['id'] as int,
        label: json['label'] as String? ?? 'Practice Reminder',
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _prefMasterEnabledKey = 'notif_master_enabled';
  static const String _prefRemindersListKey = 'notif_reminders_list_v2';

  // Incremented channel ID to ensure Android resets cached channel importance to MAX
  static const String _channelId = 'daily_practice_channel_v3';
  static const String _channelName = 'Daily Practice Reminders';
  static const String _channelDescription =
      'High-priority alerts to remind you to practice and keep your streak alive';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    try {
      const platform = MethodChannel('com.example.daily_roadmap/battery');
      final String? deviceTz = await platform.invokeMethod<String>('getDeviceTimezone');
      if (deviceTz != null && deviceTz.isNotEmpty) {
        final location = tz.getLocation(deviceTz);
        tz.setLocalLocation(location);
        print('[NotificationService] Set local timezone from device: $deviceTz');
      } else {
        throw Exception('Empty device timezone');
      }
    } catch (e) {
      print('[NotificationService] Fallback timezone detection: $e');
      try {
        final now = DateTime.now();
        final offset = now.timeZoneOffset;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset.inMilliseconds) {
            tz.setLocalLocation(loc);
            break;
          }
        }
      } catch (_) {}
    }

    // 2. Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click
      },
    );

    // 3. Explicitly create MAX-importance notification channel for Heads-Up popup
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max, // Enables Heads-up banner
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );
        await androidImpl.createNotificationChannel(channel);
      }
    }

    _isInitialized = true;
  }

  /// Request runtime permission on Android 13+ (POST_NOTIFICATIONS)
  /// Also requests exact alarm permission and battery optimization exemption
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // 1. Request POST_NOTIFICATIONS permission
        final granted = await androidImpl.requestNotificationsPermission();

        // 2. Request exact alarm permission (Android 12+)
        try {
          final exactAlarmGranted = await androidImpl.requestExactAlarmsPermission();
          print('[NotificationService] Exact alarm permission: $exactAlarmGranted');
        } catch (e) {
          print('[NotificationService] Exact alarm request error: $e');
        }

        // 3. Request battery optimization exemption (critical for Motorola/Xiaomi/Samsung)
        await requestBatteryOptimizationExemption();

        return granted ?? false;
      }
    }
    return true;
  }

  /// Request exemption from battery optimization so alarms fire when app is killed
  Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      const platform = MethodChannel('com.example.daily_roadmap/battery');
      await platform.invokeMethod('requestBatteryOptimization');
    } catch (e) {
      // Fallback: try using an intent via the Android platform
      print('[NotificationService] Battery optimization request: $e');
    }
  }

  /// Check if battery optimization exemption is granted
  Future<bool> isBatteryOptimizationExempt() async {
    if (!Platform.isAndroid) return true;
    try {
      const platform = MethodChannel('com.example.daily_roadmap/battery');
      final result = await platform.invokeMethod<bool>('isBatteryOptimized');
      return result == false; // false means NOT optimized = exempt
    } catch (e) {
      return false;
    }
  }

  /// Load master switch state
  Future<bool> isMasterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefMasterEnabledKey) ?? true;
  }

  /// Load all configured reminders
  Future<List<ReminderItem>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefRemindersListKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        final items = list.map((e) => ReminderItem.fromJson(e as Map<String, dynamic>)).toList();
        if (items.isNotEmpty) return items;
      } catch (_) {}
    }

    // Default 3 practice times throughout the day
    final defaults = [
      ReminderItem(
        id: 101,
        label: 'Morning Practice 🌅',
        hour: 9,
        minute: 0,
        isEnabled: true,
      ),
      ReminderItem(
        id: 102,
        label: 'Afternoon Sprint ☀️',
        hour: 14,
        minute: 0,
        isEnabled: true,
      ),
      ReminderItem(
        id: 103,
        label: 'Evening Review 🌙',
        hour: 20,
        minute: 0,
        isEnabled: true,
      ),
    ];

    await saveReminders(defaults, masterEnabled: true);
    return defaults;
  }

  /// Save all reminders to preferences and reschedule
  Future<void> saveReminders(
    List<ReminderItem> reminders, {
    required bool masterEnabled,
    String? customTopicHint,
    int? currentStreak,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefMasterEnabledKey, masterEnabled);
    final jsonList = reminders.map((r) => r.toJson()).toList();
    await prefs.setString(_prefRemindersListKey, jsonEncode(jsonList));

    await rescheduleAll(
      reminders,
      masterEnabled: masterEnabled,
      customTopicHint: customTopicHint,
      currentStreak: currentStreak,
    );
  }

  /// Reschedule all active reminders
  Future<void> rescheduleAll(
    List<ReminderItem> reminders, {
    required bool masterEnabled,
    String? customTopicHint,
    int? currentStreak,
  }) async {
    await init();
    // Cancel existing scheduled reminders
    await _notificationsPlugin.cancelAll();

    if (!masterEnabled) return;

    for (final reminder in reminders) {
      if (!reminder.isEnabled) continue;

      final scheduledDate = _nextInstanceOfTime(reminder.hour, reminder.minute);

      String streakText = '';
      if (currentStreak != null && currentStreak > 0) {
        streakText = ' 🔥 Keep your $currentStreak-day streak alive!';
      }

      String body = 'Time for ${reminder.label}! Review your roadmap checkpoints.$streakText';
      if (customTopicHint != null && customTopicHint.isNotEmpty) {
        body = 'Focus checkpoint: $customTopicHint.$streakText';
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF00E599),
        enableLights: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      );

      const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        reminder.id,
        'Daily Practice: ${reminder.label} 🎯',
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Send an immediate test notification with MAX priority for heads-up alert
  Future<void> sendTestNotification({
    String? customTitle,
    String? customBody,
  }) async {
    await init();
    await requestPermissions();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF00E599),
      enableLights: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // 1. Send immediate test notification
    final testId = (DateTime.now().millisecondsSinceEpoch % 100000) + 10000;
    await _notificationsPlugin.show(
      testId,
      customTitle ?? 'Practice Reminder 🎯',
      customBody ??
          'Time to practice! Complete today\'s checkpoints and keep your streak alive 🔥',
      platformDetails,
    );

    // 2. Schedule a 5-second exact alarm to verify background AlarmManager fires
    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      await _notificationsPlugin.zonedSchedule(
        88888,
        '⏰ Background Alarm Fired! 🎯',
        'AlarmManager verified! Your scheduled daily practice reminders will fire on time 🔥',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('[NotificationService] Scheduled 5s background test alarm for $scheduledDate');
    } catch (e) {
      print('[NotificationService] Error scheduling background test alarm: $e');
    }
  }

  /// Helper to calculate the next TZDateTime for a given hour and minute
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time is in the past for today, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
