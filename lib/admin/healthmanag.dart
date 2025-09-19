import 'package:doctor/admin/edithealth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageHealthCentersPage extends StatefulWidget {
  const ManageHealthCentersPage({super.key});

  @override
  State<ManageHealthCentersPage> createState() =>
      _ManageHealthCentersPageState();
}

class _ManageHealthCentersPageState extends State<ManageHealthCentersPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> allCenters = [];
  List<dynamic> filteredCenters = [];

  bool isLoading = true;
  String searchQuery = '';
  String? filterType;

  final List<String> types = [
    'Hospital',
    'Clinic',
    'Pharmacy',
    'Laboratory',
    'Dispensary',
    'Diagnostic Center',
    'Dental Clinic',
    'Health Post',
  ];

  @override
  void initState() {
    super.initState();
    fetchCenters();
  }

  Future<void> fetchCenters() async {
    setState(() => isLoading = true);
    final res = await supabase
        .from('HealthCenters')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      allCenters = res;
      applyFilters();
      isLoading = false;
    });
  }

  void applyFilters() {
    setState(() {
      filteredCenters = allCenters.where((center) {
        final nameMatch = center['name'].toString().toLowerCase().contains(
          searchQuery.toLowerCase(),
        );

        final typeMatch = filterType == null || center['type'] == filterType;

        return nameMatch && typeMatch;
      }).toList();
    });
  }

  Future<int> getTeamSize(String centerName) async {
    final res = await supabase
        .from('Users')
        .select('id')
        .eq('workAt', centerName);

    return res.length;
  }

  Future<void> deleteCenter(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this health center?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('HealthCenters').delete().eq('id', id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health center deleted')));
      fetchCenters();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting center: $e')));
    }
  }

  void editCenter(Map<String, dynamic> centerData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditHealthCenterPage(centerData: centerData),
      ),
    ).then((updated) {
      if (updated == true) {
        fetchCenters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Health Centers'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : RefreshIndicator(
                onRefresh: fetchCenters,
                child: Column(
                  children: [
                    // 🔍 Search bar
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name...',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          searchQuery = value;
                          applyFilters();
                        },
                      ),
                    ),

                    // ⛳ Filter dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: filterType,
                        hint: const Text(
                          "Filter by type",
                          style: TextStyle(color: Colors.white),
                        ),
                        dropdownColor: Colors.deepPurple,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white24,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text("All Types"),
                          ),
                          ...types.map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          filterType = value;
                          applyFilters();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 🏥 Filtered list
                    Expanded(
                      child: filteredCenters.isEmpty
                          ? const Center(
                              child: Text(
                                "No health centers found",
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredCenters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final center = filteredCenters[index];
                                final imageUrl = center['image_url'];
                                final name = center['name'];
                                final type = center['type'];
                                final id = center['id'];

                                return Card(
                                  color: Colors.white.withOpacity(0.9),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              imageUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : CircleAvatar(
                                            backgroundColor:
                                                Colors.deepPurple.shade300,
                                            child: const Icon(
                                              Icons.local_hospital,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(type),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          editCenter(center);
                                        } else if (value == 'delete') {
                                          deleteCenter(id);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
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
      ),
    );
  }
}
