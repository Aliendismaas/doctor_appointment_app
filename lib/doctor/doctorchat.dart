import 'package:doctor/doctor/doctorchatpage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorChatListPage extends StatefulWidget {
  const DoctorChatListPage({super.key});

  @override
  State<DoctorChatListPage> createState() => _DoctorChatListPageState();
}

class _DoctorChatListPageState extends State<DoctorChatListPage> {
  final supabase = Supabase.instance.client;
  final String? doctorId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> chats = [];
  bool isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    fetchChats();
    setupRealtimeListener();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchChats() async {
    if (doctorId == null) return;

    final res = await supabase
        .from('messages')
        .select()
        .or('sender.eq.$doctorId,receiver.eq.$doctorId')
        .order('created_at', ascending: false);

    final messages = List<Map<String, dynamic>>.from(res);

    final Map<String, Map<String, dynamic>> userChatMap = {};

    for (var msg in messages) {
      final isSender = msg['sender'] == doctorId;
      final userId = isSender ? msg['receiver'] : msg['sender'];

      if (userChatMap.containsKey(userId)) continue;

      final userRes = await supabase
          .from('Users')
          .select()
          .eq('userId', userId)
          .maybeSingle();

      if (userRes != null) {
        // Count unread messages from this user to doctor
        final unreadRes = await supabase
            .from('messages')
            .select('id')
            .eq('sender', userId)
            .eq('receiver', doctorId!)
            .eq('is_read', false);

        final unreadCount = unreadRes.length;

        userChatMap[userId] = {
          'user': userRes,
          'lastMessage': msg['message'],
          'timestamp': msg['created_at'],
          'unreadCount': unreadCount,
        };
      }
    }

    setState(() {
      chats = userChatMap.values.toList()
        ..sort(
          (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
        );
      isLoading = false;
    });
  }

  void setupRealtimeListener() {
    _channel = supabase.channel('realtime:messages');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newMessage = payload.newRecord;
        if (newMessage != null &&
            (newMessage['sender'] == doctorId ||
                newMessage['receiver'] == doctorId)) {
          fetchChats(); // Refresh the chat list
        }
      },
    );

    _channel!.subscribe();
  }

  Future<Map<String, dynamic>> fetchCurrentDoctorData() async {
    final doctorData = await supabase
        .from('Users')
        .select()
        .eq('userId', doctorId!)
        .single();
    return doctorData;
  }

  String formatTime(String isoTime) {
    final dateTime = DateTime.tryParse(isoTime);
    if (dateTime == null) return '';
    return DateFormat('h:mm a').format(dateTime); // e.g., 2:45 PM
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
          ? const Center(child: Text('No conversations yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chats.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final chat = chats[index];
                final user = chat['user'];
                final lastMsg = chat['lastMessage'] ?? '';
                final unreadCount = chat['unreadCount'] ?? 0;
                final time = formatTime(chat['timestamp'] ?? '');
                final profileImage = user['profileImage'];
                final username = user['username'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: profileImage != null
                        ? NetworkImage(profileImage)
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: profileImage == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(username ?? 'User'),
                  subtitle: Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(time, style: const TextStyle(fontSize: 12)),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),

                  onTap: () async {
                    final doctorData = await fetchCurrentDoctorData();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorChatPage(
                          doctorData: doctorData,
                          userData: user,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
