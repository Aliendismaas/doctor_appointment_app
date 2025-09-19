import 'package:doctor/user/chat.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final supabase = Supabase.instance.client;
  String? currentUserId;
  Map<String, dynamic>? currentUserData;
  List<Map<String, dynamic>> recentChats = [];
  bool isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    fetchCurrentUser();
    setupRealtimeListener(); // Setup real-time updates
    fetchChats();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchCurrentUser() async {
    currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      setState(() => isLoading = false);
      return;
    }

    final res = await supabase
        .from('Users')
        .select()
        .eq('userId', currentUserId!)
        .maybeSingle();

    setState(() {
      currentUserData = res;
    });

    fetchChats();
    setupRealtimeListener(); // Setup real-time updates
  }

  Future<void> fetchChats() async {
    if (currentUserId == null) return;

    final res = await supabase
        .from('messages')
        .select()
        .or('sender.eq.$currentUserId,receiver.eq.$currentUserId')
        .order('created_at', ascending: false);

    final messages = List<Map<String, dynamic>>.from(res);

    final Map<String, Map<String, dynamic>> userChatMap = {};

    for (var msg in messages) {
      final isSender = msg['sender'] == currentUserId;
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
            .eq('receiver', currentUserId!)
            .eq('is_read', false);

        final unreadCount = unreadRes.length;

        userChatMap[userId] = {
          'userData': currentUserData?['role'] == 'user'
              ? currentUserData
              : userRes,
          'doctorData': currentUserData?['role'] == 'doctor'
              ? currentUserData
              : userRes,
          'message': msg['message'],
          'timestamp': msg['created_at'],
          'unreadCount': unreadCount,
        };
      }
    }

    setState(() {
      recentChats = userChatMap.values.toList()
        ..sort(
          (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
        );
      isLoading = false;
    });
  }

  /// Sets up a real-time listener for new messages.
  void setupRealtimeListener() {
    _channel = supabase.channel('realtime:messages');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final newMessage = payload.newRecord;
        if (newMessage != null &&
            (newMessage['sender'] == currentUserId ||
                newMessage['receiver'] == currentUserId)) {
          fetchChats(); // Refresh the chat list
        }
      },
    );

    _channel!.subscribe();
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
          : recentChats.isEmpty
          ? const Center(child: Text('No chats yet.'))
          : ListView.builder(
              itemCount: recentChats.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final chat = recentChats[index];
                final unreadCount = chat['unreadCount'] ?? 0;
                final time = formatTime(chat['timestamp'] ?? '');
                final user = chat['doctorData']['role'] == 'doctor'
                    ? chat['doctorData']
                    : chat['userData'];

                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          doctorData: chat['doctorData'],
                          userData: chat['userData'],
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundImage: user['profileImage'] != null
                        ? NetworkImage(user['profileImage'])
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: user['profileImage'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user['username'] ?? 'Unknown'),
                  subtitle: Text(
                    chat['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(time, style: const TextStyle(fontSize: 12)),
                      if (unreadCount > 0 &&
                          chat['doctorData']['userId'] != currentUserId)
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
                );
              },
            ),
    );
  }
}
