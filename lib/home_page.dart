import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'search_page.dart';
import 'route_page.dart';
import 'api/map.dart';
import 'dart:convert';
import 'platform/web_only.dart' if (dart.library.io) 'platform/mobile_only.dart';

const LatLng politecnicoCoord = LatLng(45.062331, 7.662690);

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
  late Future<List<TrafficPoint>> trafficData;
  LatLng? _currentPosition;
  bool _usingFallback = false;
  static const String _locationKey = 'user_location';
  MapController mapController = MapController();
  bool _isMapMoving = false;
  List<Polyline> _trafficPolylines = [];
  LatLng? _pinnedPoint;
  bool _showPin = false;

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
    try {
      if (kIsWeb) {
        final location = await getWebPosition();
        if (location != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_locationKey, json.encode({
            'latitude': location.latitude,
            'longitude': location.longitude,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }));
          setState(() {
            _currentPosition = location;
            _usingFallback = false;
          });
          return;
        } else {
          throw Exception("Web location null");
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("Service disabled");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception("Permission denied");
        }
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
        _usingFallback = false;
      });
    } catch (e) {
      print("Location fallback to politecnico: $e");
      setState(() {
        _currentPosition = politecnicoCoord;
        _usingFallback = true;
      });
    }
  }

  final LatLng _initialPosition = LatLng(45.06288, 7.66277);
  bool showTraffic = false;

  Future<List<TrafficPoint>> fetchTrafficData() async {
    List<TrafficPoint> result = [];
    final response = await MapApi.getTraffic();
    if (response['code'] == 200) {
      for (var item in response['data']) {
        var start = item['start'];
        var end = item['end'];
        result.add(TrafficPoint(
          LatLng(start[1], start[0]),
          LatLng(end[1], end[0]),
          item['flow_rate'],
        ));
      }
    }
    return result;
  }

  void _showDirectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 20),
          child: Wrap(
            children: [
              Center(
                child: Text(
                  "Navigate to pinned location?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.cancel),
                      label: Text("Cancel"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _showPin = false;
                          _pinnedPoint = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.directions),
                      label: Text("Direction"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_pinnedPoint != null) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoutePage(
                                startName: _usingFallback ? 'Politecnico' : 'Current Location',
                                endName: 'Pinned Location',
                                startCoord: [
                                  _currentPosition?.longitude ?? politecnicoCoord.longitude,
                                  _currentPosition?.latitude  ?? politecnicoCoord.latitude,
                                ],
                                endCoord: [
                                  _pinnedPoint!.longitude,
                                  _pinnedPoint!.latitude
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
              onTap: (_, latlng) {
                setState(() {
                  _pinnedPoint = latlng;
                  _showPin = true;
                });
                _showDirectionSheet();
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _isMapMoving = true);
                  Future.delayed(Duration(milliseconds: 150), () {
                    if (mounted) setState(() => _isMapMoving = false);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              if (showTraffic && !_isMapMoving)
                PolylineLayer(polylines: _trafficPolylines, polylineCulling: true),
              if (_currentPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: _currentPosition!,
                    child: Icon(Icons.location_on, color: Colors.blue, size: 40),
                  ),
                ]),
              if (_showPin && _pinnedPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: _pinnedPoint!,
                    child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                ]),
            ],
          ),

          // SEARCH BAR: now returns a place and immediately routes
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                final place = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchPage(isSelectingStartPoint: false),
                  ),
                );
                if (place != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoutePage(
                        startName: _usingFallback ? 'Politecnico' : 'Current Location',
                        endName: place['name_en'],
                        startCoord: [
                          _currentPosition?.longitude ?? politecnicoCoord.longitude,
                          _currentPosition?.latitude  ?? politecnicoCoord.latitude,
                        ],
                        endCoord: [
                          place['Longitude'],
                          place['Latitude'],
                        ],
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.black54),
                    SizedBox(width: 10),
                    Text("Search here", style: TextStyle(color: Colors.black87)),
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
    if (flow > 0.55) return Colors.green; // 30 / 50
    if (flow > 0.36) return Colors.yellow; // 18 / 50
    return Colors.red;
  }
}
