import 'package:doctor/admin/admindrawer.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  int users = 0, doctors = 0, services = 0, centers = 0, appointments = 0;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future<void> loadSummary() async {
    final supabase = Supabase.instance.client;

    final userRes = await supabase.from('Users').select().eq('role', 'user');
    final doctorRes = await supabase
        .from('Users')
        .select()
        .eq('role', 'doctor');
    final serviceRes = await supabase.from('Services').select();
    final centerRes = await supabase.from('HealthCenters').select();
    final appointmentRes = await supabase.from('appointments').select();

    setState(() {
      users = userRes.length;
      doctors = doctorRes.length;
      services = serviceRes.length;
      centers = centerRes.length;
      appointments = appointmentRes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Summary', icon: Icons.dashboard),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard('Users', users, Icons.person, Colors.blue),
                _summaryCard(
                  'Doctors',
                  doctors,
                  Icons.local_hospital,
                  Colors.green,
                ),
                _summaryCard(
                  'Services',
                  services,
                  Icons.medical_services,
                  Colors.teal,
                ),
                _summaryCard(
                  'Centers',
                  centers,
                  Icons.location_city,
                  Colors.orange,
                ),
                _summaryCard(
                  'Appointments',
                  appointments,
                  Icons.calendar_today,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle('User Role Distribution', icon: Icons.pie_chart),
            const SizedBox(height: 8),
            _buildRolePieChart(),
            const SizedBox(height: 24),
            _sectionTitle('📅 Filter by Date Range', icon: Icons.date_range),
            _buildDateFilter(),
            const SizedBox(height: 24),
            _sectionTitle('Appointments by Doctor', icon: Icons.bar_chart),
            _buildAppointmentsBarChart(),
            const SizedBox(height: 32),
            _sectionTitle('📈 Weekly Appointments', icon: Icons.show_chart),
            _buildLineChart(),
            const SizedBox(height: 32),
            _sectionTitle('📆 Monthly Appointment', icon: Icons.timeline),
            _buildMonthlyComparisonBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) Icon(icon, size: 20, color: Colors.blue.shade700),
        if (icon != null) const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, int count, IconData icon, Color color) {
    return SizedBox(
      width: 130,
      height: 140,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRolePieChart() {
    final total = users + doctors;
    if (total == 0) return const Text('No data available.');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  value: users.toDouble(),
                  title:
                      'Users (${((users / total) * 100).toStringAsFixed(1)}%)',
                  color: Colors.blue,
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: doctors.toDouble(),
                  title:
                      'Doctors (${((doctors / total) * 100).toStringAsFixed(1)}%)',
                  color: Colors.green,
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsBarChart() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAppointmentsPerCenter(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final data = snapshot.data!;
        return SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              barGroups: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: item['count'].toDouble(),
                      color: Colors.deepPurple,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < data.length) {
                        return Text(
                          data[index]['center'],
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAppointmentsPerCenter() async {
    final supabase = Supabase.instance.client;
    final query = supabase.from('appointments').select('doctorname');
    if (_startDate != null && _endDate != null) {
      query
          .gte('created_at', _startDate!.toIso8601String())
          .lte('created_at', _endDate!.toIso8601String());
    }
    final result = await query;

    final Map<String, int> counts = {};
    for (final item in result) {
      final center = item['doctorname'] ?? 'Unknown';
      counts[center] = (counts[center] ?? 0) + 1;
    }

    return counts.entries
        .map((e) => {'center': e.key, 'count': e.value})
        .toList();
  }

  Widget _buildLineChart() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDailyAppointments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final data = snapshot.data!;

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index >= 0 && index < data.length) {
                        return Text(
                          data[index]['day'],
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: data.asMap().entries.map((e) {
                    return FlSpot(
                      e.key.toDouble(),
                      e.value['count'].toDouble(),
                    );
                  }).toList(),
                  color: Colors.orange,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDailyAppointments() async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now();
    final lastWeek = today.subtract(const Duration(days: 6));

    final result = await supabase
        .from('appointments')
        .select('created_at')
        .gte('created_at', lastWeek.toIso8601String());

    final Map<String, int> dayCounts = {};
    for (int i = 0; i < 7; i++) {
      final day = DateFormat.E().format(lastWeek.add(Duration(days: i)));
      dayCounts[day] = 0;
    }

    for (final item in result) {
      final date = DateTime.parse(item['created_at']);
      final day = DateFormat.E().format(date);
      if (dayCounts.containsKey(day)) {
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }
    }

    return dayCounts.entries
        .map((e) => {'day': e.key, 'count': e.value})
        .toList();
  }

  Widget _buildMonthlyComparisonBarChart() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchMonthlyAppointmentGrowth(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final data = snapshot.data!;
        return SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              barGroups: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: item['count'].toDouble(),
                      color: Colors.teal,
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < data.length) {
                        return Text(
                          data[index]['month'],
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMonthlyAppointmentGrowth() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final last6Months = now.subtract(const Duration(days: 180));
    final result = await supabase
        .from('appointments')
        .select('created_at')
        .gte('created_at', last6Months.toIso8601String());

    final Map<String, int> monthlyCounts = {};
    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final month = DateFormat.MMM().format(date);
      monthlyCounts[month] = 0;
    }

    for (final item in result) {
      final created = DateTime.parse(item['created_at']);
      final month = DateFormat.MMM().format(created);
      if (monthlyCounts.containsKey(month)) {
        monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
      }
    }

    final entries = monthlyCounts.entries.toList().reversed.toList();
    return entries.map((e) => {'month': e.key, 'count': e.value}).toList();
  }

  Widget _buildDateFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            _startDate != null && _endDate != null
                ? '${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}'
                : 'Select Date Range',
          ),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
            }
          },
        ),
        if (_startDate != null || _endDate != null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
            },
          ),
      ],
    );
  }
}
