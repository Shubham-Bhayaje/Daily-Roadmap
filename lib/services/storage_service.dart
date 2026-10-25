import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/roadmap.dart';

class StorageService {
  static const _roadmapsKey = 'roadmaps';
  static const _lastDateKey = 'last_advance_date';
  static const _completionDatesKey = 'completion_dates';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Roadmaps ───────────────────────────────────────────────────────────────

  /// Save all roadmaps to storage.
  Future<void> saveRoadmaps(List<Roadmap> roadmaps) async {
    final data = roadmaps.map((r) => r.toJson()).toList();
    await _prefs.setString(_roadmapsKey, jsonEncode(data));
  }

  /// Load all roadmaps from storage.
  List<Roadmap> loadRoadmaps() {
    final data = _prefs.getString(_roadmapsKey);
    if (data == null) return [];

    try {
      final List<dynamic> list = jsonDecode(data);
      return list
          .map((item) => Roadmap.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading roadmaps: $e');
      return [];
    }
  }

  // ── Day advancement ────────────────────────────────────────────────────────

  /// Get the last date topics were advanced.
  DateTime? getLastAdvanceDate() {
    final data = _prefs.getString(_lastDateKey);
    if (data == null) return null;
    return DateTime.tryParse(data);
  }

  /// Save the last advance date.
  Future<void> setLastAdvanceDate(DateTime date) async {
    await _prefs.setString(_lastDateKey, date.toIso8601String());
  }

  /// Remove a roadmap by ID.
  Future<void> removeRoadmap(String id, List<Roadmap> roadmaps) async {
    roadmaps.removeWhere((r) => r.id == id);
    await saveRoadmaps(roadmaps);
  }

  // ── Streak / completion tracking ───────────────────────────────────────────

  /// All dates (yyyy-MM-dd) on which user completed at least one topic.
  Set<String> getCompletionDates() {
    final data = _prefs.getStringList(_completionDatesKey);
    return data?.toSet() ?? {};
  }

  /// Record today (or any date) as a day with completions.
  Future<void> addCompletionDate(String dateKey) async {
    final dates = getCompletionDates();
    if (dates.add(dateKey)) {
      await _prefs.setStringList(_completionDatesKey, dates.toList());
    }
  }

  /// Remove a completion date (for undo).
  Future<void> removeCompletionDate(String dateKey) async {
    final dates = getCompletionDates();
    if (dates.remove(dateKey)) {
      await _prefs.setStringList(_completionDatesKey, dates.toList());
    }
  }
}
