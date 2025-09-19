import 'dart:io';
import 'package:doctor/auth/authServices.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DoctorRegisterPage extends StatefulWidget {
  const DoctorRegisterPage({super.key});

  @override
  State<DoctorRegisterPage> createState() => _DoctorRegisterPageState();
}

class _DoctorRegisterPageState extends State<DoctorRegisterPage> {
  final authService = AuthService();
  final supabase = Supabase.instance.client;
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final descriptionController = TextEditingController();
  XFile? profileImage;
  List<String> specializations = [];
  List<String> selectedSpecs = [];
  List<String> workingDays = [];
  List<String> selectedDays = [];
  List<dynamic> healthCenters = [];
  String? selectedHealthCenter;
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    fetchServices();
    fetchHealthCenters();
    workingDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        profileImage = image;
      });
    }
  }

  Future<String?> uploadProfileImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final ext = image.path.split('.').last.toLowerCase();
    final fileName = 'doctors/${const Uuid().v4()}.$ext';

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

    if (res.isNotEmpty) {
      return supabase.storage.from('avatars').getPublicUrl(fileName);
    }
    return null;
  }

  Future<void> _showSpecializationDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select Specializations",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  SizedBox(
                    height: 300,
                    child: ListView(
                      children: specializations.map((spec) {
                        final isSelected = selectedSpecs.contains(spec);
                        return CheckboxListTile(
                          title: Text(spec),
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedSpecs.add(spec);
                              } else {
                                selectedSpecs.remove(spec);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
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

  Future<void> fetchServices() async {
    final res = await supabase.from('Services').select('name');
    setState(() {
      specializations = List<String>.from(res.map((s) => s['name'].toString()));
    });
  }

  Future<void> fetchHealthCenters() async {
    final res = await supabase.from('HealthCenters').select('id, name');
    setState(() {
      healthCenters = res;
    });
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final username = usernameController.text.trim();
    final contact = contactController.text.trim();
    final description = descriptionController.text.trim();

    if (password != confirmPassword) {
      showError("Passwords do not match.");
      return;
    }

    if (email.isEmpty ||
        password.isEmpty ||
        username.isEmpty ||
        contact.isEmpty ||
        selectedHealthCenter == null) {
      showError("Please complete all required fields.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await authService.signUpWithEmailPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        showError("Registration failed.");
        return;
      }
      String? profileUrl;
      if (profileImage != null) {
        profileUrl = await uploadProfileImage(profileImage!);
      }

      await supabase.from('Users').insert({
        'userId': user.id,
        'username': username,
        'email': email,
        'contact': contact,
        'description': description,
        'specialization': selectedSpecs,
        'workingday': selectedDays,
        'workat': selectedHealthCenter,
        'role': 'doctor',
        'restricted': false,
        'profileImage': profileUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Doctor registered successfully. Please login as doctor.',
          ),
        ),
      );

      Navigator.pop(context);
    } on AuthException catch (e) {
      showError(e.message);
    } catch (e) {
      showError("Unexpected error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Doctor")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: pickProfileImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: profileImage != null
                          ? FileImage(File(profileImage!.path))
                          : null,
                      child: profileImage == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 32,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
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
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),

                  // Specializations
                  // Multi-select Specializations
                  TextFormField(
                    readOnly: true,
                    onTap: () => _showSpecializationDialog(context),
                    decoration: InputDecoration(
                      labelText: "Specializations",
                      hintText: selectedSpecs.isEmpty
                          ? "Select services"
                          : selectedSpecs.join(', '),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Working Days
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Working Days',
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: workingDays.map((day) {
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Work At
                  DropdownButtonFormField<String>(
                    value: selectedHealthCenter,
                    decoration: const InputDecoration(
                      labelText: 'Work At (Health Center)',
                    ),
                    items: healthCenters
                        .map<DropdownMenuItem<String>>(
                          (hc) => DropdownMenuItem(
                            value: hc['name'].toString(),
                            child: Text(hc['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedHealthCenter = value),
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("Register Doctor"),
                    onPressed: register,
                  ),
                ],
              ),
            ),
    );
  }
}
