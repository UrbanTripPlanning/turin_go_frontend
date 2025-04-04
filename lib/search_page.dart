import 'package:flutter/material.dart';
import 'route_page.dart';
import 'api/place.dart';

class SearchPage extends StatefulWidget {
  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final List<String> recentSearches = [
    "Porta Nuova",
    "Porta Susa",
    "Esselunga",
    "Polytechnic University of Turin",
    "McDonald's",
    "Torino Airport",
    "IKEA"
  ];

  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();

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
              onChanged: (query) {
                _searchPlaces(query);
              },
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
                    return ListTile(
                      leading: Icon(Icons.history),
                      title: Text(recentSearches[index]),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutePage(
                              startName: recentSearches[index],
                              endName: "Torino Airport",
                              startCoord: [7.705189, 45.068828],
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutePage(
                              startName: place['name_en'],
                              endName: "Torino Airport",
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
    _searchController.dispose();
    super.dispose();
  }
}
