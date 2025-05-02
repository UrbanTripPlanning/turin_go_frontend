import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/road.dart';
import 'notification_service.dart';

class TripUpdateService {
  static final TripUpdateService _instance = TripUpdateService._internal();

  factory TripUpdateService() => _instance;

  TripUpdateService._internal();

  String? _userId;
  bool _notificationsEnabled = false;
  Timer? _periodicTimer;
  void Function(int)? _onNewMessage;

  void initialize({
    required String userId,
    required bool notificationsEnabled,
    void Function(int)? onNewMessage,
  }) {
    print('TripUpdateService initialized for $userId');
    _userId = userId;
    _notificationsEnabled = notificationsEnabled;
    _onNewMessage = onNewMessage;

    _checkAffectedTrips(); // First check
    _startTimer();         // Start loop
  }

  void _startTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAffectedTrips());
  }

  void stop() {
    _periodicTimer?.cancel();
  }

  Future<void> _checkAffectedTrips() async {
    if (_userId == null || !_notificationsEnabled) return;

    try {
      print('🔎 Checking for affected trips...');
      final result = await RoadApi.afftectedRoute(userId: _userId!);
      final List<dynamic> affectedTrips = result['data'] ?? [];

      if (affectedTrips.isEmpty) {
        print('✅ No affected trips found.');
        return;
      }

      print('🛑 Found ${affectedTrips.length} affected trips');

      final prefs = await SharedPreferences.getInstance();
      final List<String> existing = prefs.getStringList('tripMessages') ?? [];
      final List<String> tripEvents = prefs.getStringList('trip_events') ?? [];
      final Set<String> storedPlanIds = tripEvents.map((e) => json.decode(e)['plan_id'] as String).toSet();
      final List<String> notifiedPlanIds = prefs.getStringList('notified_plan_ids') ?? [];

      for (var trip in affectedTrips) {
        final dst = trip['dst_name'] ?? 'your destination';
        final duration = trip['spend_time'];
        final oldDuration = trip['old_spend_time'];
        final planId = trip['plan_id'];

        if (notifiedPlanIds.contains(planId)) {
          continue; // Skip already notified plans
        }

        String message;
        if (oldDuration > duration) {
          final diff = oldDuration - duration;
          message = 'Good news! Trip to $dst is now $duration min (decreased by $diff min)';
        } else if (duration > oldDuration) {
          final diff = duration - oldDuration;
          message = 'Hurry up! Trip to $dst increased to $duration min (up by $diff min)';
        } else {
          continue;
        }

        await NotificationService.showNotification(
          id: planId.hashCode,
          title: 'Trip Update',
          body: message,
        );

        // Save planId to prevent repeated notifications
        notifiedPlanIds.add(planId);

        // Save event for message box
        final event = {
          'plan_id': planId,
          'dst_name': dst,
          'spend_time': duration,
          'text': message,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        };
        tripEvents.add(json.encode(event));
      }

      await prefs.setStringList('tripMessages', existing);
      await prefs.setStringList('trip_events', tripEvents);
      await prefs.setStringList('notified_plan_ids', notifiedPlanIds);
      _onNewMessage?.call(existing.length);
    } catch (e) {
      print('⚠️ Error while checking affected trips: $e');
    }
  }
}

