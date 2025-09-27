import 'package:flutter/material.dart';
import 'package:shoefrk_admin/models/dashboard_stats.dart';
import 'package:shoefrk_admin/screens/ReleasePayoutScreen.dart';
import 'package:shoefrk_admin/screens/product_screen.dart';
import 'package:shoefrk_admin/screens/seller_verification_screen.dart';
import 'package:shoefrk_admin/screens/users_screen.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';
import 'package:shoefrk_admin/widgets/ActiveSellersWidget.dart';
import 'package:shoefrk_admin/widgets/sidebar_widget.dart';
import 'package:shoefrk_admin/widgets/top_items_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

class AdminLog {
  final int id;
  final String adminId;
  final String action;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  AdminLog({
    required this.id,
    required this.adminId,
    required this.action,
    this.targetId,
    this.targetType,
    this.details,
    required this.createdAt,
  });

  factory AdminLog.fromJson(Map<String, dynamic> json) {
    return AdminLog(
      id: json['id'],
      adminId: json['admin_id'],
      action: json['action'],
      targetId: json['target_id'],
      targetType: json['target_type'],
      details: json['details'] != null ? Map<String, dynamic>.from(json['details']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class AdminLogsDialog extends StatefulWidget {
  const AdminLogsDialog({Key? key}) : super(key: key);

  @override
  _AdminLogsDialogState createState() => _AdminLogsDialogState();
}

class _AdminLogsDialogState extends State<AdminLogsDialog> {
  final supabase = Supabase.instance.client;
  List<AdminLog> _logs = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  final List<String> _filters = [
    'ALL',
    'ANNOUNCEMENT_SENT',
    'USER_APPROVED',
    'USER_REJECTED',
    'PAYOUT_RELEASED',
    'PRODUCT_APPROVED'
  ];

  @override
  void initState() {
    super.initState();
    _loadAllLogs();
  }

  Future<void> _loadAllLogs() async {
    setState(() => _isLoading = true);

    try {
      var query = supabase
          .from('admin_logs')
          .select('*');

      if (_selectedFilter != 'ALL') {
        query = query.eq('action', _selectedFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _logs = response.map((log) => AdminLog.fromJson(log)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.indigo.shade600, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Admin Activity Logs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedFilter,
                isExpanded: true,
                underline: const SizedBox(),
                items: _filters.map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(
                      filter == 'ALL' ? 'All Activities' : _formatActionText(filter),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedFilter = value!);
                  _loadAllLogs();
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No logs found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return _buildDetailedLogItem(log);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedLogItem(AdminLog log) {
    IconData icon;
    Color color;

    switch (log.action.toUpperCase()) {
      case 'ANNOUNCEMENT_SENT':
        icon = Icons.announcement;
        color = Colors.blue;
        break;
      case 'USER_APPROVED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'USER_REJECTED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'PAYOUT_RELEASED':
        icon = Icons.payments;
        color = Colors.purple;
        break;
      case 'PRODUCT_APPROVED':
        icon = Icons.inventory;
        color = Colors.teal;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatActionText(log.action),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Admin ID: ${log.adminId}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatFullTimestamp(log.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (log.targetId != null || log.details != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.targetId != null) ...[
                      Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Target: ${log.targetType ?? 'Unknown'} (${log.targetId})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (log.details != null) ...[
                      if (log.targetId != null) const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getDetailedLogDescription(log),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatActionText(String action) {
    return action.replaceAll('_', ' ').toLowerCase().split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getDetailedLogDescription(AdminLog log) {
    if (log.details == null) return 'No additional details';

    switch (log.action.toUpperCase()) {
      case 'ANNOUNCEMENT_SENT':
        return 'Message: "${log.details!['content'] ?? 'No content'}"';
      case 'USER_APPROVED':
      case 'USER_REJECTED':
        return 'User verification status changed';
      case 'PAYOUT_RELEASED':
        final amount = log.details!['amount'] ?? 0;
        return 'Payout amount: ₱${amount.toString()}';
      case 'PRODUCT_APPROVED':
        return 'Product approved for listing';
      default:
        return log.details!.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
    }
  }

  String _formatFullTimestamp(DateTime timestamp) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final month = months[timestamp.month - 1];
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');

    return '$month $day, ${hour}:${minute}';
  }
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  DashboardStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminLog> _recentLogs = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDashboardData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = supabase.auth.currentUser;
      double adminWallet = 0;

      if (currentUser != null) {
        final walletResponse = await supabase
            .from('users')
            .select('wallet')
            .eq('id', currentUser.id)
            .single();

        adminWallet = (walletResponse['wallet'] ?? 0).toDouble();
      }

      final sellersResponse = await supabase
          .from('users')
          .select('id')
          .or('is_seller.eq.true,role.cs.{"seller"}');

      final buyersResponse = await supabase
          .from('users')
          .select('id')
          .or('is_buyer.eq.true,role.cs.{"buyer"}');

      final revenueResponse = await supabase
          .from('transactions')
          .select('amount')
          .in_('status', ['paid', 'processed'])
          .or('is_refunded.is.false,is_refunded.is.null');

      double totalRevenue = 0;
      double commissionEarned = 0;

      for (var transaction in revenueResponse) {
        final amount = (transaction['amount'] as num).toDouble();
        totalRevenue += amount;
        commissionEarned += amount * 0.1;
      }

      final allTransactions = await supabase
          .from('transactions')
          .select('item_id')
          .eq('status', 'paid');

      final Map<String, int> itemCounts = {};
      for (var tx in allTransactions) {
        final itemId = tx['item_id'];
        if (itemId != null) {
          itemCounts[itemId] = (itemCounts[itemId] ?? 0) + 1;
        }
      }

      final topItemIds = itemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final top3Ids = topItemIds.take(3).map((e) => e.key).toList();

      final topItemsResponse = top3Ids.isEmpty
          ? []
          : await supabase
          .from('shoes')
          .select('id, shoe_name, brand, price, seller_name')
          .in_('id', top3Ids);

      final activeSellersResponse = await supabase
          .from('users')
          .select('id, full_name, user_name, email')
          .or('is_seller.eq.true,role.cs.{"seller"}')
          .eq('status', 'APPROVED')
          .limit(10);

      final pendingSellersResponse = await supabase
          .from('users')
          .select('id')
          .or('is_seller.eq.true,role.cs.{"seller"}')
          .eq('status', 'PENDING');

      final logsResponse = await supabase
          .from('admin_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(5);

      final recentLogs = logsResponse.map((log) => AdminLog.fromJson(log))
          .toList();

      setState(() {
        _stats = DashboardStats(
          totalSellers: sellersResponse.length,
          totalBuyers: buyersResponse.length,
          totalRevenue: totalRevenue,
          commissionEarned: commissionEarned,
          adminWallet: adminWallet,
          topItems: topItemsResponse,
          activeSellers: activeSellersResponse,
          pendingSellers: pendingSellersResponse.length,
        );
        _recentLogs = recentLogs;
        _isLoading = false;
      });

      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();

      print('Dashboard data loaded successfully');
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _errorMessage = 'Failed to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAnnouncementDialog() async {
    final TextEditingController _controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) =>
          ScaleTransition(
            scale: _scaleAnimation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.announcement, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Text('Create Announcement'),
                ],
              ),
              content: TextField(
                controller: _controller,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Enter your message here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.blue.shade600, width: 2),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: () async {
                      final content = _controller.text.trim();
                      if (content.isNotEmpty) {
                        final currentUser = supabase.auth.currentUser;

                        if (currentUser != null) {
                          await supabase.from('notifications').insert({
                            'user_id': currentUser.id,
                            'title': 'announcement',
                            'content': content,
                            'is_read': false,
                          });

                          await _logAdminAction(
                              'ANNOUNCEMENT_SENT', null, 'notification', {
                            'content': content,
                            'timestamp': DateTime.now().toIso8601String(),
                          });
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Announcement sent!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        _loadDashboardData();
                      }
                    },
                    child: const Text(
                        'Send', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _logAdminAction(String action, String? targetId,
      String? targetType, Map<String, dynamic>? details) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null) {
      await supabase.from('admin_logs').insert({
        'admin_id': currentUser.id,
        'action': action,
        'target_id': targetId,
        'target_type': targetType,
        'details': details,
      });
    }
  }

  Future<void> _showAllLogsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const AdminLogsDialog(),
    );
  }

  void _handleNavigation(String route) {
    Navigator.pop(context);

    final page = {
      'users': const UsersScreen(),
      'products': const ProductScreen(),
      'seller_verification': const SellerVerificationScreen(),
      'release_payouts': const ReleasePayoutScreen(),
    }[route];

    if (page != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  Widget _buildEnhancedStatsGrid() {
    if (_stats == null) return const SizedBox();

    final stats = [
      {
        'title': 'Total Sellers',
        'value': _stats!.totalSellers.toString(),
        'icon': Icons.store,
        'color': Colors.blue,
        'gradient': [Colors.blue.shade600, Colors.blue.shade400],
      },
      {
        'title': 'Total Buyers',
        'value': _stats!.totalBuyers.toString(),
        'icon': Icons.people,
        'color': Colors.green,
        'gradient': [Colors.green.shade600, Colors.green.shade400],
      },
      {
        'title': 'Total Revenue',
        'value': '₱${_stats!.totalRevenue.toStringAsFixed(2)}',
        'icon': Icons.monetization_on,
        'color': Colors.orange,
        'gradient': [Colors.orange.shade600, Colors.orange.shade400],
      },
      {
        'title': 'Commission Earned',
        'value': '₱${_stats!.commissionEarned.toStringAsFixed(2)}',
        'icon': Icons.account_balance_wallet,
        'color': Colors.purple,
        'gradient': [Colors.purple.shade600, Colors.purple.shade400],
      },
      {
        'title': 'Admin Wallet',
        'value': '₱${_stats!.adminWallet.toStringAsFixed(2)}',
        'icon': Icons.savings,
        'color': Colors.teal,
        'gradient': [Colors.teal.shade600, Colors.teal.shade400],
      },
      {
        'title': 'Pending Sellers',
        'value': _stats!.pendingSellers.toString(),
        'icon': Icons.pending_actions,
        'color': Colors.red,
        'gradient': [Colors.red.shade600, Colors.red.shade400],
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtil.responsiveValue<int>(
          context: context,
          mobile: 2,
          tablet: 3,
          desktop: 3,
        ),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: ResponsiveUtil.responsiveValue<double>(
          context: context,
          mobile: 1.2,
          tablet: 1.3,
          desktop: 1.4,
        ),
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: index == 0 ? _pulseAnimation.value : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: stat['gradient'] as List<Color>,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (stat['color'] as Color).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              stat['icon'] as IconData,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          if (stat['title'] == 'Total Revenue')
                            Icon(
                              Icons.trending_up,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        stat['value'] as String,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat['title'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ResponsiveUtil.isDesktop(context)
          ? null
          : SidebarWidget(
        onNavigate: _handleNavigation,
        currentRoute: 'dashboard',
      ),
      appBar: ResponsiveUtil.isDesktop(context)
          ? null
          : AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadDashboardData,
                  tooltip: 'Refresh Data',
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton.icon(
              onPressed: _showAnnouncementDialog,
              icon: const Icon(Icons.announcement, color: Colors.white),
              label: const Text('Announce',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          if (ResponsiveUtil.isDesktop(context))
            SidebarWidget(
              onNavigate: _handleNavigation,
              currentRoute: 'dashboard',
            ),
          Expanded(
            child: _isLoading
                ? _buildEnhancedShimmerLoader()
                : _errorMessage != null
                ? _buildError()
                : _buildDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedShimmerLoader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.white,
        period: const Duration(milliseconds: 1500),
        child: GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: ResponsiveUtil.responsiveValue<int>(
            context: context,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          ),
          children: List.generate(
            6,
                (i) =>
                Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Icon(
                  Icons.error_outline, size: 64, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                onPressed: _loadDashboardData,
                child: const Text(
                    'Retry', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    if (_stats == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          ResponsiveUtil.responsiveValue<double>(
            context: context,
            mobile: 12,
            tablet: 20,
            desktop: 24,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                position: _slideAnimation,
                child: _buildEnhancedWelcomeCard(),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _slideAnimation,
                child: _buildEnhancedStatsGrid(),
              ),
              const SizedBox(height: 32),
              ScaleTransition(
                scale: _scaleAnimation,
                child: ResponsiveUtil.isDesktop(context)
                    ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildEnhancedWidget(const TopItemsWidget())),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildEnhancedWidget(
                          ActiveSellersWidget(sellers: _stats!.activeSellers),
                        ),
                      ),
                    ],
                  ),
                )
                    : Column(
                  children: [
                    _buildEnhancedWidget(const TopItemsWidget()),
                    const SizedBox(height: 24),
                    _buildEnhancedWidget(
                      ActiveSellersWidget(sellers: _stats!.activeSellers),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ScaleTransition(
                scale: _scaleAnimation,
                child: _buildEnhancedWidget(_buildAdminLogsWidget()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminLogsWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.withOpacity(0.1),
                      Colors.indigo.withOpacity(0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.indigo.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Admin Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAllLogsDialog,
                icon: Icon(
                    Icons.visibility, size: 16, color: Colors.indigo.shade600),
                label: Text(
                  'See All',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activities',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _recentLogs.take(5)
                  .map((log) => _buildLogItem(log))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLogItem(AdminLog log) {
    IconData icon;
    Color color;

    switch (log.action.toUpperCase()) {
      case 'ANNOUNCEMENT_SENT':
        icon = Icons.announcement;
        color = Colors.blue;
        break;
      case 'USER_APPROVED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'USER_REJECTED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'PAYOUT_RELEASED':
        icon = Icons.payments;
        color = Colors.purple;
        break;
      case 'PRODUCT_APPROVED':
        icon = Icons.inventory;
        color = Colors.teal;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatActionText(log.action),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                if (log.details != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getLogDescription(log),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatTimestamp(log.createdAt),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatActionText(String action) {
    return action.replaceAll('_', ' ').toLowerCase().split(' ')
        .map((word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getLogDescription(AdminLog log) {
    if (log.details == null) return '';

    switch (log.action.toUpperCase()) {
      case 'ANNOUNCEMENT_SENT':
        return log.details!['content'] ?? '';
      case 'USER_APPROVED':
      case 'USER_REJECTED':
        return 'User ID: ${log.targetId ?? 'Unknown'}';
      case 'PAYOUT_RELEASED':
        final amount = log.details!['amount'] ?? 0;
        return 'Amount: ₱${amount.toString()}';
      default:
        return log.details!.toString();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Widget _buildEnhancedWidget(Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildEnhancedWelcomeCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade400,
            Colors.cyan.shade300,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                      Icons.dashboard, size: 48, color: Colors.white),
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Admin Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor your marketplace performance with real-time insights',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}