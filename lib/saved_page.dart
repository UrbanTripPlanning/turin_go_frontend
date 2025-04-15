import 'package:flutter/material.dart';
import 'package:turin_go_frontend/api/road.dart';

class SavedPage extends StatefulWidget {
  @override
  SavedPageState createState() => SavedPageState();
}

class SavedPageState extends State<SavedPage> {
  List<Map<String, dynamic>> planList = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _getPlanList();
  }

  Future<void> _getPlanList() async {
    setState(() {
      planList = [];
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await RoadApi.listRoute(userId: 0);
      setState(() {
        planList = List<Map<String, dynamic>>.from(result['data']);
        isLoading = false;
      });
    } catch (e) {
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
        dt =  DateTime.fromMillisecondsSinceEpoch((trip['end_at'] - trip['spend_time'] * 60) * 1000).toLocal().toString();
      }

      return [dt.split(' ')[0], dt.split(' ')[1].substring(0, 5)];
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
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
            if (newTrip != null) {
              setState(() {
                planList.add(newTrip);
              });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Trip')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
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
                initialValue: from,
                onChanged: (value) => setState(() => from = value),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'To'),
                initialValue: to,
                onChanged: (value) => setState(() => to = value),
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
                  children: ['Mon','Tues','Wed','Thurs','Fri','Sat','Sun'].map((day) {
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'title': tripName ?? '',
                      'leave': leaveTime != null ? leaveTime!.format(context) : '',
                      'from': from,
                      'to': to,
                      'duration': '15 minutes',
                      'mode': transport.toLowerCase(),
                    });
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

