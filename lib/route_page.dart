import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'api/road.dart';
import 'search_page.dart';
import 'dart:convert';

enum TimeSelectionMode {
  leaveNow,
  departAt,
  arriveBy,
}

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
  late bool _isWalking;
  List<LatLng> get currentRoutePoints => _isWalking ? walkingRoutePoints : drivingRoutePoints;
  bool isLoading = false;
  bool isSaved = false;
  bool isSaving = false;
  String? errorMessage;
  String? walkingRouteInfo;
  String? drivingRouteInfo;
  int drivingMinutes = 0;
  int walkingMinutes = 0;
  String? get currentRouteInfo => _isWalking ? walkingRouteInfo : drivingRouteInfo;
  MapController mapController = MapController();
  late DateTime selectedDateTime;
  late TimeSelectionMode timeMode;

  late String startNameLocal;
  late List<double> startCoordLocal;

  @override
  void initState() {
    super.initState();
    _isWalking = widget.routeMode == null ? true : widget.routeMode == 0;
    timeMode = TimeSelectionMode.values[widget.timeMode ?? 0];
    startNameLocal = widget.startName;
    startCoordLocal = widget.startCoord;

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
        end: widget.endCoord,
        startAt: timeMode == TimeSelectionMode.departAt ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
        endAt: timeMode == TimeSelectionMode.arriveBy ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
      );

      setState(() {
        Map walkingData = result['data']['walking'];
        Map drivingData = result['data']['driving'];

        walkingRoutePoints = List<LatLng>.from(
          walkingData['routes'].map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())),
        );

        drivingRoutePoints = List<LatLng>.from(
          drivingData['routes'].map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())),
        );

        walkingMinutes = walkingData['times'];
        drivingMinutes = drivingData['times'];

        walkingRouteInfo = "$walkingMinutes min (${_formatDistance(walkingData['distances'])})";
        drivingRouteInfo = "$drivingMinutes min (${_formatDistance(drivingData['distances'])})";

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

  String _formatDistance(dynamic distanceMeters) {
    if (distanceMeters < 1000) {
      return "$distanceMeters m";
    } else {
      return "${(distanceMeters / 1000).toStringAsFixed(1)} km";
    }
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 7)),
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

  void _saveRoutePlan() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    if (userId == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> savedPlans = prefs.getStringList('savedPlans')?.map((e) => Map<String, dynamic>.from(json.decode(e))).toList() ?? [];

      savedPlans.add({
        'plan_id': 'local_',
        'src_loc': startCoordLocal,
        'dst_loc': widget.endCoord,
        'spend_time': _isWalking ? walkingMinutes : drivingMinutes,
        'time_mode': timeMode.index,
        'src_name': startNameLocal,
        'dst_name': widget.endName,
        'route_mode': _isWalking ? 0 : 1,
        'start_at': timeMode == TimeSelectionMode.departAt ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
        'end_at': timeMode == TimeSelectionMode.arriveBy ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
      });

      await prefs.setStringList('savedPlans', savedPlans.map((e) => json.encode(e)).toList());
      setState(() {
        isSaving = false;
        isSaved = true;
      });
      return;
    }

    try {
      final result = await RoadApi.saveRoute(
        planId: widget.planId ?? '',
        userId: userId!,
        start: startCoordLocal,
        end: widget.endCoord,
        spendTime: _isWalking ? walkingMinutes : drivingMinutes,
        timeMode: timeMode.index,
        startName: startNameLocal,
        endName: widget.endName,
        routeMode: _isWalking ? 0 : 1,
        startAt: timeMode == TimeSelectionMode.departAt ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
        endAt: timeMode == TimeSelectionMode.arriveBy ? selectedDateTime.millisecondsSinceEpoch ~/ 1000 : null,
      );

      setState(() {
        isSaving = false;
        if (result['data'] == null) {
          isSaved = true;
        } else {
          errorMessage = 'Failed to save route plan.';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to save route plan: ${e.toString()}';
        isSaving = false;
      });
    }
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

  double _calculateZoom() {
    if (currentRoutePoints.length < 2) return 13.0;
    final distance = Distance();
    double maxDist = 0;
    for (int i = 0; i < currentRoutePoints.length - 1; i++) {
      double d = distance.as(LengthUnit.Kilometer, currentRoutePoints[i], currentRoutePoints[i + 1]);
      if (d > maxDist) maxDist = d;
    }
    if (maxDist > 10) return 11.0;
    if (maxDist > 5) return 12.0;
    if (maxDist > 2) return 13.0;
    if (maxDist > 1) return 14.0;
    return 15.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Route Planner"),
        actions: [
          IconButton(
            icon: Icon(_isWalking ? Icons.directions_walk : Icons.directions_car),
            onPressed: () {
              setState(() {
                _isWalking = !_isWalking;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // (inputs like From, To, Date/Time Selection)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: buildInputs(),
          ),
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)))
          else
            Expanded(
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: _calculateCenter(),
                  zoom: _calculateZoom(),
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  if (currentRoutePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: currentRoutePoints,
                          strokeWidth: 4.0,
                          color: _isWalking ? Colors.green : Colors.blue,
                        ),
                      ],
                    ),
                  if (currentRoutePoints.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: currentRoutePoints.first,
                          child: Icon(Icons.location_on, color: Colors.green, size: 40),
                        ),
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: currentRoutePoints.last,
                          child: Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              currentRouteInfo ?? "Loading route info...",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputs() {
    return Column(
      children: [
        Row(
          children: [
            Text("From: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final selectedPlace = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchPage(isSelectingStartPoint: true),
                    ),
                  );
                  if (selectedPlace != null) {
                    setState(() {
                      startNameLocal = selectedPlace['name_en'];
                      startCoordLocal = [selectedPlace['Longitude'], selectedPlace['Latitude']];
                    });
                    _searchRoute();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(startNameLocal, style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text("To: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: widget.endName,
                  border: OutlineInputBorder(),
                ),
                enabled: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        buildTimeSelector(),
      ],
    );
  }

  Widget buildTimeSelector() {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: DropdownButton<TimeSelectionMode>(
            value: timeMode,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: TimeSelectionMode.leaveNow,
                child: Text("Leave Now"),
              ),
              DropdownMenuItem(
                value: TimeSelectionMode.departAt,
                child: Text("Depart at"),
              ),
              DropdownMenuItem(
                value: TimeSelectionMode.arriveBy,
                child: Text("Arrive by"),
              ),
            ],
            onChanged: (TimeSelectionMode? newValue) {
              if (newValue != null) {
                setState(() {
                  timeMode = newValue;
                });
                _searchRoute();
              }
            },
          ),
        ),
        if (timeMode != TimeSelectionMode.leaveNow) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _showDatePicker,
                  icon: Icon(Icons.calendar_today),
                  label: Text("${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')}"),
                ),
                TextButton.icon(
                  onPressed: _showTimePicker,
                  icon: Icon(Icons.access_time),
                  label: Text("${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}"),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        if (timeMode != TimeSelectionMode.leaveNow && !isSaved)
          ElevatedButton(
            onPressed: isSaving ? null : _saveRoutePlan,
            child: Text("Save"),
          ),
        const SizedBox(width: 20),
      ],
    );
  }
}

