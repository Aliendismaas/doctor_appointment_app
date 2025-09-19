import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  String searchQuery = '';
  String selectedRole = 'all'; // options: 'all', 'user', 'doctor'

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final response = await supabase.from('Users').select().inFilter('role', [
      'user',
      'doctor',
    ]);

    setState(() {
      users = List<Map<String, dynamic>>.from(response);
      filteredUsers = users;
    });
  }

  void filterUsers(String query) {
    setState(() {
      searchQuery = query;
      filteredUsers = users.where((user) {
        final username = user['username']?.toLowerCase() ?? '';
        final role = user['role']?.toLowerCase() ?? '';

        final matchesSearch = username.contains(query.toLowerCase());
        final matchesRole = selectedRole == 'all' || role == selectedRole;

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> deleteUser(String authUserId) async {
    try {
      // Delete from custom Users table
      await supabase.from('Users').delete().eq('userId', authUserId);

      // Delete from Supabase Auth
      await supabase.auth.admin.deleteUser(authUserId);

      fetchUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
    }
  }

  Future<void> toggleRestriction(String authUserId, bool currentStatus) async {
    try {
      await supabase
          .from('Users')
          .update({'restricted': !currentStatus})
          .eq('userId', authUserId);
      fetchUsers();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User restriction updated')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating restriction: $e')));
    }
  }

  Future<void> changePassword(String authUserId) async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (newPassword != null && newPassword.isNotEmpty) {
      try {
        await supabase.auth.admin.updateUserById(
          authUserId,
          attributes: AdminUserAttributes(password: newPassword),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password changed')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> changeRole(String authUserId, String currentRole) async {
    try {
      final newRole = currentRole == 'user' ? 'doctor' : 'user';
      await supabase
          .from('Users')
          .update({'role': newRole})
          .eq('userId', authUserId);
      fetchUsers();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Role changed to $newRole')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error changing role: $e')));
    }
  }

  void showUserOptions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete User'),
              onTap: () {
                Navigator.pop(context);
                deleteUser(user['userId']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(
                user['restricted'] == true
                    ? 'Unrestrict User'
                    : 'Restrict User',
              ),
              onTap: () {
                Navigator.pop(context);
                toggleRestriction(user['userId'], user['restricted'] == true);
              },
            ),

            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                changePassword(user['userId']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change Role'),
              onTap: () {
                Navigator.pop(context);
                changeRole(user['userId'], user['role']);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: filterUsers,
                    decoration: InputDecoration(
                      hintText: 'Search by username',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRole = value;
                        filterUsers(searchQuery); // Re-filter based on new role
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total Users: ${filteredUsers.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (_, index) {
                final user = filteredUsers[index];
                final imageUrl = user['profileImage'] ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : const AssetImage('assets/avatar.png')
                              as ImageProvider,
                  ),
                  title: Row(
                    children: [
                      Text(user['username'] ?? 'No Name'),
                      const SizedBox(width: 8),
                      if (user['restricted'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Restricted',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  subtitle: Text(user['role'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showUserOptions(user),
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
