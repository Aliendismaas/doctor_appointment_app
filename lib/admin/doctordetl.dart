import 'package:doctor/admin/healthprofile.dart';
import 'package:doctor/user/chat.dart';
import 'package:doctor/user/makeappointment.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorDetailPage extends StatefulWidget {
  final Map<String, dynamic> doctorData;

  const DoctorDetailPage({super.key, required this.doctorData});

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool isFavorite = false;
  bool isLoadingFavorite = true;
  late String currentUserId;

  late TabController _tabController;
  List<Map<String, dynamic>> reviews = [];
  bool isLoadingReviews = false;

  List<Map<String, dynamic>> similarDoctors = [];
  bool isLoadingSimilar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchFavoriteStatus();
    fetchSimilarDoctors();
  }

  Future<void> fetchFavoriteStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    currentUserId = user.id;

    final res = await supabase
        .from('favorites')
        .select()
        .eq('user_id', currentUserId)
        .eq('doctor_id', widget.doctorData['userId'])
        .maybeSingle();

    setState(() {
      isFavorite = res != null;
      isLoadingFavorite = false;
    });
  }

  Future<void> toggleFavorite() async {
    try {
      String message;

      if (isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', currentUserId)
            .eq('doctor_id', widget.doctorData['userId']);
        message = 'Removed from favorites';
      } else {
        await supabase.from('favorites').insert({
          'user_id': currentUserId,
          'doctor_id': widget.doctorData['userId'],
        });
        message = 'Added to favorites';
      }

      setState(() {
        isFavorite = !isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.blue),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    return await supabase.from('Users').select().eq('userId', user.id).single();
  }

  Future<void> fetchReviews() async {
    setState(() => isLoadingReviews = true);

    try {
      final res = await supabase
          .from('DoctorRatings')
          .select('patient_id, rating, review, created_at')
          .eq('doctor_id', widget.doctorData['userId']);

      List<Map<String, dynamic>> reviewsWithUsers = [];

      for (var r in res) {
        final patient = await supabase
            .from('Users')
            .select('username, profileImage')
            .eq('userId', r['patient_id'])
            .maybeSingle();

        reviewsWithUsers.add({...r, 'patient': patient});
      }

      setState(() {
        reviews = reviewsWithUsers;
        isLoadingReviews = false;
      });
    } catch (e) {
      print("Error fetching reviews: $e");
      setState(() => isLoadingReviews = false);
    }
  }

  Future<Map<String, dynamic>?> fetchHealthCenter(String id) async {
    if (id.isEmpty) return null;
    try {
      final res = await supabase
          .from('HealthCenters')
          .select()
          .eq('id', id)
          .maybeSingle();
      return res;
    } catch (e) {
      print("Error fetching HealthCenter: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDoctorById(String id) async {
    try {
      final res = await supabase
          .from('Users')
          .select()
          .eq('userId', id)
          .maybeSingle();
      return res;
    } catch (e) {
      print("Error fetching doctor details: $e");
      return null;
    }
  }

  Future<void> fetchSimilarDoctors() async {
    final specialization = List<String>.from(
      widget.doctorData['specialization'] ?? [],
    );

    if (specialization.isEmpty) return;

    setState(() => isLoadingSimilar = true);

    try {
      final res = await supabase
          .from('Users')
          .select('userId, username, profileImage, specialization, workat')
          .overlaps('specialization', specialization)
          .neq('userId', widget.doctorData['userId']); // exclude current doctor

      setState(() {
        similarDoctors = List<Map<String, dynamic>>.from(res);
        isLoadingSimilar = false;
      });
    } catch (e) {
      print("Error fetching similar doctors: $e");
      setState(() => isLoadingSimilar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorData = widget.doctorData;
    final profileImage = doctorData['profileImage'];
    final username = doctorData['username'];
    final email = doctorData['email'];
    final contact = doctorData['contact'];
    final description = doctorData['description'];
    final specialization = List<String>.from(
      doctorData['specialization'] ?? [],
    );
    final workingDays = List<String>.from(doctorData['workingday'] ?? []);
    final workat = doctorData['workat'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          username ?? 'Doctor',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D0EB5), Color(0xFF4059F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: isLoadingFavorite
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.redAccent : Colors.white,
                  ),
            onPressed: isLoadingFavorite ? null : toggleFavorite,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicator: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D0EB5), Color(0xFF4059F1)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (index) {
            if (index == 1 && reviews.isEmpty) {
              fetchReviews();
            }
          },
          tabs: const [
            Tab(text: "About"),
            Tab(text: "Reviews"),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          // ABOUT TAB
          _buildAboutTab(
            profileImage,
            username,
            email,
            contact,
            description,
            specialization,
            workat,
            workingDays,
          ),

          // REVIEWS TAB
          isLoadingReviews
              ? const Center(child: CircularProgressIndicator())
              : reviews.isEmpty
              ? const Center(child: Text("No reviews yet"))
              : ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final r = reviews[index];
                    final patient = r['patient'];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: patient?['profileImage'] != null
                            ? NetworkImage(patient['profileImage'])
                            : null,
                        child: patient?['profileImage'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(patient?['username'] ?? "Unknown"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < (r['rating'] ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              ),
                            ),
                          ),
                          Text(r['review'] ?? ''),
                          Text(
                            r['created_at'] != null
                                ? DateTime.parse(
                                    r['created_at'],
                                  ).toLocal().toString()
                                : '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),

      // Bottom buttons (Chat & Book)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D0EB5), Color(0xFF4059F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("Chat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6D0EB5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                onPressed: () async {
                  final currentUserData = await fetchCurrentUserData();
                  if (currentUserData == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to fetch user data'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        doctorData: doctorData,
                        userData: currentUserData,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Book Appointment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4059F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                onPressed: () async {
                  final currentUserData = await fetchCurrentUserData();
                  if (currentUserData == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to fetch user data'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookAppointmentPage(
                        doctorData: doctorData,
                        userData: currentUserData,
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

  Widget _buildAboutTab(
    String? profileImage,
    String? username,
    String? email,
    String? contact,
    String? description,
    List<String> specialization,
    String? workat,
    List<String> workingDays,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor image card
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: profileImage != null
                ? Image.network(
                    profileImage,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 240,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 80),
                  ),
          ),
          const SizedBox(height: 16),

          // Doctor basic info
          Center(
            child: Column(
              children: [
                Text(
                  username ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D0EB5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(email ?? '', style: const TextStyle(color: Colors.grey)),
                Text(contact ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (description != null) _infoSection("About", description),

          _infoSection("Specializations", specialization.join(", ")),

          const SizedBox(height: 12),
          _infoSection("Available Days", workingDays.join(", ")),

          const SizedBox(height: 30),

          // Similar doctors section
          const Text(
            "Other Similar Doctors",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          isLoadingSimilar
              ? const Center(child: CircularProgressIndicator())
              : similarDoctors.isEmpty
              ? const Text("No similar doctors found")
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: similarDoctors.map((doc) {
                      return GestureDetector(
                        onTap: () async {
                          final fullDoctor = await fetchDoctorById(
                            doc['userId'],
                          );
                          if (fullDoctor != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DoctorDetailPage(doctorData: fullDoctor),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Failed to load doctor details"),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade200,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: doc['profileImage'] != null
                                    ? NetworkImage(doc['profileImage'])
                                    : null,
                                child: doc['profileImage'] == null
                                    ? const Icon(Icons.person, size: 30)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                doc['username'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (doc['specialization'] != null)
                                Text(
                                  (doc['specialization'] as List<dynamic>).join(
                                    ", ",
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE7F6), Color(0xFFE3F2FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF6D0EB5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
