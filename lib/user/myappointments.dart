import 'package:doctor/user/reschedulapp.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyAppointmentsPage extends StatefulWidget {
  final String userId;

  const MyAppointmentsPage({super.key, required this.userId});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> appointments = [];
  bool isLoading = true;
  String selectedFilter = 'all';
  TextEditingController searchController = TextEditingController();
  String selectedTimeFilter = 'all';

  final List<String> filters = [
    'all',
    'confirmed',
    'pending',
    'accepted',
    'upcoming',
    'past',
  ];

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    setState(() => isLoading = true);
    try {
      var query = supabase
          .from('appointments')
          .select()
          .eq('userid', widget.userId);

      if (selectedFilter == 'confirmed') {
        query = query.eq('status', 'confirmed');
      } else if (selectedFilter == 'pending') {
        query = query.eq('status', 'pending');
      } else if (selectedFilter == 'accepted') {
        query = query.eq('status', 'accepted');
      } else if (selectedFilter == 'upcoming') {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        query = query.gte('date', today);
      } else if (selectedFilter == 'past') {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        query = query.lt('date', today);
      }

      final res = await query.order('date', ascending: false);
      final List<dynamic> raw = res;

      // Filter by search
      List filtered = raw.where((a) {
        final name = (a['doctorname'] ?? '').toLowerCase();
        return name.contains(searchController.text.toLowerCase());
      }).toList();

      // Filter by time
      if (selectedTimeFilter != 'all') {
        filtered = filtered.where((a) {
          final time = a['time'] ?? '';
          final hour = int.tryParse(time.split(':').first) ?? 0;
          return selectedTimeFilter == 'am' ? hour < 12 : hour >= 12;
        }).toList();
      }

      for (var appt in filtered) {
        final rating = await supabase
            .from('DoctorRatings')
            .select('id')
            .eq('appointment_id', appt['id'])
            .maybeSingle();
        appt['alreadyRated'] = rating != null;
      }

      setState(() {
        appointments = filtered;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load appointments: $e')),
      );
    }
  }

  void updateFilter(String filter) {
    setState(() {
      selectedFilter = filter;
    });
    fetchAppointments();
  }

  void _showAppointmentDetail(Map<String, dynamic> data) {
    final doctorImage = data['doctorprofileImage'];
    final doctorName = data['doctorname'];
    final date = data['date'];
    final time = data['time'];
    final note = data['note'] ?? 'No additional notes.';
    final status = data['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Appointment Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            doctorImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      doctorImage,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                : const CircleAvatar(radius: 40, child: Icon(Icons.person)),
            const SizedBox(height: 12),
            Text(
              doctorName ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Date: $date"),
            Text("Time: $time"),
            const SizedBox(height: 8),
            Text("Status: $status"),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Note:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(note),
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

  void _showRateDoctorDialog(Map<String, dynamic> appointment) {
    double rating = 0;
    bool isSubmitting = false;
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("How was the appointment"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Please give a rating:"),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reviewController,
                    decoration: const InputDecoration(
                      hintText: "Write a review (optional)",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (rating == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please select a rating"),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);

                          try {
                            await supabase.from('DoctorRatings').insert({
                              'doctor_id': appointment['doctorid'],
                              'patient_id': widget.userId,
                              'appointment_id': appointment['id'].toString(),
                              'rating': rating.toInt(),
                              'review': reviewController.text.trim(),
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "✅ Rating submitted successfully",
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("❌ Error submitting rating: $e"),
                              ),
                            );
                          }
                          setDialogState(() => isSubmitting = false);
                          Navigator.pop(context);
                          fetchAppointments(); // refresh list
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleMenuAction(String action, Map<String, dynamic> data) async {
    if (action == 'cancel') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Cancel Appointment"),
          content: const Text(
            "Are you sure you want to cancel this appointment?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes, Cancel"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await supabase.from('appointments').delete().eq('id', data['id']);
        fetchAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled successfully')),
        );
      }
    } else if (action == 'reschedule') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RescheduleAppointmentPage(appointment: data),
        ),
      ).then((value) {
        if (value == true) fetchAppointments();
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Appointments")),
      body: Column(
        children: [
          // Filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: filters.map((filter) {
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter[0].toUpperCase() + filter.substring(1)),
                    selected: isSelected,
                    onSelected: (_) => updateFilter(filter),
                    selectedColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Search bar and time filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => fetchAppointments(),
                    decoration: const InputDecoration(
                      hintText: 'Search doctor...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedTimeFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("All")),
                    DropdownMenuItem(value: 'am', child: Text("AM")),
                    DropdownMenuItem(value: 'pm', child: Text("PM")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedTimeFilter = value;
                      });
                      fetchAppointments();
                    }
                  },
                ),
              ],
            ),
          ),

          // Appointments list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : appointments.isEmpty
                ? const Center(child: Text("No appointments found."))
                : ListView.builder(
                    itemCount: appointments.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];
                      final doctorName = appointment['doctorname'] ?? 'Unknown';
                      final doctorImage = appointment['doctorprofileImage'];
                      final date = appointment['date'];
                      final time = appointment['time'];
                      final status = appointment['status'] ?? 'Pending';

                      return GestureDetector(
                        onTap: () => _showAppointmentDetail(appointment),
                        child: Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: doctorImage != null
                                      ? NetworkImage(doctorImage)
                                      : null,
                                  backgroundColor: Colors.grey[300],
                                  child: doctorImage == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                // Doctor info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doctorName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("$date"),
                                      Text("$time"),
                                    ],
                                  ),
                                ),

                                // Status badge
                                Column(
                                  children: [
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
                                    if (status.toLowerCase() == 'completed' &&
                                        !(appointment['alreadyRated'] ??
                                            false)) ...[
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showRateDoctorDialog(appointment),
                                        icon: const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                        label: const Text("Rate"),
                                      ),
                                    ],
                                  ],
                                ),
                                // More icon
                                PopupMenuButton<String>(
                                  onSelected: (value) =>
                                      _handleMenuAction(value, appointment),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'cancel',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text("Cancel"),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reschedule',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_calendar,
                                            color: Colors.orange,
                                            size: 20,
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
