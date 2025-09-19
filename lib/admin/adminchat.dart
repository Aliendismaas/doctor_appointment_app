import 'package:doctor/admin/admindrawer.dart';
import 'package:doctor/doctor/doctorchatpage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Adminchat extends StatefulWidget {
  const Adminchat({super.key});

  @override
  State<Adminchat> createState() => _AdminchatState();
}

class _AdminchatState extends State<Adminchat> {
  final supabase = Supabase.instance.client;
  final String? doctorId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> filteredChats = [];
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
          // simulate online status for demo purposes
          'online': userRes['is_online'] ?? false,
        };
      }
    }

    setState(() {
      chats = userChatMap.values.toList()
        ..sort(
          (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
        );
      filteredChats = chats;
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
          fetchChats();
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
    return DateFormat('h:mm a').format(dateTime);
  }

  void filterChats(String query) {
    final lower = query.toLowerCase();
    setState(() {
      filteredChats = chats
          .where(
            (chat) =>
                (chat['user']['username'] ?? '').toLowerCase().contains(lower),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Dashboard"),
        backgroundColor: Colors.blue.shade700,
      ),
      drawer: const Admindrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: TextField(
                    onChanged: filterChats,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredChats.isEmpty
                      ? const Center(
                          child: Text(
                            'No conversations found.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = filteredChats[index];
                            final user = chat['user'];
                            final lastMsg = chat['lastMessage'] ?? '';
                            final unreadCount = chat['unreadCount'] ?? 0;
                            final time = formatTime(chat['timestamp'] ?? '');
                            final profileImage = user['profileImage'];
                            final username = user['username'];
                            final online = chat['online'] ?? false;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: profileImage != null
                                          ? NetworkImage(profileImage)
                                          : null,
                                      backgroundColor: Colors.grey[300],
                                      child: profileImage == null
                                          ? const Icon(Icons.person, size: 28)
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: online
                                              ? Colors.green
                                              : Colors.grey,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  username ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  lastMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                  final doctorData =
                                      await fetchCurrentDoctorData();
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
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
