import 'package:flutter/material.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerVerificationScreen extends StatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  State<SellerVerificationScreen> createState() => _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _applications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('seller_applications')
        .select('*, users(full_name, email)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    setState(() {
      _applications = data;
      _loading = false;
    });
  }

  Future<void> _updateApplicationStatus(
      String appId,
      String userId,
      String status, {
        String? reason,
        String? appType,
      }) async {
    final session = supabase.auth.currentSession;

    if (session == null || session.user == null) {
      print("❌ No authenticated admin session found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not authenticated')),
      );
      return;
    }

    await supabase.from('seller_applications').update({
      'status': status,
      if (reason != null) 'reason': reason,
    }).eq('id', appId);

    String roleToAssign = (appType == 'artist') ? 'artist' : 'seller';

    if (status == 'approved') {
      await supabase.rpc('add_user_role', params: {
        'user_id_input': userId,
        'role_to_add': roleToAssign,
      });
    }

    String title = appType == 'artist' ? 'Artist Verification' : 'Seller Verification';
    String content = (status == 'approved')
        ? 'Your $roleToAssign application has been approved! You can now upload and sell your $roleToAssign works.'
        : 'Your $roleToAssign application has been rejected.'
        '${reason != null ? ' Reason: $reason' : ''}';

    await supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'content': content,
      'is_read': false,
    });

    final adminId = session.user!.id;
    await supabase.functions.invoke(
      'log-admin-action',
      body: {
        'admin_id': adminId,
        'action': (status == 'approved') ? 'approve_application' : 'reject_application',
        'target_id': appId,
        'target_type': 'seller_application',
        'details': {
          'appType': appType,
          'status': status,
          if (reason != null) 'reason': reason,
          'assigned_role': (status == 'approved') ? roleToAssign : null,
        },
      },
    );

    _fetchApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Applications'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
          ? const Center(child: Text('No pending applications.'))
          : ListView.builder(
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final app = _applications[index];
          final user = app['users'];
          final List<dynamic> validIds = app['valid_ids'] ?? [];

          final cardPadding = ResponsiveUtil.responsiveValue(
            context: context,
            mobile: 12.0,
            tablet: 16.0,
            desktop: 24.0,
          );

          final cardMargin = ResponsiveUtil.responsiveValue(
            context: context,
            mobile: 8.0,
            tablet: 12.0,
            desktop: 16.0,
          );

          final imageSize = ResponsiveUtil.responsiveValue(
            context: context,
            mobile: 80.0,
            tablet: 100.0,
            desktop: 120.0,
          );

          final textStyle = TextStyle(
            fontSize: ResponsiveUtil.responsiveValue(
              context: context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
          );

          return Card(
            margin: EdgeInsets.all(cardMargin),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?['full_name'] ?? 'No Name',
                      style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user?['email'] ?? 'No email', style: textStyle),
                  const SizedBox(height: 8),
                  Text('Valid ID Type: ${app['valid_id_type'] ?? 'N/A'}',
                      style: textStyle),
                  const SizedBox(height: 6),
                  Text('Submitted on: ${app['created_at']}', style: textStyle),
                  const SizedBox(height: 6),

                  if (validIds.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: validIds.map<Widget>((url) {
                        return Container(
                          width: imageSize,
                          height: imageSize,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2));
                            },
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 12),

                  ResponsiveUtil.isMobile(context)
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        child: const Text('Reject',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () => _showRejectDialog(app),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _updateApplicationStatus(
                            app['id'],
                            app['user_id'],
                            'approved',
                            appType: app['type'],
                          );
                        },
                        child: const Text('Approve'),
                      ),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Reject',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () => _showRejectDialog(app),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _updateApplicationStatus(
                            app['id'],
                            app['user_id'],
                            'approved',
                            appType: app['type'],
                          );
                        },
                        child: const Text('Approve'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRejectDialog(dynamic app) {
    showDialog(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Application'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateApplicationStatus(
                  app['id'],
                  app['user_id'],
                  'rejected',
                  reason: controller.text.trim().isEmpty
                      ? null
                      : controller.text.trim(),
                  appType: app['type'],
                );
                Navigator.pop(context);
              },
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );
  }
}
