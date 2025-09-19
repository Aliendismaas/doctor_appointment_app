import 'dart:io';
import 'package:doctor/admin/pickloc.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EditHealthCenterPage extends StatefulWidget {
  final Map<String, dynamic> centerData;

  const EditHealthCenterPage({super.key, required this.centerData});

  @override
  State<EditHealthCenterPage> createState() => _EditHealthCenterPageState();
}

class _EditHealthCenterPageState extends State<EditHealthCenterPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController contactController;
  late List<String> selectedServices;
  late String? selectedType;
  XFile? pickedImage;
  String? existingImageUrl;
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
    final data = widget.centerData;

    nameController = TextEditingController(text: data['name'] ?? '');
    emailController = TextEditingController(text: data['email'] ?? '');
    contactController = TextEditingController(text: data['contact'] ?? '');
    selectedType = data['type'];
    existingImageUrl = data['image_url'];

    selectedServices =
        (data['services'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final lat = data['latitude'] is double
        ? data['latitude']
        : (data['latitude'] is int
              ? (data['latitude'] as int).toDouble()
              : null);
    final lng = data['longitude'] is double
        ? data['longitude']
        : (data['longitude'] is int
              ? (data['longitude'] as int).toDouble()
              : null);
    if (lat != null && lng != null) {
      selectedLocation = LatLng(lat, lng);
    }

    fetchServices();
  }

  Future<void> fetchServices() async {
    final res = await supabase.from('Services').select();
    setState(() {
      allServices = res;
    });
  }

  Future<void> _showServicesDialog(BuildContext context) async {
    final allServiceNames = allServices
        .map<String>((e) => e['name'] as String)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                  ...allServiceNames.map((service) {
                    final isSelected = selectedServices.contains(service);
                    return CheckboxListTile(
                      title: Text(service),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedServices.add(service);
                          } else {
                            selectedServices.remove(service);
                          }
                        });
                      },
                    );
                  }),
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
    final fileBytes = await image.readAsBytes();

    final mimeType =
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
          fileBytes,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
        );

    if (res.isNotEmpty) {
      return supabase.storage.from('avatars').getPublicUrl(fileName);
    }
    return null;
  }

  Future<void> saveChanges() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final contact = contactController.text.trim();

    if (name.isEmpty || selectedType == null || selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String? imageUrl = existingImageUrl;

      // Upload new image if picked
      if (pickedImage != null) {
        imageUrl = await uploadImage(pickedImage!);
      }

      await supabase
          .from('HealthCenters')
          .update({
            'name': name,
            'type': selectedType,
            'email': email,
            'contact': contact,
            'services': selectedServices,
            'latitude': selectedLocation!.latitude,
            'longitude': selectedLocation!.longitude,
            'image_url': imageUrl,
          })
          .eq('id', widget.centerData['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Health center updated successfully")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => pickedImage = result);
    }
  }

  Future<void> pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );

    if (result != null) {
      setState(() {
        selectedLocation = result;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Health Center")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        image: pickedImage != null
                            ? DecorationImage(
                                image: FileImage(File(pickedImage!.path)),
                                fit: BoxFit.cover,
                              )
                            : (existingImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(existingImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                      ),
                      child: (pickedImage == null && existingImageUrl == null)
                          ? const Center(
                              child: Text("Tap to pick health center image"),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: types
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedType = value),
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contact'),
                  ),
                  const SizedBox(height: 10),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Select Services:"),
                  ),
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
                  const SizedBox(height: 10),

                  if (selectedLocation != null)
                    SizedBox(
                      height: 150,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: selectedLocation!,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('selected-location'),
                            position: selectedLocation!,
                          ),
                        },
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                      ),
                    ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: Text(
                      selectedLocation == null
                          ? "Pick Location"
                          : "Change Location (${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)})",
                    ),
                    onPressed: pickLocation,
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save Changes"),
                    onPressed: saveChanges,
                  ),
                ],
              ),
            ),
    );
  }
}
