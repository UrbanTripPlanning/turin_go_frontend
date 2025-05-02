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

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', notificationsEnabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings saved successfully')),
    );
  }

  Future<void> _testNotification() async {
    await Future.delayed(Duration(seconds: 5));
    await NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Test Notification',
      body: 'This is a test notification triggered after 5 seconds!',
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade800),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );
  }

  Widget _styledButton({
    required String text,
    required VoidCallback onPressed,
    Color background = Colors.blue,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFADD8E6),
        elevation: 0,
        centerTitle: true,
        title: const Text('Settings', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: userId == null
            ? Center(
          child: GlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      isRegistering ? 'Register' : 'Login',
                      style: const TextStyle(fontSize: 26, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    TextField(controller: _usernameController, decoration: _inputDecoration('Username')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: !passwordVisible,
                      decoration: _inputDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => passwordVisible = !passwordVisible),
                        ),
                      ),
                    ),
                    if (isRegistering)
                      const SizedBox(height: 12),
                    if (isRegistering)
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !passwordVisible,
                        decoration: _inputDecoration('Confirm Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => passwordVisible = !passwordVisible),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _styledButton(
                      text: isRegistering ? 'Register' : 'Login',
                      onPressed: () {
                        username = _usernameController.text.trim();
                        password = _passwordController.text.trim();
                        confirmPassword = _confirmPasswordController.text.trim();
                        _loginOrRegister();
                      },
                    ),
                    TextButton(
                      onPressed: () => setState(() => isRegistering = !isRegistering),
                      child: Text(
                        isRegistering ? 'Already have an account? Login' : 'Don\'t have an account? Register',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text('App Version: $appVersion', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        )
            : Center(
          child: GlassContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text('Logged in as: $username', style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Enable Notifications', style: TextStyle(color: Colors.black87)),
                      value: notificationsEnabled,
                      onChanged: (bool value) async {
                        setState(() => notificationsEnabled = value);
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notificationsEnabled', value);
                      },
                    ),
                    _styledButton(
                      text: 'Save Settings',
                      onPressed: _saveSettings,
                    ),
                    if (notificationsEnabled)
                      _styledButton(
                        text: 'Test the Notification',
                        onPressed: () {
                          _testNotification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test notification will appear in 5 seconds')),
                          );
                        },
                        background: Colors.orange,
                      ),
                    _styledButton(
                      text: 'View Trip Alerts',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessageBoxPage(onMessagesRead: widget.onMessagesRead),
                          ),
                        );
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('tripMessages', []);
                        setState(() => unreadMessageCount = 0);
                        widget.onMessagesRead();
                      },
                      background: Colors.indigo,
                    ),
                    _styledButton(
                      text: 'Logout',
                      onPressed: _logout,
                      background: Colors.redAccent,
                    ),
                    const SizedBox(height: 30),
                    Text('App Version: $appVersion', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

