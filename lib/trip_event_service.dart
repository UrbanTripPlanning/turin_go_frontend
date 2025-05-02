// File: trip_event_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/road.dart';
import 'notification_service.dart';

class TripEventService {
  static final TripEventService _instance = TripEventService._internal();
  factory TripEventService() => _instance;
  TripEventService._internal();

  String? _userId;
  bool _notificationsEnabled = false;
  Timer? _timer;

  void initialize({required String userId, required bool notificationsEnabled}) {
    _userId = userId;
    _notificationsEnabled = notificationsEnabled;
    _checkForEvents();
    _timer?.cancel();
    _timer = Timer.periodic(Duration(minutes: 5), (_) => _checkForEvents());
  }

  Future<void> _checkForEvents() async {
    if (_userId == null || !_notificationsEnabled) return;
    try {
      final result = await RoadApi.afftectedRoute(userId: _userId!);
      final List<dynamic> affected = result['data'] ?? [];
      if (affected.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      List<String> storedEvents = prefs.getStringList('trip_events') ?? [];
      final seenIds = storedEvents.map((e) => json.decode(e)['plan_id']).toSet();

      for (var trip in affected) {
        final planId = trip['plan_id'];
        if (!seenIds.contains(planId)) {
          final newEvent = {
            'plan_id': planId,
            'dst_name': trip['dst_name'],
            'spend_time': trip['spend_time'],
            'timestamp': DateTime.now().toIso8601String(),
            'read': false,
          };
          storedEvents.add(json.encode(newEvent));

          // Notify only if app is in background
          if (!kDebugMode) {
            await NotificationService.showNotification(
              id: planId.hashCode,
              title: 'Trip Update',
              body: 'Trip to ${trip['dst_name']} is now ${trip['spend_time']} minutes',
            );
          }
        }
      }

      await prefs.setStringList('trip_events', storedEvents);
    } catch (e) {
      debugPrint('Error fetching trip events: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> raw = prefs.getStringList('trip_events') ?? [];
    return raw.map((e) => json.decode(e)).cast<Map<String, dynamic>>().toList();
  }

  Future<int> getUnreadCount() async {
    final events = await getEvents();
    return events.where((e) => e['read'] == false).length;
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> raw = prefs.getStringList('trip_events') ?? [];
    final updated = raw.map((e) {
      final obj = json.decode(e);
      obj['read'] = true;
      return json.encode(obj);
    }).toList();
    await prefs.setStringList('trip_events', updated);
  }
}

