import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final Map<String, dynamic> userData;

  const ChatPage({super.key, required this.doctorData, required this.userData});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  RealtimeChannel? _channel;
  XFile? pickedImage;

  @override
  void initState() {
    super.initState();
    fetchMessages();
    setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> updateUnreadMessages() async {
    final currentUserId = widget.userData['userId'];
    final otherUserId = widget.doctorData['userId'];

    final response = await supabase
        .from('messages')
        .update({'is_read': true}) // ✅ Correct: mark as read
        .eq('receiver', currentUserId)
        .eq('sender', otherUserId)
        .eq('is_read', false); // ✅ Only update unread messages

    if (response.error != null) {
      print('Failed to update read status: ${response.error!.message}');
    } else {
      print('Unread messages marked as read.');
    }
  }

  Future<void> fetchMessages() async {
    final fromId = widget.userData['userId'];
    final toId = widget.doctorData['userId'];

    final res = await supabase
        .from('messages')
        .select()
        .or(
          'and(sender.eq.$fromId,receiver.eq.$toId),and(sender.eq.$toId,receiver.eq.$fromId)',
        )
        .order('created_at', ascending: true);

    setState(() {
      messages = List<Map<String, dynamic>>.from(res);
    });
    await updateUnreadMessages();
  }

  void setupRealtime() {
    final channel = supabase.channel('realtime:messages');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newMsg = payload.newRecord;
        final fromId = widget.userData['userId'];
        final toId = widget.doctorData['userId'];

        if ((newMsg['sender'] == fromId && newMsg['receiver'] == toId) ||
            (newMsg['sender'] == toId && newMsg['receiver'] == fromId)) {
          setState(() {
            messages.add(Map<String, dynamic>.from(newMsg));
          });
          if (newMsg['receiver'] == fromId) {
            updateUnreadMessages();
          }
        }
      },
    );

    channel.subscribe();
    _channel = channel;
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => pickedImage = result);
    }
  }

  Future<String?> uploadImage(XFile image) async {
    final fileExt = image.path.split('.').last;
    final fileName = "chat/${const Uuid().v4()}.$fileExt";
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

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    String? imageUrl;

    // Only upload if image was picked
    if (pickedImage != null) {
      try {
        imageUrl = await uploadImage(pickedImage!);
      } catch (e) {
        print("Image upload failed: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image upload failed')));
        return;
      }
    }

    // Prevent sending if both text and image are missing
    if (text.isEmpty && imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a message or attach an image')),
      );
      return;
    }

    // Build message map based on what’s available
    final messageData = {
      'sender': widget.userData['userId'],
      'receiver': widget.doctorData['userId'],
      'created_at': DateTime.now().toIso8601String(),
      if (text.isNotEmpty) 'message': text,
      if (imageUrl != null) 'image': imageUrl,
    };

    try {
      await supabase.from('messages').insert(messageData);
      _messageController.clear();
      setState(() {
        pickedImage = null;
      });
    } catch (e) {
      print("Failed to send message: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  bool isMe(Map<String, dynamic> msg) {
    return msg['sender'] == widget.userData['userId'];
  }

  Widget buildMessage(Map<String, dynamic> msg) {
    final mine = isMe(msg);
    final profileImage = mine
        ? widget.userData['profileImage']
        : widget.doctorData['profileImage'];

    final messageContent = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (msg['image'] != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Image.network(
              msg['image'],
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error),
            ),
          ),
        if (msg['message'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: mine ? Colors.blue : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              msg['message'],
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
          ),
      ],
    );

    final profile = CircleAvatar(
      radius: 18,
      backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
      backgroundColor: Colors.grey[300],
      child: profileImage == null ? const Icon(Icons.person, size: 18) : null,
    );

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: mine
          ? [Flexible(child: messageContent), const SizedBox(width: 6), profile]
          : [
              profile,
              const SizedBox(width: 6),
              Flexible(child: messageContent),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatWith = widget.doctorData['username'] ?? 'Chat';

    return Scaffold(
      appBar: AppBar(title: Text(chatWith)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                return buildMessage(messages[index]);
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (pickedImage != null)
                  Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Image.file(
                          File(pickedImage!.path), // Use dart:io File
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              pickedImage = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: pickImage,
                      color: Colors.blue,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: sendMessage,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
