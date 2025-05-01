import 'package:flutter/material.dart';
import 'dart:async';
import 'package:timezone/data/latest.dart' as tz; // ✅ For time zone setup
import 'notification_service.dart'; // ✅ Make sure this file exists
import 'home_page.dart';
import 'saved_page.dart';
import 'settings_page.dart';
import 'api/road.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fetchAffectedPlansTask = "fetchAffectedPlan";
Timer? _pollingTimer;

void startPolling() {
  _pollingTimer?.cancel();

  _pollingTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) {
      return;
    }
    final result = await RoadApi.afftectedRoute(userId: userId);
    final planList = result['data'];
    if (planList == null || planList.isEmpty) {
      return;
    }
    // TODO: notification
    print('plan changed: $planList');
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize time zone for scheduled notifications
  tz.initializeTimeZones();

  // ✅ Initialize local notifications (Android + iOS)
  await NotificationService.initialize();

  startPolling();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turin Go',
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    SavedPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

