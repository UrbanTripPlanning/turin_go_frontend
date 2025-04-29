import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turin_go_frontend/api/road.dart';
import 'route_page.dart';

class SavedPage extends StatefulWidget {
  @override
  SavedPageState createState() => SavedPageState();
}

class SavedPageState extends State<SavedPage> {
  String? userId;
  List<Map<String, dynamic>> planList = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString('userId');
    });
    _getPlanList();
  }

  Future<void> _getPlanList() async {
    if (!mounted) return;
    setState(() {
      planList = [];
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await RoadApi.listRoute(userId: userId ?? '');
      if (!mounted) return;
      setState(() {
        planList = List<Map<String, dynamic>>.from(result['data']);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load route: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  List _getLeaveTime(Map trip) {
    String dt;
    if (trip['time_mode'] == 1) {
      dt = DateTime.fromMillisecondsSinceEpoch(trip['start_at'] * 1000).toLocal().toString();
    } else {
      dt = DateTime.fromMillisecondsSinceEpoch((trip['end_at'] - trip['spend_time'] * 60) * 1000).toLocal().toString();
    }

    return [dt.split(' ')[0], dt.split(' ')[1].substring(0, 5)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Saved Trips')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)))
          : ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: planList.length,
        itemBuilder: (context, index) {
          final trip = planList[index];
          final leaveTime = _getLeaveTime(trip);
          return Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text('To: ${trip['dst_name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave by ${leaveTime[0]} ${leaveTime[1]}'),
                    Text('From ${trip['src_name']} To ${trip['dst_name']}'),
                    Text('Duration: ${trip['spend_time']} min  By ${trip['route_mode'] == 0 ? 'walking' : 'driving'}'),
                  ],
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoutePage(
                      startName: trip['src_name'],
                      endName: trip['dst_name'],
                      startCoord: (trip['src_loc'] as List).map((e) => (e as num).toDouble()).toList(),
                      endCoord: (trip['dst_loc'] as List).map((e) => (e as num).toDouble()).toList(),
                      planId: trip['plan_id'],
                      routeMode: trip['route_mode'],
                      timeMode: trip['time_mode'],
                      startAt: trip['start_at'],
                      endAt: trip['end_at'],
                    ),
                  ),
                );
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: Icon(Icons.edit), onPressed: () {}),
                  IconButton(icon: Icon(Icons.delete), onPressed: () {}),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTripPage()),
          ).then((newTrip) {
            if (newTrip == true) {
              _getPlanList(); // reload saved trips
            }
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddTripPage extends StatefulWidget {
  @override
  AddTripPageState createState() => AddTripPageState();
}

class AddTripPageState extends State<AddTripPage> {
  final _formKey = GlobalKey<FormState>();
  String? tripName;
  String from = '';
  String to = '';
  TimeOfDay? leaveTime;
  bool isLeaveTime = true;
  List<String> selectedDays = [];
  DateTime? specificDate;
  bool isUsingSpecificDate = false;
  String transport = 'Walking';
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: "Name", hintText: "Enter trip's name (optional)"),
                onChanged: (value) => setState(() => tripName = value),
              ),
              SizedBox(height: 10),
              TextFormField(
                decoration: InputDecoration(labelText: 'From'),
                onChanged: (value) => setState(() => from = value),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a starting point' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'To'),
                onChanged: (value) => setState(() => to = value),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a destination' : null,
              ),
              SizedBox(height: 20),
              Text("Time Preferences", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('Leave At'),
                      value: true,
                      groupValue: isLeaveTime,
                      onChanged: (val) => setState(() => isLeaveTime = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('Arrived by'),
                      value: false,
                      groupValue: isLeaveTime,
                      onChanged: (val) => setState(() => isLeaveTime = val!),
                    ),
                  ),
                ],
              ),
              ListTile(
                title: Text(leaveTime == null ? 'Choose time' : 'Time: ${leaveTime!.format(context)}'),
                trailing: Icon(Icons.access_time),
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: leaveTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => leaveTime = picked);
                },
              ),
              SizedBox(height: 20),
              Text("Repeat or Specific Date", style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<bool>(
                title: Text("Use weekday preferences"),
                value: false,
                groupValue: isUsingSpecificDate,
                onChanged: (val) => setState(() => isUsingSpecificDate = val!),
              ),
              if (!isUsingSpecificDate)
                Wrap(
                  spacing: 10,
                  children: ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'].map((day) {
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedDays.add(day);
                          } else {
                            selectedDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              RadioListTile<bool>(
                title: Text("Use specific date"),
                value: true,
                groupValue: isUsingSpecificDate,
                onChanged: (val) => setState(() => isUsingSpecificDate = val!),
              ),
              if (isUsingSpecificDate)
                ListTile(
                  title: Text(specificDate == null ? 'Choose date' : specificDate!.toIso8601String().split('T')[0]),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => specificDate = picked);
                  },
                ),
              SizedBox(height: 20),
              Text("Means of Transport", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text("Walking"),
                      value: 'Walking',
                      groupValue: transport,
                      onChanged: (val) => setState(() => transport = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text("Drive"),
                      value: 'Drive',
                      groupValue: transport,
                      onChanged: (val) => setState(() => transport = val!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => isLoading = true);

                    try {
                      final now = DateTime.now();
                      final leaveDateTime = leaveTime != null
                          ? DateTime(now.year, now.month, now.day, leaveTime!.hour, leaveTime!.minute)
                          : now;

                      final startAt = isLeaveTime ? leaveDateTime.millisecondsSinceEpoch ~/ 1000 : null;
                      final endAt = !isLeaveTime ? leaveDateTime.millisecondsSinceEpoch ~/ 1000 : null;

                      final result = await RoadApi.saveRoute(
                        userId: '',
                        start: [45.0, 7.0], // Replace with real coordinates if available
                        end: [45.1, 7.1],
                        spendTime: 15,
                        timeMode: isLeaveTime ? 1 : 0,
                        startName: from,
                        endName: to,
                        routeMode: transport.toLowerCase() == 'walking' ? 0 : 1,
                        startAt: startAt,
                        endAt: endAt,
                      );

                      if (!context.mounted) return;
                      if (result['data'] == null) {
                        Navigator.pop(context, true); // trip saved
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save trip')));
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    } finally {
                      setState(() => isLoading = false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[200],
                  foregroundColor: Colors.black,
                ),
                child: Text("Save Trip"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
