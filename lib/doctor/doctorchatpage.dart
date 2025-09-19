import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class DoctorChatPage extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final Map<String, dynamic> userData;

  const DoctorChatPage({
    super.key,
    required this.doctorData,
    required this.userData,
  });

  @override
  State<DoctorChatPage> createState() => _DoctorChatPageState();
}

class _DoctorChatPageState extends State<DoctorChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  RealtimeChannel? _channel;
  XFile? pickedImage;

  bool userOnline = false;
  String lastSeen = '';

  @override
  void initState() {
    super.initState();
    fetchMessages();
    setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> updateUnreadMessages() async {
    final otherUserId = widget.userData['userId'];
    final currentUserId = widget.doctorData['userId'];

    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('receiver', currentUserId)
        .eq('sender', otherUserId)
        .eq('is_read', false);
  }

  Future<void> fetchMessages() async {
    final doctorId = widget.doctorData['userId'];
    final userId = widget.userData['userId'];

    final res = await supabase
        .from('messages')
        .select()
        .or(
          'and(sender.eq.$doctorId,receiver.eq.$userId),and(sender.eq.$userId,receiver.eq.$doctorId)',
        )
        .order('created_at', ascending: true);

    setState(() {
      messages = List<Map<String, dynamic>>.from(res);
    });
    await updateUnreadMessages();
  }

  void setupRealtime() {
    // Channel for chat messages
    final chatChannel = supabase.channel('realtime:messages');
    chatChannel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newMsg = payload.newRecord;
        if (newMsg != null) {
          final fromId = widget.doctorData['userId'];
          final toId = widget.userData['userId'];

          if ((newMsg['sender'] == fromId && newMsg['receiver'] == toId) ||
              (newMsg['sender'] == toId && newMsg['receiver'] == fromId)) {
            setState(() {
              messages.add(Map<String, dynamic>.from(newMsg));
            });
            if (newMsg['receiver'] == fromId) updateUnreadMessages();
          }
        }
      },
    );
    chatChannel.subscribe();
    _channel = chatChannel;

    // Channel for user online/offline updates
    final userChannel = supabase.channel('realtime:users');

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'userId',
      value: widget.userData['userId'],
    );

    userChannel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'Users',
      filter: filter,
      callback: (payload) {
        final newData = payload.newRecord ?? {};
        setState(() {
          userOnline = newData['is_online'] ?? false;
          if (!userOnline) {
            final ts = newData['last_seen'];
            lastSeen = ts != null
                ? DateFormat.jm().format(DateTime.parse(ts))
                : '';
          }
        });
      },
    );

    userChannel.subscribe();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) setState(() => pickedImage = result);
  }

  Future<String?> uploadImage(XFile image) async {
    final fileExt = image.path.split('.').last;
    final fileName = "chat/${const Uuid().v4()}.$fileExt";
    final fileBytes = await image.readAsBytes();
    final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';

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

    if (pickedImage != null) {
      imageUrl = await uploadImage(pickedImage!);
    }

    if (text.isEmpty && imageUrl == null) return;

    final messageData = {
      'sender': widget.doctorData['userId'],
      'receiver': widget.userData['userId'],
      'created_at': DateTime.now().toIso8601String(),
      if (text.isNotEmpty) 'message': text,
      if (imageUrl != null) 'image': imageUrl,
    };

    await supabase.from('messages').insert(messageData);
    _messageController.clear();
    setState(() => pickedImage = null);
  }

  bool isMe(Map<String, dynamic> msg) =>
      msg['sender'] == widget.doctorData['userId'];

  Widget buildMessage(Map<String, dynamic> msg) {
    final mine = isMe(msg);
    final profileImage = mine
        ? widget.doctorData['profileImage']
        : widget.userData['profileImage'];

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
            ),
          ),
        if (msg['message'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: mine ? Colors.green : Colors.grey[200],
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
    final chatWith = widget.userData['username'] ?? 'Patient';
    final statusText = userOnline
        ? 'Online'
        : (lastSeen.isNotEmpty ? 'Last seen $lastSeen' : 'Offline');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat with $chatWith', style: const TextStyle(fontSize: 16)),
            Text(statusText, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) => buildMessage(messages[index]),
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
                          File(pickedImage!.path),
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
                          onPressed: () => setState(() => pickedImage = null),
                        ),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      color: Colors.green,
                      onPressed: pickImage,
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
                      color: Colors.green,
                      onPressed: sendMessage,
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
