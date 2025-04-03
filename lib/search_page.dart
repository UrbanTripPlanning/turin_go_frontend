import 'package:flutter/material.dart';
import 'route_page.dart';

class SearchPage extends StatelessWidget {
  final List<String> recentSearches = [
    "Porta Nuova",
    "Porta Susa",
    "Esselunga",
    "Polytechnic University of Turin",
    "McDonald's",
    "Torino Airport",
    "IKEA"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Search")),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search here",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (query) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoutePage(
                      startName: query,
                      endName: "Torino Airport",
                      startCoord: [7.705189, 45.068828],
                      endCoord: [7.657668, 45.065126],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: recentSearches.length,
              itemBuilder: (context, index) {
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
