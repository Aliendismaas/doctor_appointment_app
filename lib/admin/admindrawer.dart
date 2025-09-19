import 'package:doctor/admin/Userman.dart';
import 'package:doctor/admin/adminsetting.dart';
import 'package:doctor/admin/game/sales.dart';
import 'package:doctor/admin/game/sport/products.dart';
import 'package:doctor/admin/healthmanag.dart';
import 'package:doctor/admin/healthy_tip/tipview.dart';
import 'package:doctor/admin/report.dart';
import 'package:doctor/admin/servicemanag.dart';
import 'package:doctor/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Admindrawer extends StatelessWidget {
  const Admindrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3C47A5), Color(0xFFEAECEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4354A0), Color(0xFF6C7BD9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFF8FA5FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.hearing_outlined,
                        color: Color.fromARGB(255, 76, 91, 175),
                        size: 35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Docter App',
                    style: TextStyle(
                      fontSize: 24,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 6,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildMagicalDrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Adminsetting()),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.room_service,
              title: 'Category',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageServicesPage()),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.inventory_2,
              title: 'Products',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProductListPage()),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.center_focus_strong,
              title: 'Healty center',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageHealthCentersPage(),
                ),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.video_collection_outlined,
              title: 'Healty Tip',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthTipsPage()),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.attach_money,
              title: 'Sales',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Sales()),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.bar_chart,
              title: 'Report',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportPage()),
              ),
            ),
            _buildMagicalDrawerItem(
              icon: Icons.people,
              title: 'User Manage',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementPage()),
              ),
            ),
            const Divider(thickness: 1, height: 1, color: Colors.white70),
            _buildMagicalDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              iconColor: Colors.redAccent,
              textColor: Colors.redAccent,
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMagicalDrawerItem({
    required IconData icon,
    required String title,
    Color iconColor = Colors.white,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8FA5FF), Color(0xFF3C47A5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Icon(icon, color: iconColor, size: 28),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
