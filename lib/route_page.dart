import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/road.dart';
import 'package:turin_go_frontend/search_page.dart';
import 'package:turin_go_frontend/saved_page.dart'; // <- added import
import 'package:turin_go_frontend/map_picker_page.dart';

enum TimeSelectionMode { leaveNow, departAt, arriveBy }

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
  bool get _hasRoute => currentRoutePoints.isNotEmpty;
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
  late String endNameLocal;
  late List<double> endCoordLocal;

  @override
  void initState() {
    super.initState();
    _isWalking = widget.routeMode == null ? true : widget.routeMode == 0;
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

        walkingRoutePoints = List<LatLng>.from(
          walkingData['routes'].map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())),
        );

        drivingRoutePoints = List<LatLng>.from(
          drivingData['routes'].map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble())),
        );

        walkingMinutes = walkingData['times'];
        drivingMinutes = drivingData['times'];

        walkingRouteInfo = "${walkingMinutes} min (${_formatDistance(walkingData['distances'])})";
        drivingRouteInfo = "${drivingMinutes} min (${_formatDistance(drivingData['distances'])})";

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
  void _saveRoutePlan() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    if (userId == null) {
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> savedPlans = prefs.getStringList('savedPlans') ?? [];

        final newPlan = {
          'plan_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'src_name': startNameLocal,
          'dst_name': endNameLocal,
          'src_loc': startCoordLocal,
          'dst_loc': endCoordLocal,
          'spend_time': _isWalking ? walkingMinutes : drivingMinutes,
          'time_mode': timeMode.index,
          'start_at': timeMode == TimeSelectionMode.departAt
              ? selectedDateTime.millisecondsSinceEpoch ~/ 1000
              : 0,
          'end_at': timeMode == TimeSelectionMode.arriveBy
              ? selectedDateTime.millisecondsSinceEpoch ~/ 1000
              : 0,
          'route_mode': _isWalking ? 0 : 1,
        };

        savedPlans.add(json.encode(newPlan));
        await prefs.setStringList('savedPlans', savedPlans);

        setState(() {
          isSaved = true;
          isSaving = false;
        });

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SavedPage()));
      } catch (e) {
        setState(() {
          errorMessage = 'Failed to save trip locally: ${e.toString()}';
          isSaving = false;
        });
      }
      return;
    }

    try {
      final result = await RoadApi.saveRoute(
        planId: widget.planId ?? '',
        userId: userId ?? '',
        start: startCoordLocal,
        end: endCoordLocal,
        spendTime: _isWalking ? walkingMinutes : drivingMinutes,
        timeMode: timeMode.index,
        startName: startNameLocal,
        endName: endNameLocal,
        routeMode: _isWalking ? 0 : 1,
        startAt: timeMode == TimeSelectionMode.departAt
            ? selectedDateTime.millisecondsSinceEpoch ~/ 1000
            : null,
        endAt: timeMode == TimeSelectionMode.arriveBy
            ? selectedDateTime.millisecondsSinceEpoch ~/ 1000
            : null,
      );

      setState(() {
        isSaving = false;
        if (result['data'] == null) {
          isSaved = true;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SavedPage()));
        } else {
          errorMessage = 'Failed to save route plan: ${result['data']}';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to save route plan: ${e.toString()}';
        isSaving = false;
      });
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

  void _toggleMode(bool walkSelected) {
    setState(() => _isWalking = walkSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFB3E5FC),
        elevation: 0,
        title: const Text('Route Planner', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_vert, color: Colors.black87),
            tooltip: "Exchange start & destination",
            onPressed: _exchangePoints,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                buildInputRow("From:", startNameLocal, true),
                const SizedBox(height: 10),
                buildInputRow("To:", endNameLocal, false),
                const SizedBox(height: 10),
                buildTimeSelector(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Visibility(
                        visible: timeMode != TimeSelectionMode.leaveNow,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: ElevatedButton.icon(
                          onPressed: isSaving || isSaved ? null : _saveRoutePlan,
                          icon: const Icon(Icons.save),
                          label: Text(isSaved ? "Saved" : "Save"),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.directions_walk, color: _isWalking ? Colors.blue : Colors.black26),
                          onPressed: () => _toggleMode(true),
                        ),
                        IconButton(
                          icon: Icon(Icons.directions_car, color: !_isWalking ? Colors.blue : Colors.black26),
                          onPressed: () => _toggleMode(false),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(child: Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red))))
          else ...[
              Expanded(
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: _calculateCenter(),
                    zoom: 14.0,
                  ),
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
                            color: _isWalking ? Colors.green : Colors.blue,
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
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Text(currentRouteInfo ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              )
            ]
        ],
      ),
    );
  }

  Widget buildInputRow(String label, String value, bool isStart) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final selectedPlace = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(isSelectingStartPoint: isStart),
                ),
              );

              if (selectedPlace != null) {
                setState(() {
                  if (isStart) {
                    startNameLocal = selectedPlace['name_en'];
                    startCoordLocal = [
                      selectedPlace['Longitude'],
                      selectedPlace['Latitude'],
                    ];
                  } else {
                    endNameLocal = selectedPlace['name_en'];
                    endCoordLocal = [
                      selectedPlace['Longitude'],
                      selectedPlace['Latitude'],
                    ];
                  }
                });
                _searchRoute();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(value, style: const TextStyle(fontSize: 16)),
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
            label: Text("${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')}"),
          ),
          TextButton.icon(
            onPressed: _showTimePicker,
            icon: const Icon(Icons.access_time),
            label: Text("${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}"),
          ),
        ],
      ],
    );
  }
}

