import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_page.dart';
import 'api/map.dart';
import 'dart:convert';

class TrafficPoint {
  final LatLng start;
  final LatLng end;
  final double flow;

  TrafficPoint(this.start, this.end, this.flow);
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>> roadData;
  late Future<List<TrafficPoint>> trafficData;
  LatLng? _currentPosition;
  static const String _locationKey = 'user_location';
  MapController mapController = MapController();
  bool _isMapMoving = false;
  List<Polyline> _trafficPolylines = [];

  @override
  void initState() {
    super.initState();
    trafficData = fetchTrafficData().then((points) {
      _updateTrafficPolylines(points);
      return points;
    });
    _determinePosition();
  }

  void _updateTrafficPolylines(List<TrafficPoint> points) {
    _trafficPolylines = points.map((point) => Polyline(
      points: [point.start, point.end],
      strokeWidth: 3.0,
      color: getColorWithFlowRate(point.flow).withOpacity(0.7),
      isDotted: false,
    )).toList();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled. Please enable them in your device settings.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    } 

    Position position = await Geolocator.getCurrentPosition();
    final location = LatLng(position.latitude, position.longitude);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, json.encode({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));

    setState(() {
      _currentPosition = location;
    });
  }

  bool showTraffic = false;
  final LatLng _initialPosition = LatLng(45.06288, 7.66277);

  final String normalTileUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";

  Future<List<TrafficPoint>> fetchTrafficData() async {
    List<TrafficPoint> result = [];
    final response = await MapApi.getTraffic();
    if (response['code'] == 200) {
      for (var item in response['data']) {
        var start = item['start'];
        var end = item['end'];
        result.add(TrafficPoint(LatLng(start[1], start[0]), LatLng(end[1], end[0]), item['flow_rate']));
      }
    }
    return Future.value(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: _currentPosition ?? _initialPosition,
              zoom: 15.0,
              maxZoom: 18.0,
              minZoom: 10.0,
              keepAlive: true,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _isMapMoving = true);
                  Future.delayed(Duration(milliseconds: 150), () {
                    if (mounted) {
                      setState(() => _isMapMoving = false);
                    }
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: normalTileUrl,
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.turinGoFrontend',
              ),
              if (showTraffic && !_isMapMoving)
                PolylineLayer(
                  polylines: _trafficPolylines,
                  polylineCulling: true,
                ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _currentPosition!,
                      builder: (ctx) => Icon(Icons.location_on, color: Colors.blue, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
              )
            ]
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchPage()),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(230),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.white),
                    SizedBox(width: 10),
                    Text("Search here", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.traffic),
        onPressed: () {
          setState(() {
            showTraffic = !showTraffic;
          });
        },
      ),
    );
  }

  Color getColorWithFlowRate(double flow) {
    if (flow > 0.75) {
      return Colors.green;
    } else if (flow > 0.4) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }
}
