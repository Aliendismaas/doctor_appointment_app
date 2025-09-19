import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;
  final usernameController = TextEditingController();
  final contactController = TextEditingController();

  String? profileImageUrl;
  String? coverImageUrl;
  XFile? pickedImage;
  XFile? tempProfileImage;
  XFile? tempCoverImage;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    final res = await supabase
        .from('Users')
        .select()
        .eq('userId', userId!)
        .maybeSingle();

    if (res != null) {
      usernameController.text = res['username'] ?? '';
      contactController.text = res['contact'] ?? '';
      profileImageUrl = res['profileImage'];
      coverImageUrl = res['coverImage'];
    }

    setState(() => isLoading = false);
  }

  Future<String?> uploadcover(XFile image) async {
    final fileExt = image.path.split('.').last;
    final fileName = "coverImage/${const Uuid().v4()}.$fileExt";
    final fileBytes = await image.readAsBytes();

    final mimeType = lookupMimeType(image.path) ?? 'image/jpeg'; // fallback

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

  Future<String?> uploadprofile(XFile image) async {
    final fileExt = image.path.split('.').last;
    final fileName = "profileImage/${const Uuid().v4()}.$fileExt";
    final fileBytes = await image.readAsBytes();

    final mimeType = lookupMimeType(image.path) ?? 'image/jpeg'; // fallback

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

  Future<void> updateProfile() async {
    setState(() => isSaving = true);
    final userId = supabase.auth.currentUser?.id;

    try {
      // Upload new profile image if selected
      if (tempProfileImage != null) {
        final url = await uploadprofile(tempProfileImage!);
        if (url == null) {
          throw Exception("Failed to upload profile image");
        }
        profileImageUrl = url;
      }

      // Upload new cover image if selected
      if (tempCoverImage != null) {
        final url = await uploadcover(tempCoverImage!);
        if (url == null) {
          throw Exception("Failed to upload cover image");
        }
        coverImageUrl = url;
      }

      // ✅ Ensure final URLs are NOT null
      final updates = {
        'username': usernameController.text.trim(),
        'contact': contactController.text.trim(),
        'profileImage': profileImageUrl ?? "",
        'coverImage': coverImageUrl ?? "",
      };

      await supabase.from('Users').update(updates).eq('userId', userId!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        if (isProfile) {
          tempProfileImage = result;
        } else {
          tempCoverImage = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                // Cover Image
                GestureDetector(
                  onTap: () => pickImage(false),
                  child: Stack(
                    children: [
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          image: tempCoverImage != null
                              ? DecorationImage(
                                  image: FileImage(File(tempCoverImage!.path)),
                                  fit: BoxFit.cover,
                                )
                              : coverImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(coverImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (tempCoverImage == null && coverImageUrl == null)
                            ? const Center(
                                child: Text("Tap to select Cover Image"),
                              )
                            : null,
                      ),
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.1),
                          child: const Center(
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Profile Image
                Center(
                  child: GestureDetector(
                    onTap: () => pickImage(true),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: tempProfileImage != null
                              ? FileImage(File(tempProfileImage!.path))
                              : profileImageUrl != null
                              ? NetworkImage(profileImageUrl!) as ImageProvider
                              : null,
                          child:
                              (tempProfileImage == null &&
                                  profileImageUrl == null)
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const Positioned(
                          bottom: 4,
                          right: 4,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Username
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                const SizedBox(height: 12),

                // Contact
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: "Contact"),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Save Changes"),
                  onPressed: isSaving ? null : updateProfile,
                ),
              ],
            ),
          ),

          if (isSaving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
