import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/roadmap.dart';
import '../models/daily_practice.dart';
import '../services/storage_service.dart';
import '../services/practice_manager.dart';
import '../services/roadmap_parser.dart';
import '../services/apkg_parser.dart';
import '../services/csv_parser.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NotificationService _notificationService = NotificationService();
  late PracticeManager _practiceManager;

  List<Roadmap> _roadmaps = [];
  List<DailyPractice> _todaysPractice = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  bool _masterNotificationsEnabled = true;
  List<ReminderItem> _reminders = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Roadmap> get roadmaps => _roadmaps;
  List<DailyPractice> get todaysPractice => _todaysPractice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get hasRoadmaps => _roadmaps.isNotEmpty;
  bool get notificationsEnabled => _masterNotificationsEnabled;
  List<ReminderItem> get reminders => _reminders;
  int get activeReminderCount => _reminders.where((r) => r.isEnabled).length;

  /// How many of today's practice items are done.
  int get todayDoneCount =>
      _todaysPractice.where((p) => p.isCompleted).length;

  /// Total topics completed across every roadmap.
  int get totalCompleted =>
      _roadmaps.fold(0, (sum, r) => sum + r.completedCount);

  /// Total topics across every roadmap.
  int get totalTopics =>
      _roadmaps.fold(0, (sum, r) => sum + r.totalCount);

  /// Current streak (consecutive days with at least one completion).
  int get currentStreak {
    final dates = _storage.getCompletionDates();
    if (dates.isEmpty) return 0;

    final sorted = dates.toList()..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));

    // If the most recent completion isn't today or yesterday, streak is 0.
    if (sorted.first != todayKey && sorted.first != yesterdayKey) return 0;

    int streak = 0;
    var check = dates.contains(todayKey) ? now : now.subtract(const Duration(days: 1));

    while (dates.contains(_dateKey(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Returns completion status for the last 7 days (index 0 = 6 days ago, 6 = today).
  List<bool> get weeklyCompletions {
    final dates = _storage.getCompletionDates();
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return dates.contains(_dateKey(d));
    });
  }

  /// Returns the day labels (single letter) for the last 7 days.
  List<String> get weeklyLabels {
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return dayLetters[d.weekday - 1];
    });
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _storage.init();
    _practiceManager = PracticeManager(_storage);
    _roadmaps = _storage.loadRoadmaps();

    // Auto-detect and fix any roadmap where topics were imported in reverse order (e.g. 135 down to 1)
    bool needsSave = false;
    for (final r in _roadmaps) {
      if (r.topics.length >= 2) {
        final numRegex = RegExp(r'^\s*(\d+)[\.\s\)\-]');
        final firstMatch = numRegex.firstMatch(r.topics.first.name);
        final lastMatch = numRegex.firstMatch(r.topics.last.name);
        if (firstMatch != null && lastMatch != null) {
          final firstNum = int.tryParse(firstMatch.group(1)!);
          final lastNum = int.tryParse(lastMatch.group(1)!);
          if (firstNum != null && lastNum != null && firstNum > lastNum) {
            final corrected = r.topics.reversed.toList();
            r.topics.clear();
            r.topics.addAll(corrected);
            r.currentIndex = 0;
            needsSave = true;
          }
        }
      }
    }
    if (needsSave) {
      await _storage.saveRoadmaps(_roadmaps);
    }

    // Check if we need to advance topics for a new day
    if (_roadmaps.isNotEmpty && _practiceManager.shouldAdvance()) {
      await _practiceManager.advanceTopics(_roadmaps);
    }

    _updateTodaysPractice();

    // Initialize notifications & schedule
    try {
      await _notificationService.init();
      _masterNotificationsEnabled = await _notificationService.isMasterEnabled();
      _reminders = await _notificationService.loadReminders();
      _refreshNotificationSchedule();
    } catch (e) {
      print('Notification init error: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Add a new roadmap by URL.
  Future<void> addRoadmap(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final slug = RoadmapParser.extractSlug(url);

      // Check for duplicates
      if (slug != null && _roadmaps.any((r) => r.id == slug)) {
        throw Exception('This roadmap is already added!');
      }

      final roadmap = await RoadmapParser.fetchRoadmap(url);

      // Assign today's first topic
      if (roadmap.topics.isNotEmpty) {
        roadmap.topics[0].assignedDate = DateTime.now();
      }

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import an Anki .apkg file from local device path
  Future<String?> importApkgFile(String filePath, {String? defaultName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final bytes = await file.readAsBytes();
      final roadmap = await ApkgParser.parseApkgBytes(bytes, defaultName: defaultName);

      // Replace if existing so users can re-import/update
      _roadmaps.removeWhere((r) => r.id == roadmap.id || r.name.toLowerCase() == roadmap.name.toLowerCase());

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
      return null; // success
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import an Anki .apkg file from bytes directly
  Future<String?> importApkgBytes(List<int> bytes, {String? defaultName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final roadmap = await ApkgParser.parseApkgBytes(bytes, defaultName: defaultName);

      // Replace if existing so users can re-import/update
      _roadmaps.removeWhere((r) => r.id == roadmap.id || r.name.toLowerCase() == roadmap.name.toLowerCase());

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import a CSV/TSV file from local device path
  Future<String?> importCsvFile(String filePath, {String? defaultName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final bytes = await file.readAsBytes();
      final roadmap = CsvParser.parseCsvBytes(bytes, defaultName: defaultName);

      // Replace if existing so users can re-import/update
      _roadmaps.removeWhere((r) => r.id == roadmap.id || r.name.toLowerCase() == roadmap.name.toLowerCase());

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import a CSV/TSV from bytes directly
  Future<String?> importCsvBytes(List<int> bytes, {String? defaultName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final roadmap = CsvParser.parseCsvBytes(bytes, defaultName: defaultName);

      // Replace if existing so users can re-import/update
      _roadmaps.removeWhere((r) => r.id == roadmap.id || r.name.toLowerCase() == roadmap.name.toLowerCase());

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import CSV from string directly
  Future<String?> importCsvString(String csvContent, {String? defaultName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final roadmap = CsvParser.parseCsvString(csvContent, defaultName: defaultName);

      // Replace if existing so users can re-import/update
      _roadmaps.removeWhere((r) => r.id == roadmap.id || r.name.toLowerCase() == roadmap.name.toLowerCase());

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import built-in Anki sample deck (instant testing)
  Future<String?> importSampleDeck(String key) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Roadmap roadmap;
      if (key == 'docker') {
        try {
          final data = await rootBundle.load('assets/decks/Docker_Roadmap.apkg');
          roadmap = await ApkgParser.parseApkgBytes(data.buffer.asUint8List(), defaultName: 'Docker Roadmap');
        } catch (e) {
          roadmap = ApkgParser.getSampleDeck(key);
        }
      } else if (key == 'system-design-csv') {
        const sampleCsv = '''Question,Answer,Category
"What is Horizontal vs Vertical Scaling?","Vertical scaling (scale up) adds more RAM/CPU to an existing machine. Horizontal scaling (scale out) adds more commodity machines to the pool behind a load balancer.","Architecture"
"What is the CAP Theorem?","In any distributed data store, you can only guarantee at most two out of three: Consistency (every read receives most recent write), Availability (every request receives non-error response), and Partition Tolerance (system continues despite dropped messages).","Distributed Systems"
"What is a Reverse Proxy vs Forward Proxy?","A forward proxy acts on behalf of clients (protecting client identity, filtering outbound traffic). A reverse proxy sits in front of backend web servers, handling SSL termination, load balancing, compression, and caching.","Networking"
"What is Consistent Hashing?","A distributed hashing scheme where nodes and keys are mapped to points on a circular ring. Adding or removing a node only redistributes k/n keys on average, preventing massive reshuffling.","Caching & DB"
"How does Redis provide sub-millisecond latency?","Redis is an in-memory key-value store written in C, using single-threaded event loop architecture (no lock contention or context switching) with memory-optimized data structures.","Caching"
"What is Database Sharding?","Horizontal partitioning of a database where rows of a table are held separately across distinct database servers, distributed by a shard key (e.g. user_id or hash).","Databases"
"What is Idempotency in APIs?","An API operation is idempotent if making multiple identical requests has the same effect as making a single request (e.g., HTTP GET, PUT, DELETE are idempotent; POST typically is not).","APIs & Protocols"
"What is a Circuit Breaker Pattern?","Prevents cascading failures by detecting recurring errors in external microservice calls. When failures exceed a threshold, the breaker trips to 'Open', immediately failing calls or returning fallbacks without waiting for timeouts.","Resilience"''';
        roadmap = CsvParser.parseCsvString(sampleCsv, defaultName: 'System Design (CSV)');
      } else {
        roadmap = ApkgParser.getSampleDeck(key);
      }

      // Replace if existing so users can re-import/update
      _roadmaps.removeWhere((r) => r.id == roadmap.id || r.name.toLowerCase() == roadmap.name.toLowerCase());

      _roadmaps.add(roadmap);
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      _error = null;
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return _error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a custom roadmap manually.
  Future<String?> createCustomRoadmap(String name, List<String> topicNames) async {
    final slug = 'custom-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-|-$'), '')}';

    if (_roadmaps.any((r) => r.id == slug || r.name.toLowerCase() == name.toLowerCase())) {
      return 'A roadmap with this name already exists!';
    }

    // Auto-reverse if topics were pasted in descending order (e.g. 135 down to 1)
    List<String> orderedNames = List.from(topicNames);
    if (orderedNames.length >= 2) {
      final numRegex = RegExp(r'^\s*(\d+)[\.\s\)\-]');
      final firstMatch = numRegex.firstMatch(orderedNames.first);
      final lastMatch = numRegex.firstMatch(orderedNames.last);
      if (firstMatch != null && lastMatch != null) {
        final firstNum = int.tryParse(firstMatch.group(1)!);
        final lastNum = int.tryParse(lastMatch.group(1)!);
        if (firstNum != null && lastNum != null && firstNum > lastNum) {
          orderedNames = orderedNames.reversed.toList();
        }
      }
    }

    final topics = <RoadmapTopic>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < orderedNames.length; i++) {
      topics.add(RoadmapTopic(
        id: 'custom-$now-$i',
        name: orderedNames[i],
      ));
    }

    final roadmap = Roadmap(
      id: slug,
      name: name,
      url: 'custom://$slug',
      topics: topics,
      addedAt: DateTime.now(),
    );

    if (topics.isNotEmpty) {
      topics[0].assignedDate = DateTime.now();
    }

    _roadmaps.add(roadmap);
    await _storage.saveRoadmaps(_roadmaps);
    _updateTodaysPractice();
    notifyListeners();
    return null; // success
  }

  /// Update an existing roadmap's name and topics.
  Future<void> updateRoadmap(
    String roadmapId,
    String newName,
    List<RoadmapTopic> updatedTopics,
  ) async {
    final index = _roadmaps.indexWhere((r) => r.id == roadmapId);
    if (index == -1) return;

    final old = _roadmaps[index];
    final clampedIndex = old.currentIndex.clamp(
      0,
      updatedTopics.isEmpty ? 0 : updatedTopics.length - 1,
    );

    _roadmaps[index] = Roadmap(
      id: old.id,
      name: newName,
      url: old.url,
      topics: updatedTopics,
      addedAt: old.addedAt,
      currentIndex: clampedIndex,
      isAnkiDeck: old.isAnkiDeck,
    );

    await _storage.saveRoadmaps(_roadmaps);
    _updateTodaysPractice();
    notifyListeners();
  }

  /// Called by Anki study screen when cards are reviewed
  Future<void> notifyDeckUpdated(String roadmapId) async {
    await _storage.saveRoadmaps(_roadmaps);
    await _storage.addCompletionDate(_dateKey(DateTime.now()));
    _updateTodaysPractice();
    notifyListeners();
  }

  /// Remove a roadmap.
  Future<void> removeRoadmap(String id) async {
    _roadmaps.removeWhere((r) => r.id == id);
    await _storage.saveRoadmaps(_roadmaps);
    _updateTodaysPractice();
    notifyListeners();
  }

  /// Mark a topic as completed.
  Future<void> completeTopic(String roadmapId, int topicIndex) async {
    await _practiceManager.completeTopic(_roadmaps, roadmapId, topicIndex);
    await _storage.addCompletionDate(_dateKey(DateTime.now()));
    _updateTodaysPractice();
    notifyListeners();
  }

  /// Mark topic as not completed (undo).
  Future<void> uncompleteTopic(String roadmapId, int topicIndex) async {
    final roadmap = _roadmaps.firstWhere((r) => r.id == roadmapId);
    if (topicIndex < roadmap.topics.length) {
      roadmap.topics[topicIndex].isCompleted = false;
      roadmap.topics[topicIndex].completedAt = null;
      await _storage.saveRoadmaps(_roadmaps);
      _updateTodaysPractice();
      notifyListeners();
    }
  }

  void _updateTodaysPractice() {
    _todaysPractice = _practiceManager.getTodaysPractice(_roadmaps);
    _refreshNotificationSchedule();
  }

  void _refreshNotificationSchedule() {
    String? hint;
    if (_todaysPractice.isNotEmpty) {
      final uncompleted = _todaysPractice.where((p) => !p.isCompleted).toList();
      if (uncompleted.isNotEmpty) {
        hint = '${uncompleted.first.roadmapName}: ${uncompleted.first.topicName}';
      }
    }
    _notificationService.rescheduleAll(
      _reminders,
      masterEnabled: _masterNotificationsEnabled,
      customTopicHint: hint,
      currentStreak: currentStreak,
    );
  }

  /// Toggle master notifications
  Future<void> toggleMasterNotifications(bool enabled) async {
    _masterNotificationsEnabled = enabled;
    notifyListeners();
    await _saveAndRescheduleReminders();
  }

  /// Toggle single reminder
  Future<void> toggleReminder(int reminderId, bool enabled) async {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx != -1) {
      _reminders[idx].isEnabled = enabled;
      notifyListeners();
      await _saveAndRescheduleReminders();
    }
  }

  /// Update single reminder time
  Future<void> updateReminderTime(int reminderId, int hour, int minute) async {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx != -1) {
      _reminders[idx].hour = hour;
      _reminders[idx].minute = minute;
      notifyListeners();
      await _saveAndRescheduleReminders();
    }
  }

  /// Update single reminder label
  Future<void> updateReminderLabel(int reminderId, String newLabel) async {
    final idx = _reminders.indexWhere((r) => r.id == reminderId);
    if (idx != -1 && newLabel.trim().isNotEmpty) {
      _reminders[idx].label = newLabel.trim();
      notifyListeners();
      await _saveAndRescheduleReminders();
    }
  }

  /// Add new reminder time
  Future<void> addReminder({required String label, required int hour, required int minute}) async {
    final newId = (DateTime.now().millisecondsSinceEpoch % 100000) + 1000;
    _reminders.add(ReminderItem(
      id: newId,
      label: label,
      hour: hour,
      minute: minute,
      isEnabled: true,
    ));
    notifyListeners();
    await _saveAndRescheduleReminders();
  }

  /// Delete reminder
  Future<void> deleteReminder(int reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
    notifyListeners();
    await _saveAndRescheduleReminders();
  }

  Future<void> _saveAndRescheduleReminders() async {
    String? hint;
    if (_todaysPractice.isNotEmpty) {
      final uncompleted = _todaysPractice.where((p) => !p.isCompleted).toList();
      if (uncompleted.isNotEmpty) {
        hint = '${uncompleted.first.roadmapName}: ${uncompleted.first.topicName}';
      }
    }
    await _notificationService.saveReminders(
      _reminders,
      masterEnabled: _masterNotificationsEnabled,
      customTopicHint: hint,
      currentStreak: currentStreak,
    );
  }

  /// Send an immediate test notification to confirm it works on user's device
  Future<void> sendTestNotification() async {
    String? hint;
    if (_todaysPractice.isNotEmpty) {
      final uncompleted = _todaysPractice.where((p) => !p.isCompleted).toList();
      if (uncompleted.isNotEmpty) {
        hint = '${uncompleted.first.roadmapName}: ${uncompleted.first.topicName}';
      }
    }
    final streak = currentStreak;
    final streakText = streak > 0 ? ' 🔥 Keep your $streak-day streak alive!' : '';
    await _notificationService.sendTestNotification(
      customTitle: 'Practice Reminder 🎯',
      customBody: hint != null
          ? 'Today\'s focus: $hint.$streakText'
          : 'Ready for today\'s practice? Complete your checkpoints today!$streakText',
    );
  }

  /// Request notification permission on Android 13+
  Future<bool> requestNotificationPermissions() async {
    return await _notificationService.requestPermissions();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
