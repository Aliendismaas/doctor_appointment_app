import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isChanging = false;

  // Toggle visibility for each password field
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  final supabase = Supabase.instance.client;

  String passwordStrength = '';

  bool isStrongPassword(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(password);
  }

  void checkPasswordStrength(String password) {
    if (password.isEmpty) {
      passwordStrength = '';
    } else if (password.length < 8 || RegExp(r'^[a-z]+$').hasMatch(password)) {
      passwordStrength = 'Weak';
    } else if (password.length >= 8 &&
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$').hasMatch(password)) {
      passwordStrength = 'Strong';
    } else {
      passwordStrength = 'Medium';
    }
    setState(() {});
  }

  Future<void> _changePassword() async {
    final current = _currentController.text.trim();
    final newPassword = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (newPassword != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (!isStrongPassword(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 8 characters, include uppercase, lowercase, and number',
          ),
        ),
      );
      return;
    }

    setState(() => _isChanging = true);

    try {
      final currentUser = supabase.auth.currentUser;
      final userEmail = currentUser?.email ?? '';

      final response = await supabase.auth.signInWithPassword(
        email: userEmail,
        password: current,
      );

      if (response.user == null) throw 'Current password is incorrect';

      await supabase.auth.updateUser(
        AdminUserAttributes(password: newPassword),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );

      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() {
        passwordStrength = '';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isChanging = false);
    }
  }

  Color getStrengthColor() {
    switch (passwordStrength) {
      case 'Weak':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Strong':
        return Colors.green;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 47, 90, 171),
              Color.fromARGB(255, 99, 157, 224),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 12,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Change Password",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 46, 89, 125),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPasswordField(
                      controller: _currentController,
                      label: "Current Password",
                      icon: Icons.lock,
                      obscure: !_showCurrent,
                      toggleVisibility: () {
                        setState(() => _showCurrent = !_showCurrent);
                      },
                      isVisible: _showCurrent,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _newController,
                      label: "New Password",
                      icon: Icons.lock_outline,
                      obscure: !_showNew,
                      toggleVisibility: () {
                        setState(() => _showNew = !_showNew);
                      },
                      isVisible: _showNew,
                      onChanged: checkPasswordStrength,
                    ),
                    // Password strength indicator
                    if (passwordStrength.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: passwordStrength == 'Weak'
                                    ? 0.33
                                    : passwordStrength == 'Medium'
                                    ? 0.66
                                    : 1.0,
                                color: getStrengthColor(),
                                backgroundColor: Colors.grey[300],
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              passwordStrength,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: getStrengthColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmController,
                      label: "Confirm New Password",
                      icon: Icons.lock_outline,
                      obscure: !_showConfirm,
                      toggleVisibility: () {
                        setState(() => _showConfirm = !_showConfirm);
                      },
                      isVisible: _showConfirm,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isChanging ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: const Color.fromARGB(
                            255,
                            56,
                            100,
                            142,
                          ),
                          elevation: 8,
                        ),
                        child: _isChanging
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                "Change Password",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback toggleVisibility,
    required bool isVisible,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color.fromARGB(255, 56, 103, 142)),
        labelText: label,
        labelStyle: TextStyle(color: const Color.fromARGB(255, 56, 96, 142)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: const Color.fromARGB(255, 56, 96, 142),
          ),
          onPressed: toggleVisibility,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: const Color.fromARGB(255, 56, 93, 142),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
