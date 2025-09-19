import 'package:doctor/admin/admindrawer.dart';
import 'package:doctor/admin/game/sport/addproduct.dart';
import 'package:doctor/admin/game/sport/products.dart';
import 'package:doctor/admin/healthy_tip/health_tip.dart';
import 'package:doctor/user/editprofil.dart';
import 'package:doctor/user/myappointments.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Adminprofile extends StatefulWidget {
  const Adminprofile({super.key});

  @override
  State<Adminprofile> createState() => _AdminprofileState();
}

class _AdminprofileState extends State<Adminprofile> {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  List<dynamic> medicalHistory = [];
  bool isHistoryLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchMedicalHistory();
  }

  Future<void> fetchMedicalHistory() async {
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('MedicalHistory')
          .select(
            'diagnosis, medication, created_at, appointment_id, doctor_id',
          )
          .eq('patient_id', userId!)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> historyWithDoctor = [];

      for (var history in res) {
        // Fetch doctor info
        final doctorRes = await Supabase.instance.client
            .from('Users')
            .select('userId, username, profileImage')
            .eq('userId', history['doctor_id'])
            .maybeSingle();

        // Merge doctor info into history record
        historyWithDoctor.add({
          ...history,
          'doctor': doctorRes, // Will contain username + profileImage
        });
      }

      setState(() {
        medicalHistory = historyWithDoctor;
        isHistoryLoading = false;
      });
    } catch (e) {
      print('Error fetching medical history: $e');
      setState(() {
        isHistoryLoading = false;
      });
    }
  }

  Future<void> fetchUserData() async {
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('Users')
          .select('userId, username, email, contact, profileImage, coverImage')
          .eq('userId', userId!)
          .single();

      setState(() {
        userData = response;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void openAppointmentsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyAppointmentsPage(userId: userId!)),
    );
  }

  void openPhotoPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductListPage()),
    );
  }

  void openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('profile')),
      drawer: Admindrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
          ? const Center(child: Text("User not found"))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Cover Image
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300], // Fallback color
                          image: userData!['coverImage'] != null
                              ? DecorationImage(
                                  image: NetworkImage(userData!['coverImage']),
                                  fit: BoxFit.cover,
                                )
                              : const DecorationImage(
                                  image: AssetImage("assets/cover.png"),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // Profile Image
                      Positioned(
                        bottom: -50,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 55,
                            backgroundImage: userData!['profileImage'] != null
                                ? NetworkImage(userData!['profileImage'])
                                : const AssetImage("assets/profile.png")
                                      as ImageProvider,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60), // Space for profile image overlap
                  Text(
                    "Username: ${userData!['username']}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Email: ${userData!['email']}"),
                  Text("Contact: ${userData!['contact']}"),
                  const SizedBox(height: 30),

                  // Responsive Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text(
                            "Appointment",
                            style: TextStyle(
                              color: Color.fromARGB(255, 210, 218, 226),
                            ),
                          ),
                          onPressed: openAppointmentsPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo),
                          label: const Text(""),
                          onPressed: openPhotoPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text(""),
                          onPressed: openEditProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Medical History Section
                  const Divider(thickness: 1),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "My Medical History",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  isHistoryLoading
                      ? const CircularProgressIndicator()
                      : medicalHistory.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("No medical history found."),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: medicalHistory.length,
                          itemBuilder: (context, index) {
                            final history = medicalHistory[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      history['doctor']?['profileImage'] != null
                                      ? NetworkImage(
                                          history['doctor']['profileImage'],
                                        )
                                      : const AssetImage("assets/profile.png")
                                            as ImageProvider,
                                ),
                                title: Text(
                                  "Dr. ${history['doctor']?['username'] ?? 'Unknown'}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Diagnosis: ${history['diagnosis'] ?? 'N/A'}",
                                    ),
                                    Text(
                                      "Medication: ${history['medication'] ?? 'N/A'}",
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Date: ${DateTime.tryParse(history['created_at'] ?? '')?.toLocal().toString().split(' ')[0] ?? ''}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
