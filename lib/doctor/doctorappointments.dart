import 'package:doctor/doctor/patientdetail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorAppointmentsPage extends StatefulWidget {
  const DoctorAppointmentsPage({super.key});

  @override
  State<DoctorAppointmentsPage> createState() => _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> {
  final supabase = Supabase.instance.client;
  final doctorId = Supabase.instance.client.auth.currentUser?.id;

  List<dynamic> appointments = [];
  bool isLoading = true;
  String selectedFilter = 'all';
  String searchQuery = '';
  String timeFilter = 'all';

  final List<String> filters = [
    'all',
    'pending',
    'confirmed',
    'rejected',
    'rescheduled',
    'upcoming',
  ];

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    if (doctorId == null) return;
    setState(() => isLoading = true);

    var query = supabase
        .from('appointments')
        .select()
        .eq('doctorid', doctorId!);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (selectedFilter == 'pending') {
      query = query.eq('status', 'pending');
    } else if (selectedFilter == 'confirmed') {
      query = query.eq('status', 'confirmed');
    } else if (selectedFilter == 'rejected') {
      query = query.eq('status', 'rejected');
    } else if (selectedFilter == 'rescheduled') {
      query = query.eq('status', 'rescheduled');
    } else if (selectedFilter == 'upcoming') {
      query = query.gte('date', today);
    }

    try {
      final res = await query.order('date', ascending: false);
      List<dynamic> filtered = res;

      // 🔹 Auto-complete past appointments
      for (var appt in filtered) {
        if (appt['status'] != 'completed') {
          DateTime apptDate = DateTime.parse(appt['date']);
          if (apptDate.isBefore(DateTime.now())) {
            await supabase
                .from('appointments')
                .update({'status': 'completed'})
                .eq('id', appt['id']);
            appt['status'] = 'completed'; // Update local list too
          }
        }
      }

      if (searchQuery.isNotEmpty) {
        filtered = filtered.where((a) {
          final username = (a['username'] ?? '').toString().toLowerCase();
          return username.contains(searchQuery.toLowerCase());
        }).toList();
      }

      if (timeFilter == 'AM') {
        filtered = filtered
            .where((a) => (a['time'] ?? '').toUpperCase().contains('AM'))
            .toList();
      } else if (timeFilter == 'PM') {
        filtered = filtered
            .where((a) => (a['time'] ?? '').toUpperCase().contains('PM'))
            .toList();
      }

      // Fetch medical history for all appointments
      final appointmentIds = filtered.map((a) => a['id']).toList();
      final histories = await supabase
          .from('MedicalHistory')
          .select('appointment_id, diagnosis, medication')
          .inFilter('appointment_id', appointmentIds);

      // Map for quick lookup
      final historyMap = {for (var h in histories) h['appointment_id']: h};

      // Merge history into appointments
      for (var appt in filtered) {
        appt['medical_history'] = historyMap[appt['id']];
      }

      setState(() {
        appointments = filtered;
        isLoading = false;
      });

      // Show reminder if any completed appointment has no history
      final pendingReports = appointments.where(
        (a) => a['status'] == 'completed' && a['medical_history'] == null,
      );
      if (pendingReports.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _showReminderDialog();
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load appointments: $e')),
      );
    }
  }

  void _showReminderDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reminder"),
        content: const Text(
          "Please provide medical reports for the completed appointments.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> data) {
    final medical = data['medical_history'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Appointment Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Patient: ${data['username']}"),
            Text("Date: ${data['date']}"),
            Text("Time: ${data['time']}"),
            const Divider(),
            if (medical != null) ...[
              Text("Diagnosis: ${medical['diagnosis'] ?? 'N/A'}"),
              Text("Medication: ${medical['medication'] ?? 'N/A'}"),
            ] else
              const Text("No medical report provided yet."),
            const SizedBox(height: 8),
            if (medical == null && data['status'] == 'completed')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddMedicalHistoryDialog(data['id']);
                },
                icon: const Icon(Icons.medical_information),
                label: const Text("Add Medical History"),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showAddMedicalHistoryDialog(String appointmentId) {
    final diagnosisController = TextEditingController();
    final medicationController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Medical History"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: diagnosisController,
                decoration: const InputDecoration(labelText: "Diagnosis"),
              ),
              TextField(
                controller: medicationController,
                decoration: const InputDecoration(labelText: "Medication"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (diagnosisController.text.trim().isEmpty ||
                  medicationController.text.trim().isEmpty) {
                return;
              }

              // 🔹 Get appointment details for patient_id
              final appt = appointments.firstWhere(
                (a) => a['id'] == appointmentId,
              );
              final patientId = appt['userid'];

              await supabase.from('MedicalHistory').insert({
                'appointment_id': appointmentId,
                'doctor_id': doctorId,
                'patient_id': patientId,
                'diagnosis': diagnosisController.text.trim(),
                'medication': medicationController.text.trim(),
              });

              Navigator.pop(context);
              fetchAppointments();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Medical history added successfully'),
                ),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _handleAction(Map<String, dynamic> appointment, String action) async {
    if (action == 'reschedule') {
      _showRescheduleDialog(appointment);
    } else {
      String newStatus = action == 'confirm' ? 'confirmed' : 'rejected';
      await supabase
          .from('appointments')
          .update({'status': newStatus})
          .eq('id', appointment['id']);
      fetchAppointments();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Appointment $newStatus')));
    }
  }

  void _showRescheduleDialog(Map<String, dynamic> appointment) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(appointment['date']) ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    final formattedTime = pickedTime.format(context);

    await supabase
        .from('appointments')
        .update({
          'date': formattedDate,
          'time': formattedTime,
          'status': 'rescheduled',
        })
        .eq('id', appointment['id']);

    fetchAppointments();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Appointment rescheduled')));
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'rescheduled':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F2F2), Color(0xFFE3E3F3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    return ChoiceChip(
                      label: Text(filter.toUpperCase()),
                      selected: selectedFilter == filter,
                      onSelected: (_) {
                        setState(() => selectedFilter = filter);
                        fetchAppointments();
                      },
                      selectedColor: Colors.deepPurpleAccent,
                      labelStyle: TextStyle(
                        color: selectedFilter == filter
                            ? Colors.white
                            : Colors.black,
                      ),
                      backgroundColor: Colors.grey[200],
                    );
                  },
                ),
              ),
            ),

            // Search and Time Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by patient name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      fetchAppointments();
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ['all', 'AM', 'PM'].map((label) {
                      return ChoiceChip(
                        label: Text(label),
                        selected: timeFilter == label,
                        onSelected: (_) {
                          setState(() => timeFilter = label);
                          fetchAppointments();
                        },
                        selectedColor: Colors.deepPurple,
                        labelStyle: TextStyle(
                          color: timeFilter == label
                              ? Colors.white
                              : Colors.black,
                        ),
                        backgroundColor: Colors.grey[300],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Appointments List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : appointments.isEmpty
                  ? const Center(child: Text("No appointments found."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final a = appointments[index];
                        final username = a['username'] ?? 'Unknown';
                        final userImage = a['userprofileImage'];
                        final date = a['date'];
                        final time = a['time'];
                        final status = a['status'];

                        return GestureDetector(
                          onTap: () => _showAppointmentDetails(a),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            Patientdetail(userid: a['userid']),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundImage: userImage != null
                                        ? NetworkImage(userImage)
                                        : null,
                                    backgroundColor: Colors.grey[300],
                                    child: userImage == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Username, Date, Time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("Date: $date"),
                                      Text("Time: $time"),
                                    ],
                                  ),
                                ),

                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Menu button
                                PopupMenuButton<String>(
                                  onSelected: (val) => _handleAction(a, val),
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'confirm',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 8),
                                          Text("Confirm"),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reject',
                                      child: Row(
                                        children: [
                                          Icon(Icons.close, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text("Reject"),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reschedule',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month,
                                            color: Colors.blue,
                                          ),
                                          SizedBox(width: 8),
                                          Text("Reschedule"),
                                        ],
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
