import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ManageServicesPage extends StatefulWidget {
  const ManageServicesPage({super.key});

  @override
  State<ManageServicesPage> createState() => _ManageServicesPageState();
}

class _ManageServicesPageState extends State<ManageServicesPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> allServices = [];
  List<dynamic> filteredServices = [];
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchServices();
    searchController.addListener(_searchServices);
  }

  Future<void> fetchServices() async {
    final res = await supabase.from('Services').select().order('name');
    setState(() {
      allServices = res;
      filteredServices = res;
      isLoading = false;
    });
  }

  void _searchServices() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredServices = allServices.where((service) {
        final name = service['name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteService(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Service"),
        content: const Text("Are you sure you want to delete this service?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('Services').delete().eq('id', id);
      fetchServices();
    }
  }

  Future<void> _editService(Map service) async {
    final nameController = TextEditingController(text: service['name']);
    XFile? newImage;
    String? imageUrl = service['image_url'];
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Edit Service"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    newImage = picked;
                    setModalState(() {});
                  }
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: newImage != null
                      ? FileImage(File(newImage!.path))
                      : imageUrl != null
                      ? NetworkImage(imageUrl) as ImageProvider
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: newImage == null && imageUrl == null
                      ? const Icon(Icons.image)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Service Name"),
              ),
              if (isUpdating)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          actions: isUpdating
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      setModalState(() => isUpdating = true);

                      String? finalImageUrl = imageUrl;

                      if (newImage != null) {
                        final fileExt = newImage!.path.split('.').last;
                        final fileName =
                            "services/${const Uuid().v4()}.$fileExt";
                        final bytes = await newImage!.readAsBytes();

                        final uploadRes = await supabase.storage
                            .from('avatars')
                            .uploadBinary(
                              fileName,
                              bytes,
                              fileOptions: FileOptions(
                                upsert: true,
                                contentType: 'image/$fileExt',
                              ),
                            );

                        if (uploadRes.isNotEmpty) {
                          finalImageUrl = supabase.storage
                              .from('avatars')
                              .getPublicUrl(fileName);
                        }
                      }

                      await supabase
                          .from('Services')
                          .update({
                            'name': nameController.text.trim(),
                            'image_url': finalImageUrl,
                          })
                          .eq('id', service['id']);

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        fetchServices();
                      }
                    },
                    child: const Text("Save"),
                  ),
                ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Services"),
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    // 🔍 Search bar
                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search Services",
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
                    ),
                    const SizedBox(height: 16),

                    // 🏥 List of services
                    Expanded(
                      child: filteredServices.isEmpty
                          ? const Center(
                              child: Text(
                                "No services found",
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredServices.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final service = filteredServices[index];
                                final imageUrl = service['image_url'];
                                final name = service['name'];

                                return Card(
                                  color: Colors.white.withOpacity(0.9),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: CircleAvatar(
                                      radius: 28,
                                      backgroundImage: imageUrl != null
                                          ? NetworkImage(imageUrl)
                                          : null,
                                      backgroundColor:
                                          Colors.deepPurple.shade300,
                                      child: imageUrl == null
                                          ? const Icon(
                                              Icons.medical_services,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () =>
                                              _editService(service),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteService(service['id']),
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
