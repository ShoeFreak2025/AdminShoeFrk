import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive_util.dart';

class SidebarWidget extends StatelessWidget {
  final Function(String) onNavigate;
  final String? currentRoute;

  const SidebarWidget({
    Key? key,
    required this.onNavigate,
    this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtil.isDesktop(context)) {
      return Container(
        width: 250,
        color: Colors.white,
        child: _buildMenu(context),
      );
    } else {
      return Drawer(
        backgroundColor: Colors.white,
        child: _buildMenu(context),
      );
    }
  }

  Widget _buildMenu(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue.shade700),
          child: const Center(
            child: Text(
              'Admin Panel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        _buildNavItem(Icons.dashboard, 'Dashboard', 'dashboard'),
        _buildNavItem(Icons.people_alt, 'Manage Users', 'users'),
        _buildNavItem(Icons.verified_user, 'Seller Verification', 'seller_verification'),
        _buildNavItem(Icons.inventory, 'Products', 'products'),
        _buildNavItem(Icons.payments, 'Release Payouts', 'release_payouts'),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.redAccent),
          ),
          onTap: () async {
            Navigator.of(context).pop();
            await Supabase.instance.client.auth.signOut();
          },
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String title, String route) {
    final bool isActive = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? Colors.blue.shade700 : Colors.black87,
        ),
      ),
      tileColor: isActive ? Colors.blue.shade50 : null,
      selected: isActive,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () => onNavigate(route),
    );
  }
}
