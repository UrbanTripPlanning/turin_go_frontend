import 'package:flutter/material.dart';
import 'route_page.dart';
import 'api/place.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class SearchPage extends StatefulWidget {
  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  List<Map<String, dynamic>> recentSearches = [];
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  static const String _recentSearchesKey = 'recent_searches';
  static const String _locationKey = 'user_location';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  // Load search history
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searchesJson = prefs.getString(_recentSearchesKey);
    if (searchesJson != null) {
      setState(() {
        recentSearches = List<Map<String, dynamic>>.from(json.decode(searchesJson));
      });
    }
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchesKey, json.encode(recentSearches));
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(_searchController.text);
    });
  }

  void _addToRecentSearches(Map<String, dynamic> place) {
    setState(() {
      recentSearches.removeWhere((item) => item['name_en'] == place['name_en']);
      recentSearches.insert(0, place);
      if (recentSearches.length > 10) {
        recentSearches = recentSearches.sublist(0, 10);
      }
    });
    _saveRecentSearches();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
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
        errorMessage = 'Failed to search places: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Get user location
  Future<List<double>?> _getUserLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_locationKey);
      
      if (locationJson != null) {
        final location = json.decode(locationJson);
        final timestamp = location['timestamp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // If location data is older than 5 minutes, get new location
        if (now - timestamp > 5 * 60 * 1000) {
          return await _getCurrentLocation();
        }
        
        return [location['longitude'], location['latitude']];
      }
      
      return await _getCurrentLocation();
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  // Get current location
  Future<List<double>?> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final location = [position.longitude, position.latitude];
      
      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationKey, json.encode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
      
      return location;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  void _navigateToRoute(Map<String, dynamic> place, List<double> userLocation) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutePage(
          startName: "Your location",
          endName: place['name_en'],
          startCoord: userLocation,
          endCoord: [place['Longitude'], place['Latitude']],
        ),
      ),
    );
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to get current location. Please check location permissions')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Search")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search here",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.isEmpty ? recentSearches.length : searchResults.length,
                itemBuilder: (context, index) {
                  if (searchResults.isEmpty) {
                    final place = recentSearches[index];
                    return ListTile(
                      leading: Icon(Icons.history),
                      title: Text(place['name_en']),
                      subtitle: Text(place['name_it'] ?? ''),
                      onTap: () async {
                        final userLocation = await _getUserLocation();
                        if (userLocation != null) {
                          _navigateToRoute(place, userLocation);
                        } else {
                          _showError();
                        }
                      },
                    );
                  } else {
                    final place = searchResults[index];
                    return ListTile(
                      leading: Icon(Icons.location_on),
                      title: Text(place['name_en']),
                      subtitle: Text(place['name_it'] ?? ''),
                      onTap: () async {
                        _addToRecentSearches(place);
                        final userLocation = await _getUserLocation();
                        if (userLocation != null) {
                          _navigateToRoute(place, userLocation);
                        } else {
                          _showError();
                        }
                      },
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
