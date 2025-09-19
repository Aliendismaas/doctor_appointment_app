import 'package:doctor/admin/addservice.dart';
import 'package:doctor/admin/admindrawer.dart';
import 'package:doctor/admin/doctordetl.dart';
import 'package:doctor/admin/doctorregi.dart';
import 'package:doctor/admin/healthprofile.dart';
import 'package:doctor/admin/healthregi.dart' show RegisterHealthCenterPage;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Admindash extends StatefulWidget {
  const Admindash({super.key});

  @override
  State<Admindash> createState() => _AdmindashState();
}

class _AdmindashState extends State<Admindash> {
  final supabase = Supabase.instance.client;
  List<dynamic> services = [];
  bool isLoading = true;
  List<dynamic> healthCenters = [];
  bool isHealthCentersLoading = true;
  List<dynamic> doctors = [];
  bool isDoctorsLoading = true;

  @override
  void initState() {
    super.initState();
    fetchServices();
    fetchHealthCenters();
    fetchDoctors();
  }

  Future<void> fetchDoctors() async {
    final res = await supabase.from('Users').select().eq('role', 'doctor');
    setState(() {
      doctors = res;
      isDoctorsLoading = false;
    });
  }

  Future<void> fetchHealthCenters() async {
    final res = await supabase.from('HealthCenters').select();
    setState(() {
      healthCenters = res;
      isHealthCentersLoading = false;
    });
  }

  Future<void> fetchServices() async {
    final res = await supabase.from('Services').select();
    setState(() {
      services = res;
      isLoading = false;
    });
  }

  void _showAdminDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFEAECEA),
        title: const Text(
          "What would you like to add?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGradientButton(
              icon: Icons.medical_services,
              label: "Services",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddServicePage()),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildGradientButton(
              icon: Icons.local_hospital,
              label: "Health Center",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterHealthCenterPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildGradientButton(
              icon: Icons.person,
              label: "Doctor",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorRegisterPage()),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          ' Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3C47A5), Color(0xFF6C7BD9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 6,
        shadowColor: Colors.black45,
      ),
      drawer: const Admindrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle("Services"),
                const SizedBox(height: 12),
                _buildHorizontalList(services, "service"),

                const SizedBox(height: 20),
                _buildSectionTitle("Health Centers"),
                const SizedBox(height: 12),
                _buildHorizontalList(healthCenters, "center"),

                const SizedBox(height: 20),
                _buildSectionTitle("Doctors"),
                const SizedBox(height: 12),
                isDoctorsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDoctorsGrid(),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => _showAdminDialog(context),
          child: const Icon(Icons.add, size: 30),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF3C47A5),
        shadows: [
          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(List items, String type) {
    return SizedBox(
      height: type == "service" ? 110 : 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final data = items[index];
          final imageUrl = data['image_url'];
          final name = data['name'];

          final card = Container(
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );

          // 👇 restore HealthCenter navigation
          return type == "center"
              ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            HealthCenterProfilePage(centerData: data),
                      ),
                    );
                  },
                  child: card,
                )
              : card;
        },
      ),
    );
  }

  Widget _buildDoctorsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth >= 600) crossAxisCount = 3;
        if (constraints.maxWidth >= 900) crossAxisCount = 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: doctors.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.7,
          ),
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            final imageUrl = doctor['profileImage'];
            final username = doctor['username'];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DoctorDetailPage(doctorData: doctor),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        username ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGradientButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style:
          ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).copyWith(
            backgroundColor: MaterialStateProperty.all(Colors.transparent),
            shadowColor: MaterialStateProperty.all(Colors.transparent),
          ),
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
