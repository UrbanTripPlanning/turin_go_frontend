import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showTraffic = false;
  final LatLng _initialPosition = LatLng(45.06298, 7.67773);

  final String normalTileUrl = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
  final String trafficTileUrl = "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png";

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
                urlTemplate: showTraffic ? trafficTileUrl : normalTileUrl,
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.turinGoFrontend',
              ),
            ],
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
}
