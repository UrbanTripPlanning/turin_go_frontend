import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/common.dart';
import 'notification_service.dart'; // Make sure you have this!

class SettingsPage extends StatefulWidget {
  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  String username = '';
  String password = '';
  bool notificationsEnabled = false;
  String? userId;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString('userId');
      username = prefs.getString('username') ?? '';
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  Future<void> _login() async {
    try {
      final result = await CommonApi.login(username: username, password: password);
      if (result['data'] != null) {
        if (!mounted) return;

        setState(() {
          userId = result['data']['user_id'];
          username = result['data']['username'];
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId!);
        await prefs.setString('username', username);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully logged in as $username')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${result['message']}')),
        );
      }
    } catch (e) {
      print('Error during login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during login')),
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', notificationsEnabled);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  Future<void> _testNotification() async {
    await Future.delayed(Duration(seconds: 5));
    await NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Test Notification',
      body: 'This is a test notification triggered after 5 seconds!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (userId != null)
              Text('Logged in as: $username', style: TextStyle(fontSize: 16))
            else ...[
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  username = _usernameController.text;
                  password = _passwordController.text;
                  _login();
                },
                child: Text('Login'),
              ),
            ],
            if (userId != null) ...[
              SizedBox(height: 20),
              Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: Text('Enable Notifications'),
                value: notificationsEnabled,
                onChanged: (bool value) async {
                  setState(() {
                    notificationsEnabled = value;
                  });
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notificationsEnabled', value);
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text('Save Settings'),
              ),
              if (notificationsEnabled) ...[
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _testNotification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Test notification will appear in 5 seconds')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: Text('Test the Notification'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

