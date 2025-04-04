import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'api/road.dart';

class RoutePage extends StatefulWidget {
  final String startName;
  final String endName;
  final List<double> startCoord;
  final List<double> endCoord;

  RoutePage({
    required this.startName,
    required this.endName,
    required this.startCoord,
    required this.endCoord,
  });

  @override
  RoutePageState createState() => RoutePageState();
}

class RoutePageState extends State<RoutePage> {
  List<LatLng> walkingRoutePoints = [];
  List<LatLng> drivingRoutePoints = [];
  List<LatLng> get currentRoutePoints => _isWalking ? walkingRoutePoints : drivingRoutePoints;
  bool _isWalking = true;
  bool isLoading = false;
  String? errorMessage;
  String? walkingRouteInfo;
  String? drivingRouteInfo;
  String? get currentRouteInfo => _isWalking ? walkingRouteInfo : drivingRouteInfo;
  MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _searchRoute();
  }

  Future<void> _searchRoute() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await RoadApi.searchRoute(
        start: widget.startCoord,
        end: widget.endCoord,
      );

      setState(() {
        Map walkingData = result['data']['walking'];
        Map drivingData = result['data']['driving'];
        List walkingRoutes = walkingData['routes'];
        List drivingRoutes = drivingData['routes'];
        
        walkingRoutePoints = walkingRoutes.map((coord) => 
          LatLng(coord[1].toDouble(), coord[0].toDouble())
        ).toList();

        drivingRoutePoints = drivingRoutes.map((coord) => 
          LatLng(coord[1].toDouble(), coord[0].toDouble())
        ).toList();

        String walkingDistanceStr = "";
        if (walkingData['distances'] < 1000) {
          walkingDistanceStr = "${walkingData['distances']} m";
        } else {
          walkingDistanceStr = "${(walkingData['distances']/1000).toStringAsFixed(1)} km";
        }

        String drivingDistanceStr = "";
        if (drivingData['distances'] < 1000) {
          drivingDistanceStr = "${drivingData['distances']} m";
        } else {
          drivingDistanceStr = "${(drivingData['distances']/1000).toStringAsFixed(1)} km";
        }

        walkingRouteInfo = "${walkingData['times']} min ($walkingDistanceStr)";
        drivingRouteInfo = "${drivingData['times']} min ($drivingDistanceStr)";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load route: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  LatLng _calculateCenter() {
    if (currentRoutePoints.isEmpty) return LatLng(45.09298, 7.67773);
    
    double centerLat = 0;
    double centerLng = 0;
    
    for (var point in currentRoutePoints) {
      centerLat += point.latitude;
      centerLng += point.longitude;
    }
    
    return LatLng(
      centerLat / currentRoutePoints.length,
      centerLng / currentRoutePoints.length
    );
  }

  double _calculateZoom() {
    if (currentRoutePoints.length < 2) return 13.0;
    
    double maxDistance = 0;
    final distance = Distance();
    
    for (int i = 0; i < currentRoutePoints.length - 1; i++) {
      double d = distance.as(LengthUnit.Kilometer, currentRoutePoints[i], currentRoutePoints[i + 1]);
      maxDistance = maxDistance > d ? maxDistance : d;
    }

    if (maxDistance > 10) return 11.0;
    if (maxDistance > 5) return 12.0;
    if (maxDistance > 2) return 13.0;
    if (maxDistance > 1) return 14.0;
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
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text("From: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: widget.startName,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text("To: ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: widget.endName,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                          builder: (ctx) => Icon(Icons.location_on, color: Colors.green, size: 40),
                        ),
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: currentRoutePoints.last,
                          builder: (ctx) => Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  currentRouteInfo ?? "Loading route information...",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(onPressed: () {}, child: Text("Save")),
                    SizedBox(width: 10),
                    ElevatedButton(onPressed: () {}, child: Text("Add stops")),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
