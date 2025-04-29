import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/road.dart';
import 'route_page.dart';
import 'notification_service.dart';
import 'dart:async';
import 'dart:convert';

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
      _scheduleDailyCheck(); // reschedule next day
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
    if (userId == null) return;
    if (!notificationsEnabled) return;

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
              body: 'Trip to ${oldTrip['dst_name']} updated: $oldDuration min ➔ $newDuration min',
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
      appBar: AppBar(title: Text('Saved Trips')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)))
          : ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: planList.length,
        itemBuilder: (context, index) {
          final trip = planList[index];
          final leaveTime = _getLeaveTime(trip);
          return Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text('To: ${trip['dst_name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave by ${leaveTime[0]} ${leaveTime[1]}'),
                    Text('From ${trip['src_name']} To ${trip['dst_name']}'),
                    Text('Duration: ${trip['spend_time']} min  By ${trip['route_mode'] == 0 ? 'walking' : 'driving'}'),
                  ],
                ),
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
          );
        },
      ),
    );
  }
}

