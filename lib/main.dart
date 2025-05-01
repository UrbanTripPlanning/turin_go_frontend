import 'dart:io'; // For Platform checks
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';
import 'home_page.dart';
import 'saved_page.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone for scheduled notifications
  tz.initializeTimeZones();

  // Initialize local notifications
  await NotificationService.initialize();

  if (Platform.isAndroid) {
    await _requestAndroidPermissions();
  }

  runApp(MyApp());
}

Future<void> _requestAndroidPermissions() async {
  // Request location permission
  var locationStatus = await Permission.location.request();

  // Optional: Handle denied/limited if needed
  if (locationStatus.isDenied) {
    print("Location permission denied");
  }

  // Request notification permission (required on Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

