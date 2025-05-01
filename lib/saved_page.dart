import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/road.dart';
import 'route_page.dart';
import 'notification_service.dart';

class SavedPage extends StatefulWidget {
  @override
  SavedPageState createState() => SavedPageState();
}

class SavedPageState extends State<SavedPage> {
  String? userId;
  List<Map<String, dynamic>> planList = [];
  bool isLoading = false;
  String? errorMessage;
  Timer? dailyTimer;
  List<Timer> tripTimers = [];
  bool notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    dailyTimer?.cancel();
    for (var timer in tripTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString('userId');
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
    _getPlanList();
  }

  Future<void> _getPlanList() async {
    if (!mounted) return;
    setState(() {
      planList = [];
      isLoading = true;
      errorMessage = null;
    });

    if (userId == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? savedPlans = prefs.getStringList('savedPlans');
      List<Map<String, dynamic>> plans = [];
      if (savedPlans != null) {
        for (String plan in savedPlans) {
          plans.add(Map<String, dynamic>.from(json.decode(plan)));
        }
      }

      setState(() {
        planList = plans;
        isLoading = false;
      });
      return;
    }

    try {
      final result = await RoadApi.listRoute(userId: userId ?? '');
      if (!mounted) return;
      setState(() {
        planList = List<Map<String, dynamic>>.from(result['data']);
        isLoading = false;
      });

      if (notificationsEnabled) {
        _scheduleDailyCheck();
        _scheduleTripChecks();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load route: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _scheduleDailyCheck() {
    dailyTimer?.cancel();
    final now = DateTime.now();
    final next9PM = DateTime(now.year, now.month, now.day, 21, 0);
    final diff = next9PM.isAfter(now) ? next9PM.difference(now) : next9PM.add(Duration(days: 1)).difference(now);

    dailyTimer = Timer(diff, () async {
      await _checkTripsForUpdate();
      _scheduleDailyCheck();
    });
  }

  void _scheduleTripChecks() {
    tripTimers.forEach((timer) => timer.cancel());
    tripTimers.clear();

    for (var trip in planList) {
      final durationMinutes = trip['spend_time'] ?? 0;
      final leaveTimestamp = (trip['time_mode'] == 1)
          ? trip['start_at'] * 1000
          : (trip['end_at'] - durationMinutes * 60) * 1000;

      final leaveTime = DateTime.fromMillisecondsSinceEpoch(leaveTimestamp);
      final checkTime = leaveTime.subtract(Duration(minutes: durationMinutes * 2));

      final now = DateTime.now();
      if (checkTime.isAfter(now)) {
        final timer = Timer(checkTime.difference(now), () async {
          await _checkTripsForUpdate();
        });
        tripTimers.add(timer);
      }
    }
  }

  Future<void> _checkTripsForUpdate() async {
    if (userId == null || !notificationsEnabled) return;

    try {
      final result = await RoadApi.listRoute(userId: userId ?? '');
      final latestTrips = List<Map<String, dynamic>>.from(result['data']);

      for (var oldTrip in planList) {
        final newTrip = latestTrips.firstWhere(
              (element) => element['plan_id'] == oldTrip['plan_id'],
          orElse: () => {},
        );

        if (newTrip.isNotEmpty) {
          final oldDuration = oldTrip['spend_time'];
          final newDuration = newTrip['spend_time'];

          if (oldDuration != newDuration) {
            await NotificationService.showNotification(
              id: oldTrip['plan_id'].hashCode,
              title: 'Trip Update',
              body: 'Trip to ${oldTrip['dst_name']} updated: ${oldDuration} min ➔ ${newDuration} min',
            );
          }
        }
      }
    } catch (e) {
      print('Error checking trips: $e');
    }
  }

  List _getLeaveTime(Map trip) {
    String dt;
    if (trip['time_mode'] == 1) {
      dt = DateTime.fromMillisecondsSinceEpoch(trip['start_at'] * 1000).toLocal().toString();
    } else {
      dt = DateTime.fromMillisecondsSinceEpoch((trip['end_at'] - trip['spend_time'] * 60) * 1000).toLocal().toString();
    }
    return [dt.split(' ')[0], dt.split(' ')[1].substring(0, 5)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            width: double.infinity,
            color: const Color(0xFFB3E5FC),
            child: const Center(
              child: Text(
                'Saved Trips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: planList.length,
              itemBuilder: (context, index) {
                final trip = planList[index];
                final leaveTime = _getLeaveTime(trip);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(
                        'To: ${trip['dst_name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('Leave by ${leaveTime[0]} ${leaveTime[1]}', style: const TextStyle(color: Colors.black54)),
                          Text('From ${trip['src_name']} To ${trip['dst_name']}', style: const TextStyle(color: Colors.black54)),
                          Text('Duration: ${trip['spend_time']} min  By ${trip['route_mode'] == 0 ? 'walking' : 'driving'}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Trip'),
                              content: const Text('Are you sure you want to delete this trip?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              if (userId == null) {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                List<String> savedPlans = prefs.getStringList('savedPlans') ?? [];
                                savedPlans.removeWhere((plan) {
                                  final map = json.decode(plan);
                                  return map['plan_id'] == trip['plan_id'];
                                });
                                await prefs.setStringList('savedPlans', savedPlans);
                                setState(() => planList.removeAt(index));
                              } else {
                                await RoadApi.deleteRoute(planId: trip['plan_id']);
                                setState(() => planList.removeAt(index));
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to delete trip: ${e.toString()}')),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutePage(
                              startName: trip['src_name'],
                              endName: trip['dst_name'],
                              startCoord: (trip['src_loc'] as List).map((e) => (e as num).toDouble()).toList(),
                              endCoord: (trip['dst_loc'] as List).map((e) => (e as num).toDouble()).toList(),
                              planId: trip['plan_id'],
                              routeMode: trip['route_mode'],
                              timeMode: trip['time_mode'],
                              startAt: trip['start_at'],
                              endAt: trip['end_at'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

