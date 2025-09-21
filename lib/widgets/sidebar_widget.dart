import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive_util.dart';

class SidebarWidget extends StatelessWidget {
  final Function(String) onNavigate;

  const SidebarWidget({Key? key, required this.onNavigate}) : super(key: key);

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
          child: const Text(
            'Admin Panel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Dashboard'),
          onTap: () => onNavigate('dashboard'),
        ),
        ListTile(
          leading: const Icon(Icons.people_alt),
          title: const Text('Manage Users'),
          onTap: () => onNavigate('users'),
        ),
        ListTile(
          leading: const Icon(Icons.verified_user),
          title: const Text('Seller Verification'),
          onTap: () => onNavigate('seller_verification'),
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('Products'),
          onTap: () => onNavigate('products'),
        ),
        ListTile(
          leading: const Icon(Icons.payments),
          title: const Text('Release Payouts'),
          onTap: () => onNavigate('release_payouts'),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            Navigator.of(context).pop();
            await Supabase.instance.client.auth.signOut();
          },
        ),
      ],
    );
  }
}
