import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'home_page.dart';
import 'saved_page.dart';
import 'settings_page.dart';
import 'api/road.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trip_event_service.dart'; //

const fetchAffectedPlansTask = "fetchAffectedPlan";
Timer? _pollingTimer;

ValueNotifier<int> unreadEventCountNotifier = ValueNotifier<int>(0);

void startPolling() {
  _pollingTimer?.cancel();

  _pollingTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final unreadCount = await TripEventService().getUnreadCount();
    unreadEventCountNotifier.value = unreadCount;

    print('🔔 Unread trip alerts: \$unreadCount');
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await NotificationService.initialize();

  if (!kIsWeb) {
    await _requestMobilePermissions();
  }

  startPolling();
  runApp(MyApp());
}

Future<void> _requestMobilePermissions() async {
  if (await Permission.location.isDenied) {
    await Permission.location.request();
  }

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
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    unreadEventCountNotifier.addListener(() {
      setState(() {
        _unreadCount = unreadEventCountNotifier.value;
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _clearUnreadCount() {
    unreadEventCountNotifier.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomePage(),
      SavedPage(),
      SettingsPage(
        onMessagesRead: _clearUnreadCount,
      ),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          iconSize: 30,
          selectedIconTheme: const IconThemeData(size: 34),
          unselectedIconTheme: const IconThemeData(size: 30),
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: const Icon(Icons.home),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: const Icon(Icons.bookmark),
              ),
              label: 'Saved',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Stack(
                  children: [
                    const Icon(Icons.settings),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

