// Updated search_page.dart: no direct RoutePage pushes; always pop selected place
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/place.dart';
import 'package:turin_go_frontend/map_picker_page.dart';

const LatLng politecnicoCoord = LatLng(45.062331, 7.662690);

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
  bool _locationAvailable = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          setState(() => _locationAvailable = false);
          return;
        }
      }
      await Geolocator.getCurrentPosition();
      setState(() => _locationAvailable = true);
    } catch (_) {
      setState(() => _locationAvailable = false);
    }
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
        errorMessage = "Search failed: \${e.toString()}";
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
        // simply return picked place as destination
        Navigator.pop(context, {
          'name_en': 'Pinned Location',
          'Latitude': picked.latitude,
          'Longitude': picked.longitude,
        });
      }
    }
  }

  Future<void> _selectCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception("Denied");
        }
      }

      Position pos = await Geolocator.getCurrentPosition();
      Navigator.pop(context, {
        'name_en': 'Your Location',
        'Latitude': pos.latitude,
        'Longitude': pos.longitude,
      });
    } catch (e) {
      Navigator.pop(context, {
        'name_en': 'Politecnico',
        'Latitude': politecnicoCoord.latitude,
        'Longitude': politecnicoCoord.longitude,
      });
    }
  }

  void _onPlaceTap(Map<String, dynamic> place) async {
    if (widget.isSelectingStartPoint) {
      Navigator.pop(context, place);
    } else {
      // update recent searches
      final prefs = await SharedPreferences.getInstance();
      recentSearches.removeWhere((p) => p['name_en'] == place['name_en']);
      recentSearches.insert(0, place);
      if (recentSearches.length > 10) recentSearches = recentSearches.sublist(0, 10);
      await prefs.setString(_recentSearchesKey, json.encode(recentSearches));

      // simply return selected destination
      Navigator.pop(context, place);
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
        title: Text(
          widget.isSelectingStartPoint ? 'Pick Starting Point' : 'Pick Destination',
          style: TextStyle(color: Colors.black),
        ),
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
                  leading: Icon(Icons.my_location,
                      color: _locationAvailable ? null : Colors.grey),
                  title: Text("Your Location",
                      style: TextStyle(
                          color: _locationAvailable ? null : Colors.grey)),
                  onTap: _locationAvailable ? _selectCurrentLocation : null,
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
                itemCount: searchResults.isNotEmpty
                    ? searchResults.length
                    : recentSearches.length,
                itemBuilder: (context, index) {
                  final place = searchResults.isNotEmpty
                      ? searchResults[index]
                      : recentSearches[index];
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