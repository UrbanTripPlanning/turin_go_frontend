import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api/road.dart';

class MessageBoxPage extends StatefulWidget {
  final VoidCallback onMessagesRead;

  const MessageBoxPage({required this.onMessagesRead, super.key});

  @override
  State<MessageBoxPage> createState() => _MessageBoxPageState();
}

class _MessageBoxPageState extends State<MessageBoxPage> {
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('trip_events') ?? [];
    final parsed = rawList.map((e) => json.decode(e)).cast<Map<String, dynamic>>().toList();

    // Mark all as read
    final updated = parsed.map((event) {
      event['read'] = true;
      return json.encode(event);
    }).toList();
    await prefs.setStringList('trip_events', updated);

    // Sort by timestamp descending
    parsed.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    setState(() {
      messages = parsed;
      isLoading = false;
    });

    widget.onMessagesRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Trip Events',
          style: TextStyle(color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,),
        ),
        backgroundColor: const Color(0xFFB3E5FC),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
          ? const Center(child: Text('No recent updates.'))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final trip = messages[index];
          final bool isUnread = trip['read'] == false;
          final timestamp = DateTime.tryParse(trip['timestamp'] ?? '')?.toLocal();
          final formattedTime = timestamp != null ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}' : '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isUnread ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Icon(Icons.directions, color: isUnread ? Colors.deepOrange : Colors.blue),
                title: Text(
                  'Trip to ${trip['dst_name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New duration: ${trip['spend_time']} minutes', style: const TextStyle(color: Colors.black54)),
                    if (formattedTime.isNotEmpty)
                      Text(formattedTime, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
                trailing: isUnread
                    ? const Icon(Icons.fiber_new, color: Colors.redAccent)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}


