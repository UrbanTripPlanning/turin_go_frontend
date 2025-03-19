import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'search_page.dart';
// import 'api/road.dart';
import 'api/map.dart';

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

  @override
  void initState() {
    super.initState();
    trafficData = fetchTrafficData();
    // RoadApi.searchRoute(start: '', end: '').then((response) => {
    //   if (response['code'] == 200) {
    //     print(response['data'])
    //   }
    // });
  }

  bool showTraffic = false;
  final LatLng _initialPosition = LatLng(45.06298, 7.67773);

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
            options: MapOptions(
              center: _initialPosition,
              zoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: normalTileUrl,
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.turinGoFrontend',
              ),
              if (showTraffic)
                FutureBuilder<List<TrafficPoint>>(
                  future: trafficData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No traffic data available'));
                    } else {
                      List<TrafficPoint> segments = snapshot.data!;
                      List<Polyline> polylines = segments.map((segment) {
                        return Polyline(
                          points: [segment.start, segment.end],
                          strokeWidth: 4.0,
                          color: getColorWithFlowRate(segment.flow),
                        );
                      }).toList();

                      return PolylineLayer(
                        polylines: polylines,
                      );
                    }
                  },
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
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
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
