import 'package:doctor/doctor/doctorappointments.dart';
import 'package:doctor/user/editprofil.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Doctorprofile extends StatefulWidget {
  const Doctorprofile({super.key});

  @override
  State<Doctorprofile> createState() => _DoctorprofileState();
}

class _DoctorprofileState extends State<Doctorprofile> {
  final userId = Supabase.instance.client.auth.currentUser?.id;

  Map<String, dynamic>? userData;
  List<dynamic> medicalHistory = [];
  bool isHistoryLoading = true;
  bool isLoading = true;
  double avgRating = 0;
  int totalAppointments = 0;
  bool isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchDoctorReviews();
    fetchDoctorStats(); // ⬅ Added
  }

  Future<void> fetchDoctorStats() async {
    if (userId == null) return;

    try {
      // Fetch ratings
      final ratingsResponse = await Supabase.instance.client
          .from('DoctorRatings')
          .select('rating')
          .eq('doctor_id', userId!);

      double avg = 0;
      if (ratingsResponse.isNotEmpty) {
        final ratings = ratingsResponse.map((r) => r['rating'] as num).toList();
        avg = ratings.reduce((a, b) => a + b) / ratings.length;
      }

      // Fetch total appointments
      final appointmentsResponse = await Supabase.instance.client
          .from('appointments')
          .select('id')
          .eq('doctorid', userId!);

      final count = appointmentsResponse.length;

      setState(() {
        avgRating = avg;
        totalAppointments = count;
        isStatsLoading = false;
      });
    } catch (e) {
      print("Error fetching doctor stats: $e");
      setState(() => isStatsLoading = false);
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
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchDoctorReviews() async {
    if (userId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('DoctorRatings')
          .select('rating, review, created_at, patient_id')
          .eq('doctor_id', userId!)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> historyWithDoctor = [];

      for (var history in response) {
        final patientRes = await Supabase.instance.client
            .from('Users')
            .select('userId, username, profileImage')
            .eq('userId', history['patient_id'])
            .maybeSingle();

        historyWithDoctor.add({...history, 'patient': patientRes});
      }

      setState(() {
        medicalHistory = historyWithDoctor;
        isHistoryLoading = false;
      });
    } catch (e) {
      print('Error fetching doctor reviews: $e');
      setState(() => isHistoryLoading = false);
    }
  }

  void openAppointmentsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorAppointmentsPage()),
    );
  }

  void openPhotoPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoPage(userData: userData!)),
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
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
          ? const Center(child: Text("User not found"))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Cover + Profile Image
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade800,
                              Colors.blue.shade400,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          image: userData!['coverImage'] != null
                              ? DecorationImage(
                                  image: NetworkImage(userData!['coverImage']),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.3),
                                    BlendMode.darken,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: -60,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
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
                  const SizedBox(height: 70),

                  // Doctor Info Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              userData!['username'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(userData!['email']),
                            Text(userData!['contact']),
                            const SizedBox(height: 8),

                            isStatsLoading
                                ? const CircularProgressIndicator()
                                : Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            avgRating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "($totalAppointments appointments)",
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        Icons.calendar_today,
                        "Appointments",
                        onTap: openAppointmentsPage,
                      ),
                      _buildActionButton(
                        Icons.photo,
                        "Photo",
                        onTap: openPhotoPage,
                      ),
                      _buildActionButton(
                        Icons.edit,
                        "Edit",
                        onTap: openEditProfile,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Reviews Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Patient Reviews",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  isHistoryLoading
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        )
                      : medicalHistory.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No reviews yet."),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: medicalHistory.length,
                          itemBuilder: (context, index) {
                            final review = medicalHistory[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundImage:
                                            review['patient']?['profileImage'] !=
                                                null
                                            ? NetworkImage(
                                                review['patient']['profileImage'],
                                              )
                                            : const AssetImage(
                                                    "assets/profile.png",
                                                  )
                                                  as ImageProvider,
                                        radius: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              review['patient']?['username'] ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Row(
                                              children: List.generate(
                                                5,
                                                (starIndex) => Icon(
                                                  starIndex < review['rating']
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(review['review'] ?? ''),
                                            const SizedBox(height: 4),
                                            Text(
                                              review['created_at'] != null
                                                  ? _formatDate(
                                                      review['created_at'],
                                                    ).toString()
                                                  : '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildActionButton(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString).toLocal();
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

class PhotoPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const PhotoPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Photos'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Cover Image
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[300], // Fallback color
                image: userData['coverImage'] != null
                    ? DecorationImage(
                        image: NetworkImage(userData['coverImage']),
                        fit: BoxFit.cover,
                      )
                    : const DecorationImage(
                        image: AssetImage("assets/cover.png"),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const Text(
              "Cover Photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // Profile Image
            CircleAvatar(
              radius: 80,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 75,
                backgroundImage: userData['profileImage'] != null
                    ? NetworkImage(userData['profileImage'])
                    : const AssetImage("assets/profile.png") as ImageProvider,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Profile Photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
