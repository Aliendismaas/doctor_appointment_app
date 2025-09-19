import 'dart:io';
import 'package:doctor/admin/pickloc.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RegisterHealthCenterPage extends StatefulWidget {
  const RegisterHealthCenterPage({super.key});

  @override
  State<RegisterHealthCenterPage> createState() =>
      _RegisterHealthCenterPageState();
}

class _RegisterHealthCenterPageState extends State<RegisterHealthCenterPage> {
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedType;
  List<String> selectedServices = [];
  XFile? pickedImage;

  bool isLoading = false;
  List<dynamic> allServices = [];
  LatLng? selectedLocation;

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
    fetchServices();
  }

  Future<void> fetchServices() async {
    final res = await supabase.from('Services').select('name');
    setState(() => allServices = res);
  }

  Future<void> _showServicesDialog(BuildContext context) async {
    final res = await supabase.from('Services').select();
    final all = res.map<String>((e) => e['name'] as String).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select Services",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...all.map((service) {
                    final isSelected = selectedServices.contains(service);
                    return CheckboxListTile(
                      title: Text(service),
                      value: isSelected,
                      onChanged: (val) {
                        setStateDialog(() {
                          val == true
                              ? selectedServices.add(service)
                              : selectedServices.remove(service);
                        });
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text("Done"),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> uploadImage(XFile image) async {
    final ext = image.path.split('.').last.toLowerCase();
    final fileName = 'healthcenters/${const Uuid().v4()}.$ext';
    final bytes = await image.readAsBytes();

    final contentType =
        {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
        }[ext] ??
        'image/jpeg';

    final res = await supabase.storage
        .from('avatars')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    return res.isNotEmpty
        ? supabase.storage.from('avatars').getPublicUrl(fileName)
        : null;
  }

  Future<void> pickImage() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result != null) setState(() => pickedImage = result);
  }

  Future<void> pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (result != null) setState(() => selectedLocation = result);
  }

  Future<void> saveHealthCenter() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final contact = contactController.text.trim();
    final description = descriptionController.text.trim();

    if (name.isEmpty ||
        selectedType == null ||
        pickedImage == null ||
        selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final imageUrl = await uploadImage(pickedImage!);

      await supabase.from('HealthCenters').insert({
        'name': name,
        'type': selectedType,
        'email': email,
        'contact': contact,
        'description': description,
        'services': selectedServices,
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'image_url': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Health center registered successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration styledInput(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Health Center")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[200],
                            image: pickedImage != null
                                ? DecorationImage(
                                    image: FileImage(File(pickedImage!.path)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: pickedImage == null
                              ? const Center(
                                  child: Text(
                                    "Tap to pick health center image",
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: nameController,
                        decoration: styledInput("Name"),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: types
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => selectedType = val),
                        decoration: styledInput("Type"),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: emailController,
                        decoration: styledInput("Email"),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: contactController,
                        decoration: styledInput("Contact"),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: styledInput("Description"),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Services:",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        onTap: () => _showServicesDialog(context),
                        decoration: InputDecoration(
                          hintText: selectedServices.isEmpty
                              ? 'Select services'
                              : selectedServices.join(', '),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.map),
                        label: Text(
                          selectedLocation == null
                              ? "Pick Location"
                              : "Picked: (${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)})",
                        ),
                        onPressed: pickLocation,
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Save Health Center"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: saveHealthCenter,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
