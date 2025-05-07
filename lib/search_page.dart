import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/place.dart';
import 'package:turin_go_frontend/map_picker_page.dart';
import 'package:turin_go_frontend/route_page.dart';

class SearchPage extends StatefulWidget {
  final bool isSelectingStartPoint;

  SearchPage({required this.isSelectingStartPoint});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> recentSearches = [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _debounce;
  static const String _recentSearchesKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 400), () {
      _searchPlaces(_searchController.text.trim());
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_recentSearchesKey);
    if (data != null) {
      setState(() {
        recentSearches = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchesKey, json.encode(recentSearches));
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await PlaceApi.searchPlaces(name: query);
      setState(() {
        searchResults = List<Map<String, dynamic>>.from(result['data']);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Search failed: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _chooseOnMap() async {
    final picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(isSelectingStartPoint: widget.isSelectingStartPoint),
      ),
    );

    if (picked != null) {
      if (widget.isSelectingStartPoint) {
        Navigator.pop(context, {
          'name_en': 'Pinned Location',
          'Latitude': picked.latitude,
          'Longitude': picked.longitude,
        });
      } else {
        final position = await Geolocator.getCurrentPosition();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoutePage(
              startName: "Your Location",
              endName: "Pinned Location",
              startCoord: [position.longitude, position.latitude],
              endCoord: [picked.longitude, picked.latitude],
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location permission denied')));
        return;
      }
    }

    Position pos = await Geolocator.getCurrentPosition();
    Navigator.pop(context, {
      'name_en': 'Your Location',
      'Latitude': pos.latitude,
      'Longitude': pos.longitude,
    });
  }

  void _onPlaceTap(Map<String, dynamic> place) async {
    if (widget.isSelectingStartPoint) {
      Navigator.pop(context, place);
    } else {
      final prefs = await SharedPreferences.getInstance();
      recentSearches.removeWhere((p) => p['name_en'] == place['name_en']);
      recentSearches.insert(0, place);
      if (recentSearches.length > 10) {
        recentSearches = recentSearches.sublist(0, 10);
      }
      await prefs.setString(_recentSearchesKey, json.encode(recentSearches));

      final position = await Geolocator.getCurrentPosition();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutePage(
            startName: "Your Location",
            endName: place['name_en'],
            startCoord: [position.longitude, position.latitude],
            endCoord: [place['Longitude'], place['Latitude']],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTyping = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFB3E5FC),
        title: Text(widget.isSelectingStartPoint ? 'Pick Starting Point' : 'Pick Destination', style: TextStyle(color: Colors.black)),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (!isTyping)
            Column(
              children: [
                ListTile(
                  leading: Icon(Icons.my_location),
                  title: Text("Your Location"),
                  onTap: _selectCurrentLocation,
                ),
                ListTile(
                  leading: Icon(Icons.map),
                  title: Text("Choose on Map"),
                  onTap: _chooseOnMap,
                ),
                Divider(),
              ],
            ),
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(errorMessage!, style: TextStyle(color: Colors.red)),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.isNotEmpty ? searchResults.length : recentSearches.length,
                itemBuilder: (context, index) {
                  final place = searchResults.isNotEmpty ? searchResults[index] : recentSearches[index];
                  return ListTile(
                    leading: Icon(Icons.location_on, color: Colors.blueGrey),
                    title: Text(place['name_en']),
                    subtitle: Text(place['name_it'] ?? ""),
                    onTap: () => _onPlaceTap(place),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

