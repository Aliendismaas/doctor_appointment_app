import 'package:doctor/admin/adminhome.dart';
import 'package:doctor/doctor/doctorhome.dart';
import 'package:doctor/main.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor/user/home.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient supabase;

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;

    // Listen for Supabase auth events (works on Web + Mobile)
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        // User clicked password reset link (web flow)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
        );
      }

      // You can also handle signedIn, signedOut, etc.
      if (event == AuthChangeEvent.signedIn && session != null) {
        // User just signed in
      }
    });
  }

  Future<Widget> _getRedirectPage() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const LoginPage();

    final userId = user.id;
    final userData = await Supabase.instance.client
        .from('Users') // Ensure this matches your table name exactly
        .select('role')
        .eq('userId', userId)
        .maybeSingle();

    if (userData == null || userData['role'] == null) {
      return const LoginPage(); // fallback if role missing
    }

    final role = userData['role'];
    if (role == 'admin') {
      return const Adminhome();
    } else if (role == 'doctor') {
      return const Doctorhome();
    } else if (role == 'user') {
      return const HomePage();
    } else {
      return const LoginPage(); // fallback for unknown roles
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getRedirectPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Something went wrong')),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
