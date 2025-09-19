import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  List<Map<String, dynamic>> favoriteDoctors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFavoriteDoctors();
  }

  Future<void> fetchFavoriteDoctors() async {
    setState(() => isLoading = true);

    try {
      // Fetch all favorite doctor_ids for current user
      final favoriteResponse = await supabase
          .from('favorites')
          .select('doctor_id')
          .eq('user_id', userId!);

      final doctorIds = List<String>.from(
        (favoriteResponse as List).map((row) => row['doctor_id']),
      );

      // Fetch doctor details from Users table
      if (doctorIds.isNotEmpty) {
        final doctorsResponse = await supabase
            .from('Users')
            .select('userId, username, profileImage')
            .inFilter('userId', doctorIds);
        setState(() {
          favoriteDoctors = List<Map<String, dynamic>>.from(doctorsResponse);
          isLoading = false;
        });
      } else {
        setState(() {
          favoriteDoctors = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching favorites: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> removeFromFavorites(String doctorId) async {
    try {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId!)
          .eq('doctor_id', doctorId);

      // Refresh favorites list
      fetchFavoriteDoctors();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoriteDoctors.isEmpty
          ? const Center(child: Text("You haven't favorited any doctors yet."))
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Two items per row
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: favoriteDoctors.length,
                itemBuilder: (context, index) {
                  final doctor = favoriteDoctors[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: doctor['profileImage'] != null
                              ? NetworkImage(doctor['profileImage'])
                              : null,
                          child: doctor['profileImage'] == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          doctor['username'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          onPressed: () =>
                              removeFromFavorites(doctor['userId']),
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text("Remove"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
