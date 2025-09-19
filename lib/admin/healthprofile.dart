import 'package:doctor/admin/doctordetl.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthCenterProfilePage extends StatelessWidget {
  final Map<String, dynamic> centerData;

  const HealthCenterProfilePage({super.key, required this.centerData});

  Future<List<Map<String, dynamic>>> fetchDoctors() async {
    try {
      final res = await Supabase.instance.client
          .from('Users')
          .select()
          .eq('workat', centerData['id']);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("Error fetching doctors: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = centerData['image_url'] as String?;
    final String name = centerData['name']?.toString() ?? 'Unknown';
    final String type = centerData['type']?.toString() ?? '';
    final String email = centerData['email']?.toString() ?? '-';
    final String contact = centerData['contact']?.toString() ?? '-';
    final String description = centerData['description']?.toString() ?? '';

    final List<String> services = List<String>.from(
      centerData['services'] ?? [],
    );

    final double? lat = centerData['latitude'] != null
        ? (centerData['latitude'] as num).toDouble()
        : null;
    final double? lng = centerData['longitude'] != null
        ? (centerData['longitude'] as num).toDouble()
        : null;

    final LatLng? position = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3C47A5), Color(0xFF8FA5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📌 Header Image
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                gradient: const LinearGradient(
                  colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 220,
                        color: Colors.black12,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 📌 Name + Type
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C47A5),
              ),
            ),
            if (type.isNotEmpty)
              Text(
                type,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

            const SizedBox(height: 20),

            // 📌 Map Card
            if (position != null)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: position,
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('location'),
                              position: position,
                              infoWindow: InfoWindow(title: name),
                            ),
                          },
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          onMapCreated: (controller) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Location: (${lat?.toStringAsFixed(5)}, ${lng?.toStringAsFixed(5)})",
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 📌 Description
            if (description.isNotEmpty)
              _buildCard(
                title: "About",
                child: Text(description, style: const TextStyle(fontSize: 14)),
              ),

            // 📌 Contact
            _buildCard(
              title: "Contact Info",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.email, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(email, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        contact,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 📌 Services
            _buildCard(
              title: "Services Offered",
              child: services.isEmpty
                  ? const Text(
                      "No services listed",
                      style: TextStyle(color: Colors.white70),
                    )
                  : Wrap(
                      spacing: 8,
                      children: services.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            // 📌 Doctors
            _buildCard(
              title: "Doctors at this Health Center",
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchDoctors(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      "Error loading doctors",
                      style: TextStyle(color: Colors.white70),
                    );
                  }
                  final doctors = snapshot.data ?? [];
                  if (doctors.isEmpty) {
                    return const Text(
                      "No doctors found",
                      style: TextStyle(color: Colors.white70),
                    );
                  }
                  return Column(
                    children: doctors.map((doc) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: const Color(0xFF3C47A5).withOpacity(0.8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: doc['profileImage'] != null
                                ? NetworkImage(doc['profileImage'])
                                : null,
                            child: doc['profileImage'] == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(
                            doc['username'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DoctorDetailPage(doctorData: doc),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔮 Reusable Gradient Card
  Widget _buildCard({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3C47A5), Color(0xFF8FA5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
