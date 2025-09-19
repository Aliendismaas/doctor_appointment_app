import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RescheduleAppointmentPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const RescheduleAppointmentPage({super.key, required this.appointment});

  @override
  State<RescheduleAppointmentPage> createState() =>
      _RescheduleAppointmentPageState();
}

class _RescheduleAppointmentPageState extends State<RescheduleAppointmentPage> {
  final supabase = Supabase.instance.client;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    final initialDate = DateTime.tryParse(widget.appointment['date']);
    if (initialDate != null) {
      selectedDate = initialDate;
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> submitReschedule() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time')),
      );
      return;
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final formattedTime = selectedTime!.format(context);

    await supabase
        .from('appointments')
        .update({
          'date': formattedDate,
          'time': formattedTime,
          'status': 'pending', // Reset status if needed
        })
        .eq('id', widget.appointment['id']);

    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment rescheduled successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reschedule Appointment")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              title: const Text("Select New Date"),
              subtitle: Text(
                selectedDate != null
                    ? DateFormat('EEE, MMM d, yyyy').format(selectedDate!)
                    : 'No date selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickDate,
            ),
            ListTile(
              title: const Text("Select New Time"),
              subtitle: Text(
                selectedTime != null
                    ? selectedTime!.format(context)
                    : 'No time selected',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: pickTime,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: submitReschedule,
              icon: const Icon(Icons.check),
              label: const Text("Confirm Reschedule"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
