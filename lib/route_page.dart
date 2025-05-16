import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/road.dart';
import 'package:turin_go_frontend/search_page.dart';
import 'package:turin_go_frontend/saved_page.dart';
import 'package:turin_go_frontend/map_picker_page.dart';
import 'package:turin_go_frontend/main.dart';

enum TimeSelectionMode { leaveNow, departAt, arriveBy }
enum RouteMode { walking, driving, cycling }

class RoutePage extends StatefulWidget {
  final String startName;
  final String endName;
  final List<double> startCoord;
  final List<double> endCoord;
  final String? planId;
  final int? routeMode;
  final int? timeMode;
  final int? startAt;
  final int? endAt;

  RoutePage({
    required this.startName,
    required this.endName,
    required this.startCoord,
    required this.endCoord,
    this.planId,
    this.routeMode,
    this.timeMode,
    this.startAt,
    this.endAt,
  });

  @override
  RoutePageState createState() => RoutePageState();
}

class RoutePageState extends State<RoutePage> {
  String? userId;
  List<LatLng> walkingRoutePoints = [];
  List<LatLng> drivingRoutePoints = [];
  List<LatLng> cyclingRoutePoints = [];
  late RouteMode _routeMode;

  List<LatLng> get currentRoutePoints {
    switch (_routeMode) {
      case RouteMode.walking:
        return walkingRoutePoints;
      case RouteMode.driving:
        return drivingRoutePoints;
      case RouteMode.cycling:
        return cyclingRoutePoints;
    }
  }

  bool get _hasRoute => currentRoutePoints.isNotEmpty;
  bool isLoading = false;
  bool isSaved = false;
  bool isSaving = false;
  String? errorMessage;
  String? walkingRouteInfo;
  String? drivingRouteInfo;
  String? cyclingRouteInfo;
  int walkingMinutes = 0;
  int drivingMinutes = 0;
  int cyclingMinutes = 0;

  String? get currentRouteInfo {
    switch (_routeMode) {
      case RouteMode.walking:
        return walkingRouteInfo;
      case RouteMode.driving:
        return drivingRouteInfo;
      case RouteMode.cycling:
        return cyclingRouteInfo;
    }
  }

  MapController mapController = MapController();
  late DateTime selectedDateTime;
  late TimeSelectionMode timeMode;
  late String startNameLocal;
  late List<double> startCoordLocal;
  late String endNameLocal;
  late List<double> endCoordLocal;

  @override
  void initState() {
    super.initState();
    _routeMode = RouteMode.values[widget.routeMode ?? 0];
    timeMode = TimeSelectionMode.values[widget.timeMode ?? 0];
    startNameLocal = widget.startName;
    startCoordLocal = widget.startCoord;
    endNameLocal = widget.endName;
    endCoordLocal = widget.endCoord;

    switch (timeMode) {
      case TimeSelectionMode.leaveNow:
        selectedDateTime = DateTime.now();
        break;
      case TimeSelectionMode.arriveBy:
        selectedDateTime = DateTime.fromMillisecondsSinceEpoch((widget.endAt ?? 0) * 1000);
        break;
      case TimeSelectionMode.departAt:
        selectedDateTime = DateTime.fromMillisecondsSinceEpoch((widget.startAt ?? 0) * 1000);
        break;
    }

    _searchRoute();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _searchRoute() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await RoadApi.searchRoute(
        start: startCoordLocal,
        end: endCoordLocal,
        startAt: timeMode == TimeSelectionMode.departAt ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
        endAt: timeMode == TimeSelectionMode.arriveBy ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
      );

      setState(() {
        Map walkingData = result['data']['walking'];
        Map drivingData = result['data']['driving'];
        Map cyclingData = result['data']['cycling'];

        walkingRoutePoints = List<LatLng>.from(walkingData['routes'].map((c) => LatLng(c[1], c[0])));
        drivingRoutePoints = List<LatLng>.from(drivingData['routes'].map((c) => LatLng(c[1], c[0])));
        cyclingRoutePoints = List<LatLng>.from(cyclingData['routes'].map((c) => LatLng(c[1], c[0])));

        walkingMinutes = walkingData['times'];
        drivingMinutes = drivingData['times'];
        cyclingMinutes = cyclingData['times'];

        walkingRouteInfo = "${walkingMinutes} min (${_formatDistance(walkingData['distances'])})";
        drivingRouteInfo = "${drivingMinutes} min (${_formatDistance(drivingData['distances'])})";
        cyclingRouteInfo = "${cyclingMinutes} min (${_formatDistance(cyclingData['distances'])})";

        isSaved = false;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load route: ${e.toString()}';
        isLoading = false;
      });
    }
  }
  void _toggleMode(RouteMode mode) {
    setState(() => _routeMode = mode);
  }

  String _formatDistance(dynamic distanceMeters) {
    if (distanceMeters < 1000) return "$distanceMeters m";
    return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
  }

  LatLng _calculateCenter() {
    if (currentRoutePoints.isEmpty) return LatLng(45.06288, 7.66277);
    double lat = 0, lng = 0;
    for (var p in currentRoutePoints) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / currentRoutePoints.length, lng / currentRoutePoints.length);
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() {
        selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          selectedDateTime.hour,
          selectedDateTime.minute,
        );
      });
      _searchRoute();
    }
  }

  void _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        selectedDateTime = DateTime(
          selectedDateTime.year,
          selectedDateTime.month,
          selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
      _searchRoute();
    }
  }




  void _exchangePoints() {
    setState(() {
      final tmpName = startNameLocal;
      final tmpCoord = startCoordLocal;
      startNameLocal = endNameLocal;
      startCoordLocal = endCoordLocal;
      endNameLocal = tmpName;
      endCoordLocal = tmpCoord;
    });
    _searchRoute();
  }

  void _saveRoutePlan() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    final tripData = {
      'plan_id': widget.planId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'src_name': startNameLocal,
      'dst_name': endNameLocal,
      'src_loc': startCoordLocal,
      'dst_loc': endCoordLocal,
      'spend_time': _getCurrentMinutes(),
      'time_mode': timeMode.index,
      'start_at': timeMode == TimeSelectionMode.departAt ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : 0,
      'end_at': timeMode == TimeSelectionMode.arriveBy ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : 0,
      'route_mode': _routeMode.index,
    };

    if (userId == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> savedPlans = prefs.getStringList('savedPlans') ?? [];
      savedPlans.add(json.encode(tripData));
      await prefs.setStringList('savedPlans', savedPlans);
      setState(() {
        isSaved = true;
        isSaving = false;
      });
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPage()));
    } else {
      try {
        final result = await RoadApi.saveRoute(
          planId: widget.planId ?? '',
          userId: userId!,
          start: startCoordLocal,
          end: endCoordLocal,
          spendTime: _getCurrentMinutes(),
          timeMode: timeMode.index,
          startName: startNameLocal,
          endName: endNameLocal,
          routeMode: _routeMode.index,
          startAt: timeMode == TimeSelectionMode.departAt
              ? selectedDateTime.millisecondsSinceEpoch ~/ 1000
              : 0,
          endAt: timeMode == TimeSelectionMode.arriveBy
              ? selectedDateTime.millisecondsSinceEpoch ~/ 1000
              : 0,
        );


        setState(() {
          isSaved = result['data'] == null;
          isSaving = false;
        });
        if (isSaved) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPage()));
        }
      } catch (e) {
        setState(() {
          errorMessage = 'Failed to save route plan: ${e.toString()}';
          isSaving = false;
        });
      }
    }
  }

  int _getCurrentMinutes() {
    switch (_routeMode) {
      case RouteMode.walking:
        return walkingMinutes;
      case RouteMode.driving:
        return drivingMinutes;
      case RouteMode.cycling:
        return cyclingMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFB3E5FC),
        elevation: 0,
        title: const Text('Route Planner', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_vert),
            onPressed: _exchangePoints,
            tooltip: "Swap start and end",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                buildInputRow("From:", startNameLocal, true),
                SizedBox(height: 10),
                buildInputRow("To:", endNameLocal, false),
                SizedBox(height: 10),
                buildTimeSelector(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Visibility(
                      visible: timeMode != TimeSelectionMode.leaveNow,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: ElevatedButton.icon(
                        onPressed: isSaved || isSaving ? null : _saveRoutePlan,
                        icon: Icon(Icons.save),
                        label: Text(isSaved ? "Saved" : "Save"),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.directions_walk, color: _routeMode == RouteMode.walking ? Colors.blue : Colors.grey),
                          onPressed: () => _toggleMode(RouteMode.walking),
                        ),
                        IconButton(
                          icon: Icon(Icons.directions_car, color: _routeMode == RouteMode.driving ? Colors.blue : Colors.grey),
                          onPressed: () => _toggleMode(RouteMode.driving),
                        ),
                        IconButton(
                          icon: Icon(Icons.directions_bike, color: _routeMode == RouteMode.cycling ? Colors.blue : Colors.grey),
                          onPressed: () => _toggleMode(RouteMode.cycling),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLoading)
            Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(child: Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red))))
          else
            Expanded(
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(center: _calculateCenter(), zoom: 14.0),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  if (_hasRoute)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: currentRoutePoints,
                          strokeWidth: 4.0,
                          color: _routeMode == RouteMode.walking
                              ? Colors.green
                              : _routeMode == RouteMode.cycling
                              ? Colors.orange
                              : Colors.blue,
                        ),
                      ],
                    ),
                  if (_hasRoute)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: currentRoutePoints.first,
                          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                        ),
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: currentRoutePoints.last,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(currentRouteInfo ?? "", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget buildInputRow(String label, String value, bool isStart) {
    return Row(
      children: [
        Text(label),
        SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SearchPage(isSelectingStartPoint: isStart)),
              );
              if (result != null) {
                setState(() {
                  if (isStart) {
                    startNameLocal = result['name_en'];
                    startCoordLocal = [result['Longitude'], result['Latitude']];
                  } else {
                    endNameLocal = result['name_en'];
                    endCoordLocal = [result['Longitude'], result['Latitude']];
                  }
                });
                _searchRoute();
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(value),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTimeSelector() {
    return Row(
      children: [
        DropdownButton<TimeSelectionMode>(
          value: timeMode,
          items: const [
            DropdownMenuItem(value: TimeSelectionMode.leaveNow, child: Text("Leave Now")),
            DropdownMenuItem(value: TimeSelectionMode.departAt, child: Text("Depart at")),
            DropdownMenuItem(value: TimeSelectionMode.arriveBy, child: Text("Arrive by")),
          ],
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => timeMode = newValue);
              _searchRoute();
            }
          },
        ),
        if (timeMode != TimeSelectionMode.leaveNow) ...[
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _showDatePicker,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              "${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')}",
            ),
          ),
          TextButton.icon(
            onPressed: _showTimePicker,
            icon: const Icon(Icons.access_time),
            label: Text(
              "${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}",
            ),
          ),
        ]
      ],
    );
  }
}