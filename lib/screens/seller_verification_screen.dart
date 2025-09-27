import 'package:flutter/material.dart';
import 'package:shoefrk_admin/utils/admin_logger.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';
import 'package:shoefrk_admin/widgets/sidebar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerVerificationScreen extends StatefulWidget {
  final Function(String)? onNavigate;

  const SellerVerificationScreen({super.key, this.onNavigate});

  @override
  State<SellerVerificationScreen> createState() => _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<dynamic> _applications = [];
  bool _loading = true;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fetchApplications();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleNavigation(String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      String routeName;
      switch (route) {
        case 'dashboard':
          routeName = '/dashboard';
          break;
        case 'users':
          routeName = '/users';
          break;
        case 'seller_verification':
          routeName = '/seller-verification';
          break;
        case 'products':
          routeName = '/products';
          break;
        case 'release_payouts':
          routeName = '/release-payouts';
          break;
        default:
          routeName = '/dashboard';
      }
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  Future<void> _fetchApplications() async {
    setState(() => _loading = true);

    try {
      final data = await supabase
          .from('seller_applications')
          .select('*, users(full_name, email)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      setState(() {
        _applications = data;
        _loading = false;
      });

      _fadeController.forward();
      _scaleController.forward();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading applications: $e')),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not authenticated')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing application...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
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

      await AdminLogger.logAction(
        action: (status == 'approved') ? 'approve_application' : 'reject_application',
        targetId: appId,
        targetType: 'seller_application',
        details: {
          'admin_id': session.user!.id,
          'appType': appType,
          'status': status,
          if (reason != null) 'reason': reason,
          'assigned_role': (status == 'approved') ? roleToAssign : null,
        },
      );

      Navigator.pop(context);

      _showSuccessAnimation(status == 'approved' ? 'approved' : 'rejected');

      await _fetchApplications();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating application: $e')),
      );
    }
  }

  void _showSuccessAnimation(String action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: action == 'approved' ? Colors.green.shade100 : Colors.red.shade100,
                      ),
                      child: Icon(
                        action == 'approved' ? Icons.check : Icons.close,
                        color: action == 'approved' ? Colors.green : Colors.red,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Application ${action.toUpperCase()}!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Widget _buildApplicationCard(Map<String, dynamic> app, int index) {
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

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _fadeController,
              curve: Interval(
                index * 0.1,
                1.0,
                curve: Curves.easeOutCubic,
              ),
            )),
            child: Container(
              margin: EdgeInsets.all(cardMargin),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.blue.withOpacity(0.3),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.blue.shade50.withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.blue.shade100,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Text(
                                  (user?['full_name'] ?? '?')[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?['full_name'] ?? 'No Name',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      user?['email'] ?? 'No email',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (app['type'] ?? 'seller').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        _buildDetailRow(
                          Icons.badge,
                          'Valid ID Type',
                          app['valid_id_type'] ?? 'N/A',
                          textStyle,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.calendar_today,
                          'Submitted',
                          app['created_at'] ?? 'Unknown',
                          textStyle,
                        ),

                        const SizedBox(height: 16),

                        if (validIds.isNotEmpty) ...[
                          Text(
                            'Valid ID Images:',
                            style: textStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: validIds.map<Widget>((url) {
                              return Hero(
                                tag: url,
                                child: GestureDetector(
                                  onTap: () => _showImageDialog(url),
                                  child: Container(
                                    width: imageSize,
                                    height: imageSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 40,
                                              ),
                                            ),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: Colors.grey.shade100,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        ResponsiveUtil.isMobile(context)
                            ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildActionButton(
                              'Reject',
                              Icons.close,
                              Colors.red,
                                  () => _showRejectDialog(app),
                              false,
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              'Approve',
                              Icons.check,
                              Colors.green,
                                  () async {
                                await _updateApplicationStatus(
                                  app['id'],
                                  app['user_id'],
                                  'approved',
                                  appType: app['type'],
                                );
                              },
                              true,
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionButton(
                              'Reject',
                              Icons.close,
                              Colors.red,
                                  () => _showRejectDialog(app),
                              false,
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              'Approve',
                              Icons.check,
                              Colors.green,
                                  () async {
                                await _updateApplicationStatus(
                                  app['id'],
                                  app['user_id'],
                                  'approved',
                                  appType: app['type'],
                                );
                              },
                              true,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, TextStyle textStyle) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.blue.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: textStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      bool isPrimary,
      ) {
    return Material(
      elevation: isPrimary ? 4 : 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isPrimary ? color : Colors.transparent,
            border: isPrimary ? null : Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Hero(
          tag: imageUrl,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading applications...'),
          ],
        ),
      );
    }

    if (_applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No pending applications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _applications.length,
      itemBuilder: (context, index) => _buildApplicationCard(_applications[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onNavigate != null) {
      return _buildBody();
    }
    return Scaffold(
      appBar: ResponsiveUtil.isMobile(context)
          ? AppBar(
        title: const Text('Seller Verification'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      )
          : null,
      drawer: ResponsiveUtil.isMobile(context)
          ? SidebarWidget(
        onNavigate: _handleNavigation,
        currentRoute: 'seller_verification',
      )
          : null,
      body: Row(
        children: [
          if (ResponsiveUtil.isDesktop(context))
            SidebarWidget(
              onNavigate: _handleNavigation,
              currentRoute: 'seller_verification',
            ),
          Expanded(
            child: Column(
              children: [
                if (ResponsiveUtil.isDesktop(context))
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200,
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Seller Verification',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(dynamic app) {
    showDialog(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Reject Application'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to reject this application?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
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