import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shoefrk_admin/utils/responsive_util.dart';
import 'package:shoefrk_admin/widgets/sidebar_widget.dart';

class ReleasePayoutScreen extends StatefulWidget {
  final Function(String)? onNavigate;

  const ReleasePayoutScreen({super.key, this.onNavigate});

  @override
  State<ReleasePayoutScreen> createState() => _ReleasePayoutScreenState();
}

class _ReleasePayoutScreenState extends State<ReleasePayoutScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  late AnimationController _headerController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _headerAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPendingTransactions();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
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

  Future<void> _loadPendingTransactions() async {
    setState(() => _loading = true);

    try {
      final response = await supabase
          .from('transactions')
          .select()
          .in_('status', [
        'PAID',
        'CANCEL REQUESTED',
        'CANCEL APPROVED',
        'CANCEL DECLINED',
      ])
          .order('created_at', ascending: false);

      if (response is List) {
        setState(() {
          _transactions =
              response.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _transactions = [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');
      setState(() {
        _transactions = [];
        _loading = false;
      });
    }
  }

  Future<void> _releaseToSeller(String transactionId) async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showMessage('❌ User not logged in');
      return;
    }

    _showLoadingDialog('Releasing payment...');

    try {
      final response = await http.post(
        Uri.parse('https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/release-to-seller'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'transaction_id': transactionId}),
      );

      final result = _parseJson(response.body);

      if (response.statusCode != 200) {
        Navigator.of(context).pop();
        _showErrorDialog(result['error'] ?? 'Operation failed');
        return;
      }

      final logResponse = await http.post(
        Uri.parse('https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/log_action'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'action': 'release_payout',
          'target_id': transactionId,
          'target_type': 'transaction',
          'details': {'result': result},
        }),
      );

      if (logResponse.statusCode != 200) {
        Navigator.of(context).pop();
        _showErrorDialog('Release failed: Could not log action');
        debugPrint('❌ log_action failed: ${logResponse.body}');
        return;
      }

      Navigator.of(context).pop();
      _showSuccessDialog('Seller paid successfully', Icons.payments);
      _loadPendingTransactions();
    } catch (e) {
      Navigator.of(context).pop();
      debugPrint('❌ Error releasing payout: $e');
      _showErrorDialog('Failed to release payout');
    }
  }

  Future<void> _refundToBuyer(String transactionId) async {
    try {
      final txn = await supabase
          .from('transactions')
          .select('typeofSeller')
          .eq('id', transactionId)
          .maybeSingle();

      if (txn == null || txn['typeofSeller'] == null) {
        _showMessage('❌ Transaction not found');
        return;
      }

      final String typeofSeller = txn['typeofSeller'] as String;
      final endpoint = (typeofSeller.toLowerCase() == 'seller') ? 'Refund' : 'Refund-Artist';

      final session = supabase.auth.currentSession;
      if (session == null) {
        _showMessage('❌ Not authenticated');
        return;
      }

      _showLoadingDialog('Processing refund...');

      final response = await http.post(
        Uri.parse('https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'transaction_id': transactionId}),
      );

      final result = _parseJson(response.body);

      if (response.statusCode != 200) {
        Navigator.of(context).pop();
        _showErrorDialog(result['error'] ?? 'Refund failed');
        return;
      }

      final logResponse = await http.post(
        Uri.parse('https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/log_action'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'action': 'refund_buyer',
          'target_id': transactionId,
          'target_type': 'transaction',
          'details': {
            'typeofSeller': typeofSeller,
            'result': result,
          },
        }),
      );

      if (logResponse.statusCode != 200) {
        Navigator.of(context).pop();
        _showErrorDialog('Refund failed: Could not log action');
        debugPrint('❌ log_action failed: ${logResponse.body}');
        return;
      }

      Navigator.of(context).pop();
      _showSuccessDialog('Buyer refunded successfully', Icons.refresh);
      _loadPendingTransactions();
    } catch (e) {
      Navigator.of(context).pop();
      debugPrint('❌ Error refunding buyer: $e');
      _showErrorDialog('Refund process failed');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String message, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Success!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return ScaleTransition(
      scale: _headerAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade600,
              Colors.blue.shade400,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade200,
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: TweenAnimationBuilder(
                duration: const Duration(seconds: 4),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.rotate(
                    angle: value * 6.28,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: TweenAnimationBuilder(
                duration: const Duration(seconds: 6),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.rotate(
                    angle: -value * 6.28,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtil.responsiveValue(
                  context: context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
                vertical: 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!ResponsiveUtil.isDesktop(context))
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.payments,
                          color: Colors.white,
                          size: ResponsiveUtil.responsiveValue(
                            context: context,
                            mobile: 28,
                            tablet: 32,
                            desktop: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Release Payouts',
                              style: TextStyle(
                                fontSize: ResponsiveUtil.responsiveValue(
                                  context: context,
                                  mobile: 24,
                                  tablet: 28,
                                  desktop: 32,
                                ),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage pending transactions',
                              style: TextStyle(
                                fontSize: ResponsiveUtil.responsiveValue(
                                  context: context,
                                  mobile: 14,
                                  tablet: 16,
                                  desktop: 18,
                                ),
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveUtil.responsiveValue(
                      context: context,
                      mobile: 16,
                      tablet: 20,
                      desktop: 24,
                    ),
                  ),
                  if (ResponsiveUtil.isTablet(context) || ResponsiveUtil.isDesktop(context))
                    Row(
                      children: [
                        _buildStatCard(
                          'Total Pending',
                          '${_transactions.length}',
                          Icons.pending_actions,
                          Colors.orange,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          'PAID Status',
                          '${_transactions.where((t) => t['status'] == 'PAID').length}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_transactions.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          Column(
                            children: [
                              Text(
                                '${_transactions.where((t) => t['status'] == 'PAID').length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'PAID',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: ['ALL', 'PAID', 'CANCEL REQUESTED', 'CANCEL APPROVED', 'CANCEL DECLINED']
                    .map((status) => _buildFilterChip(status))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) => setState(() => _statusFilter = status),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.purple.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    var filtered = _transactions;

    if (_statusFilter != 'ALL') {
      filtered = filtered.where((t) => t['status'] == _statusFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final query = _searchQuery.toLowerCase();
        return t['id'].toString().toLowerCase().contains(query) ||
            t['seller_id'].toString().toLowerCase().contains(query) ||
            t['user_id'].toString().toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget _buildTransactionsList() {
    final filteredTransactions = _filteredTransactions;

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading transactions...'),
          ],
        ),
      );
    }

    if (filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'ALL'
                  ? 'No transactions match your filters'
                  : 'No pending payouts',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final txn = filteredTransactions[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _EnhancedTransactionCard(
                  txn: txn,
                  onRelease: () => _releaseToSeller(txn['id']),
                  onRefund: () => _refundToBuyer(txn['id']),
                  isHorizontal: ResponsiveUtil.isDesktop(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildAnimatedHeader(),
        _buildSearchAndFilters(),
        Expanded(child: _buildTransactionsList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onNavigate != null) {
      return _buildMainContent();
    }
    return Scaffold(
      drawer: ResponsiveUtil.isMobile(context)
          ? SidebarWidget(
        onNavigate: _handleNavigation,
        currentRoute: 'release_payouts',
      )
          : null,
      body: Row(
        children: [
          if (ResponsiveUtil.isDesktop(context))
            SidebarWidget(
              onNavigate: _handleNavigation,
              currentRoute: 'release_payouts',
            ),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }
}

class _EnhancedTransactionCard extends StatefulWidget {
  final Map<String, dynamic> txn;
  final VoidCallback onRelease;
  final VoidCallback onRefund;
  final bool isHorizontal;

  const _EnhancedTransactionCard({
    required this.txn,
    required this.onRelease,
    required this.onRefund,
    this.isHorizontal = false,
  });

  @override
  State<_EnhancedTransactionCard> createState() => _EnhancedTransactionCardState();
}

class _EnhancedTransactionCardState extends State<_EnhancedTransactionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'CANCEL REQUESTED':
        return Colors.orange;
      case 'CANCEL APPROVED':
        return Colors.blue;
      case 'CANCEL DECLINED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PAID':
        return Icons.check_circle;
      case 'CANCEL REQUESTED':
        return Icons.help_outline;
      case 'CANCEL APPROVED':
        return Icons.thumb_up;
      case 'CANCEL DECLINED':
        return Icons.thumb_down;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.txn['status'] ?? '');
    final statusIcon = _getStatusIcon(widget.txn['status'] ?? '');

    return ScaleTransition(
      scale: _scaleAnimation,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _hoverController.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _hoverController.reverse();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? Colors.purple.shade100 : Colors.grey.shade200,
                spreadRadius: _isHovered ? 4 : 2,
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
            border: Border.all(
              color: _isHovered ? Colors.purple.shade200 : Colors.transparent,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.6)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: widget.isHorizontal
                      ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTransactionDetails(statusColor, statusIcon)),
                      const SizedBox(width: 20),
                      _buildActionButtons(),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTransactionDetails(statusColor, statusIcon),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionDetails(Color statusColor, IconData statusIcon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ID: ${widget.txn['id']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.txn['status'] ?? 'UNKNOWN',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.pink.shade50],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.attach_money, color: Colors.purple.shade600, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '₱${widget.txn['amount']}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Seller ID',
                widget.txn['seller_id']?.toString() ?? 'N/A',
                Icons.store,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                'Buyer ID',
                widget.txn['user_id']?.toString() ?? 'N/A',
                Icons.person,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.txn['created_at'] != null) ...[
          Text(
            'Created: ${_formatDate(widget.txn['created_at'])}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: (color is MaterialColor) ? color.shade700 : color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.isHorizontal ? 200 : double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onRelease,
            icon: const Icon(Icons.payments, size: 18),
            label: const Text('Release to Seller'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: widget.isHorizontal ? 200 : double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onRefund,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refund to Buyer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}