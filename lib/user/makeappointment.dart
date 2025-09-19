import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class BookAppointmentPage extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final Map<String, dynamic> userData;

  const BookAppointmentPage({
    super.key,
    required this.doctorData,
    required this.userData,
  });

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final supabase = Supabase.instance.client;

  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  TimeOfDay? selectedTime;
  final noteController = TextEditingController();
  bool isBooking = false;

  List<String> get workingDays => List<String>.from(
    widget.doctorData['workingday'] ?? [],
  ).map((e) => e.toLowerCase()).toList();

  bool _isWorkingDay(DateTime date) {
    final dayName = _weekdayToString(date.weekday).toLowerCase();
    return workingDays.contains(dayName);
  }

  String _weekdayToString(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  Future<void> bookAppointment() async {
    if (selectedDay == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => isBooking = true);

    try {
      // Check if the appointment already exists
      final existingAppointments = await supabase
          .from('appointments')
          .select()
          .eq('userid', widget.userData['userId'])
          .eq('doctorid', widget.doctorData['userId'])
          .eq('date', selectedDay!.toIso8601String());

      if (existingAppointments.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have an appointment for this time'),
          ),
        );
        return;
      }
      // Create the appointment
      final appointment = {
        'userid': widget.userData['userId'],
        'doctorid': widget.doctorData['userId'],
        'date': selectedDay!.toIso8601String(),
        'time': selectedTime!.format(context),
        'note': noteController.text,
        'status': 'pending',
        'username': widget.userData['username'],
        'userprofileImage': widget.userData['profileImage'],
        'doctorname': widget.doctorData['username'],
        'doctorprofileImage': widget.doctorData['profileImage'],
      };

      await supabase.from('appointments').insert(appointment);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    } finally {
      setState(() => isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctorData;
    final profileImage = doctor['profileImage'];
    final username = doctor['username'];
    final specialization = (doctor['specialization'] ?? []).join(', ');
    final workat = doctor['workat'];

    return Scaffold(
      appBar: AppBar(title: Text('Book ${username ?? "Doctor"}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Doctor Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: profileImage != null
                  ? Image.network(
                      profileImage,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 60),
                    ),
            ),
            const SizedBox(height: 12),

            // Doctor Info
            Text(
              username ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(specialization, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              'Works at: $workat',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const Divider(height: 32),

            // Calendar
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Date",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 60)),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: (selected, focused) {
                if (_isWorkingDay(selected)) {
                  setState(() {
                    selectedDay = selected;
                    focusedDay = focused;
                  });
                }
              },
              enabledDayPredicate: _isWorkingDay,
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: Colors.red),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) {
                  final isWorking = _isWorkingDay(day);
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isWorking ? Colors.blue.shade50 : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isWorking ? Colors.black : Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Time picker
            Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedTime != null
                        ? 'Selected Time: ${selectedTime!.format(context)}'
                        : 'No time selected',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickTime,
                  child: const Text("Pick Time"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Confirm Button
            isBooking
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Confirm Booking"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue.shade700,
                      ),
                      onPressed: bookAppointment,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
