import 'package:doctor/admin/doctordetl.dart';
import 'package:doctor/admin/healthprofile.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final user = Supabase.instance.client.auth.currentUser;
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
    fetchDoctors(); // 👈 Add this
  }

  Future<void> fetchDoctors() async {
    final res = await supabase
        .from('Users')
        .select()
        .eq('role', 'doctor'); // Fetch only doctors

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Services",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final imageUrl = service['image_url'];
                      final name = service['name'];
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: imageUrl != null
                                ? NetworkImage(imageUrl)
                                : null,
                            backgroundColor: Colors.grey[300],
                            child: imageUrl == null
                                ? const Icon(Icons.image_not_supported)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(name, style: const TextStyle(fontSize: 14)),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Health Centers
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: healthCenters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final center = healthCenters[index];
                      final imageUrl = center['image_url'];
                      final name = center['name'];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HealthCenterProfilePage(centerData: center),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[300],
                                image: imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imageUrl == null
                                  ? const Center(
                                      child: Icon(Icons.image_not_supported),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 80,
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  "Doctors",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Doctor Grid
                isDoctorsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          if (constraints.maxWidth >= 600) crossAxisCount = 3;
                          if (constraints.maxWidth >= 900) crossAxisCount = 4;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: doctors.length,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 200,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent:
                                      220, // 👈 Controls vertical height
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
                                      builder: (_) =>
                                          DoctorDetailPage(doctorData: doctor),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      imageUrl != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                imageUrl,
                                                width: double.infinity,
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Container(
                                              width: double.infinity,
                                              height: 130,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.person,
                                                size: 50,
                                              ),
                                            ),
                                      const SizedBox(height: 6),
                                      Text(
                                        username ?? 'No Name',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
