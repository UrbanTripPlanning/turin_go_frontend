// Fully updated SettingsPage with unread trip alert count and visual improvements
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'glass_container.dart';
import 'api/common.dart';
import 'trip_update_service.dart';
import 'message_box_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onMessagesRead;
  SettingsPage({required this.onMessagesRead});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  String username = '';
  String password = '';
  String confirmPassword = '';
  bool passwordVisible = false;
  bool notificationsEnabled = false;
  String? userId;
  bool isRegistering = false;
  int unreadMessageCount = 0;
  final String appVersion = 'v0.0.1';

  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString('userId');
      username = prefs.getString('username') ?? '';
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      unreadMessageCount = prefs.getStringList('tripMessages')?.length ?? 0;
    });

    if (userId != null && notificationsEnabled) {
      TripUpdateService().initialize(
        userId: userId!,
        notificationsEnabled: true,
        onNewMessage: (count) {
          if (!mounted) return;
          setState(() => unreadMessageCount = count);
        },
      );
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('tripMessages');
    if (!mounted) return;
    setState(() {
      userId = null;
      username = '';
      unreadMessageCount = 0;
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _loginOrRegister() async {
    if (isRegistering && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

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
          SnackBar(
            content: Text(
              isRegistering
                  ? 'Registered and logged in as $username'
                  : 'Successfully logged in as $username',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isRegistering ? "Registration" : "Login"} failed: ${result['message']}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during ${isRegistering ? "registration" : "login"}')),
      );
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

  Widget _userInfoCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            child: Icon(Icons.person, size: 32, color: Colors.black87),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Logged in', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiatTile(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB3E5FC),
        elevation: 0,
        centerTitle: true,
        title: const Text('Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: userId == null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(isRegistering ? 'Register' : 'Login', style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 20),
                  TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Username')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => passwordVisible = !passwordVisible),
                      ),
                    ),
                  ),
                  if (isRegistering) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: !passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        suffixIcon: IconButton(
                          icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => passwordVisible = !passwordVisible),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        username = _usernameController.text.trim();
                        password = _passwordController.text.trim();
                        confirmPassword = _confirmPasswordController.text.trim();
                        _loginOrRegister();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isRegistering ? 'Register' : 'Login'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => isRegistering = !isRegistering),
                    child: Text(isRegistering ? 'Already have an account? Login' : 'Don\'t have an account? Register'),
                  ),
                  const SizedBox(height: 30),
                  Text('App Version: $appVersion', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        )
            : Column(
          children: [
            _userInfoCard(),
            _fiatTile(
              'Enable Notifications',
              Icons.notifications_active,
                  () async {
                setState(() => notificationsEnabled = !notificationsEnabled);
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notificationsEnabled', notificationsEnabled);
              },
              color: notificationsEnabled ? Colors.blue : Colors.black87,
            ),
            if (notificationsEnabled)
              _fiatTile('Test Notification', Icons.campaign, () {
                _testNotification();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test notification will appear in 5 seconds')));
              }),
            _fiatTile(
              'View Trip Alerts' + (unreadMessageCount > 0 ? ' ($unreadMessageCount)' : ''),
              Icons.warning_amber,
                  () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MessageBoxPage(onMessagesRead: widget.onMessagesRead)),
                );
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setStringList('tripMessages', []);
                setState(() => unreadMessageCount = 0);
                widget.onMessagesRead();
              },
            ),
            Divider(),
            Container(
              color: Colors.red.shade50,
              child: _fiatTile('Logout', Icons.logout, _logout, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            Text('App Version: $appVersion', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
