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
  List<LatLng> routePoints = [];
  bool isLoading = false;
  String? errorMessage;
  String? routeInfo;
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
        List routes = result['data'];
        routePoints = routes.map((coord) => 
          LatLng(coord[1].toDouble(), coord[0].toDouble())
        ).toList();

        routeInfo = "${result['duration']} min (${result['distance']} km)";
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
    if (routePoints.isEmpty) return LatLng(45.09298, 7.67773);
    
    double centerLat = 0;
    double centerLng = 0;
    
    for (var point in routePoints) {
      centerLat += point.latitude;
      centerLng += point.longitude;
    }
    
    return LatLng(
      centerLat / routePoints.length,
      centerLng / routePoints.length
    );
  }

  double _calculateZoom() {
    if (routePoints.length < 2) return 13.0;
    
    double maxDistance = 0;
    final distance = Distance();
    
    for (int i = 0; i < routePoints.length - 1; i++) {
      double d = distance.as(LengthUnit.Kilometer, routePoints[i], routePoints[i + 1]);
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
      appBar: AppBar(title: Text("Route Planner")),
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
                  if (routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  if (routePoints.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: routePoints.first,
                          builder: (ctx) => Icon(Icons.location_on, color: Colors.green, size: 40),
                        ),
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: routePoints.last,
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
                  routeInfo ?? "Loading route information...",
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
