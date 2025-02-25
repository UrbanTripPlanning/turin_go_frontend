import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePage extends StatelessWidget {
  final String start;
  final String destination;

  RoutePage({required this.start, required this.destination});

  final LatLng startPoint = LatLng(45.09298, 7.67773);
  final LatLng midPoint = LatLng(45.16298, 7.67773);
  final LatLng destinationPoint = LatLng(45.21298, 7.67773);

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
                          hintText: start,
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
                          hintText: destination,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: midPoint,
                zoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [startPoint, midPoint, destinationPoint],
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: startPoint,
                      builder: (ctx) => Icon(Icons.location_on, color: Colors.green, size: 40),
                    ),
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: destinationPoint,
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
                  "14 min (19 km) - Fastest route",
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
