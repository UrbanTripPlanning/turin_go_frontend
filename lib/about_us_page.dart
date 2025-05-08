import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFB3E5FC),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'About Us',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 16.5,
            height: 1.6,
            fontFamily: 'Georgia',
            color: Colors.black87,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Meet the Team',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We are a multidisciplinary group of students working at the intersection of urban mobility, data science, and smart city planning. Our team consists of:\n\n'
                '• Wenxi Lai\n'
                '• Riccardo Fida\n'
                '• Marzio Reitano\n'
                '• Habibollah Naeimi\n'
                '• Davood Shaterzadeh\n\n'
                'Each member brings unique expertise, from AI and graph theory to system design and real-world mobility challenges.',
              ),
              SizedBox(height: 24),
              Text(
                'What We Built',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Our project is an intelligent trip planning system designed specifically for the city of Turin. It uses traffic data to offer optimized travel routes for urban users, with a focus on environmental adaptation and efficiency.',
              ),
              SizedBox(height: 24),
              Text(
                'How It Works',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'At the core of our system is a Graph Convolutional Network (GCN) that models the city’s road network as a graph, learning spatial and temporal patterns from traffic data.\n\n'
                'We also integrate weather data correlation to dynamically adjust route recommendations based on current or forecasted conditions (e.g., rain).\n\n'
                'The system continuously adapts, ensuring that the suggested routes are not just shortest — but also context-aware, safer, and more reliable.',
              ),
              SizedBox(height: 24),
              Text(
                'Our Vision',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We aim to contribute to smarter urban mobility in modern cities by merging AI, geospatial data, and urban planning. By tailoring our solution to Turin’s unique layout and traffic behavior, we hope to support both residents and policymakers in making better travel decisions.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

