import 'dart:io';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AddServicePage extends StatefulWidget {
  const AddServicePage({super.key});

  @override
  State<AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends State<AddServicePage> {
  final TextEditingController nameController = TextEditingController();
  final supabase = Supabase.instance.client;
  XFile? pickedImage;
  bool isLoading = false;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => pickedImage = result);
    }
  }

Future<String?> uploadImage(XFile image) async {
  final fileExt = image.path.split('.').last;
  final fileName = "services/${const Uuid().v4()}.$fileExt";
  final fileBytes = await image.readAsBytes();

  final mimeType = lookupMimeType(image.path) ?? 'image/jpeg'; // fallback

  final res = await supabase.storage.from('avatars').uploadBinary(
    fileName,
    fileBytes,
    fileOptions: FileOptions(
      upsert: true,
      contentType: mimeType,
    ),
  );

  if (res.isNotEmpty) {
    return supabase.storage.from('avatars').getPublicUrl(fileName);
  }
  return null;
}


  Future<void> saveService() async {
    final name = nameController.text.trim();
    if (name.isEmpty || pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide both name and image")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final imageUrl = await uploadImage(pickedImage!);
      await supabase.from('Services').insert({
        'name': name,
        'image_url': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service registered successfully!")),
      );

      setState(() {
        pickedImage = null;
        nameController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving service: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Service")),
      body: Padding(
        padding: const EdgeInsets.all(20),
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
                          image: FileImage(
                            File(pickedImage!.path),
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: pickedImage == null
                    ? const Center(child: Text("Tap to pick service image"))
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Service Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save Service"),
                    onPressed: saveService,
                  ),
          ],
        ),
      ),
    );
  }
}
