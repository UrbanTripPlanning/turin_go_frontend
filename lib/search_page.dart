import 'package:flutter/material.dart';
import 'route_page.dart';
import 'api/place.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  // 加载搜索记录
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
        errorMessage = 'search place fail: ${e.toString()}';
        isLoading = false;
      });
    }
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutePage(
                              startName: "Your location",
                              endName: place['name_en'],
                              startCoord: [place['Longitude'], place['Latitude']],
                              endCoord: [7.657668, 45.065126],
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    final place = searchResults[index];
                    return ListTile(
                      leading: Icon(Icons.location_on),
                      title: Text(place['name_en']),
                      subtitle: Text(place['name_it'] ?? ''),
                      onTap: () {
                        _addToRecentSearches(place);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutePage(
                              startName: "Your location",
                              endName: place['name_en'],
                              startCoord: [place['Longitude'], place['Latitude']],
                              endCoord: [7.657668, 45.065126],
                            ),
                          ),
                        );
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
