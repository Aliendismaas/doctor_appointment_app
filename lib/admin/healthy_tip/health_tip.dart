import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class PostHealthTipPage extends StatefulWidget {
  const PostHealthTipPage({super.key});

  @override
  State<PostHealthTipPage> createState() => _PostHealthTipPageState();
}

class _PostHealthTipPageState extends State<PostHealthTipPage> {
  final TextEditingController captionController = TextEditingController();
  final supabase = Supabase.instance.client;
  XFile? pickedFile;
  String? fileType; // "image" or "video"
  bool isLoading = false;

  final picker = ImagePicker();

  Future<void> pickImage() async {
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        pickedFile = result;
        fileType = "image";
      });
    }
  }

  Future<void> pickVideo() async {
    final result = await picker.pickVideo(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        pickedFile = result;
        fileType = "video";
      });
    }
  }

  Future<String?> uploadFile(XFile file) async {
    final fileExt = file.path.split('.').last;
    final fileName = "health_tips/${const Uuid().v4()}.$fileExt";
    final fileBytes = await file.readAsBytes();

    final mimeType =
        lookupMimeType(file.path) ??
        (fileType == "video" ? "video/mp4" : "image/jpeg");

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

  Future<void> saveTip() async {
    final caption = captionController.text.trim();
    if (caption.isEmpty && pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a caption or media")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String? mediaUrl;
      if (pickedFile != null) {
        mediaUrl = await uploadFile(pickedFile!);
      }

      await supabase.from('health_tips').insert({
        'caption': caption,
        'media_url': mediaUrl,
        'media_type': fileType,
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tip posted successfully!")));

      setState(() {
        pickedFile = null;
        fileType = null;
        captionController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error posting Tip: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void cancelSelection() {
    setState(() {
      pickedFile = null;
      fileType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post Tip")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Media preview
            GestureDetector(
              onTap: fileType == null ? pickImage : null,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                  image: (pickedFile != null && fileType == "image")
                      ? DecorationImage(
                          image: FileImage(File(pickedFile!.path)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: pickedFile == null
                    ? const Center(child: Text("Tap to pick image"))
                    : fileType == "video"
                    ? const Center(
                        child: Icon(
                          Icons.videocam,
                          size: 60,
                          color: Colors.blue,
                        ),
                      )
                    : null,
              ),
            ),
            if (pickedFile != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: cancelSelection,
                ),
              ),

            const SizedBox(height: 20),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                labelText: "Say something",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text("Add Image"),
                ),
                ElevatedButton.icon(
                  onPressed: pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text("Add Video"),
                ),
              ],
            ),

            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Post"),
                    onPressed: saveTip,
                  ),
          ],
        ),
      ),
    );
  }
}
