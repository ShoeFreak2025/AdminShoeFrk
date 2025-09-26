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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  DashboardStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  // Animation controllers for wow effects
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
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulse animation on repeat
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
        _isLoading = false;
      });

      // Start animations when data is loaded
      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();
    } catch (e) {
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
      builder: (context) => ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
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
                    }

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Announcement sent!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                child: const Text('Send', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
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
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
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
                colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
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
                (i) => Container(
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
              child: Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _loadDashboardData,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                      Expanded(child: _buildEnhancedWidget(TopItemsWidget())),
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
                    _buildEnhancedWidget(TopItemsWidget()),
                    const SizedBox(height: 24),
                    _buildEnhancedWidget(
                      ActiveSellersWidget(sellers: _stats!.activeSellers),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  child: const Icon(Icons.dashboard, size: 48, color: Colors.white),
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

  Widget _buildEnhancedStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: ResponsiveUtil.responsiveValue<int>(
        context: context,
        mobile: 2,
        tablet: 3,
        desktop: 4,
      ),
      crossAxisSpacing: ResponsiveUtil.responsiveValue<double>(
        context: context,
        mobile: 12,
        tablet: 16,
        desktop: 20,
      ),
      mainAxisSpacing: ResponsiveUtil.responsiveValue<double>(
        context: context,
        mobile: 12,
        tablet: 16,
        desktop: 20,
      ),
      childAspectRatio: ResponsiveUtil.responsiveValue<double>(
        context: context,
        mobile: 1.1, // Increased height for mobile
        tablet: 1.3,
        desktop: 1.4,
      ),
      children: [
        _buildEnhancedStatCard('Total Sellers', _stats!.totalSellers,
            Icons.store, Colors.blue, 0),
        _buildEnhancedStatCard('Total Buyers', _stats!.totalBuyers,
            Icons.people, Colors.green, 1),
        _buildEnhancedStatCard('Admin Wallet', _stats!.adminWallet,
            Icons.account_balance_wallet, Colors.teal, 2, isCurrency: true),
        _buildEnhancedStatCard('Revenue', _stats!.totalRevenue, Icons.trending_up,
            Colors.orange, 3, isCurrency: true),
        _buildEnhancedStatCard('Commission', _stats!.commissionEarned,
            Icons.attach_money, Colors.purple, 4, isCurrency: true),
        _buildEnhancedStatCard('Pending Applications', _stats!.pendingSellers,
            Icons.hourglass_empty, Colors.red, 5),
      ],
    );
  }

  Widget _buildEnhancedStatCard(String title, num value, IconData icon,
      Color color, int index, {bool isCurrency = false}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                ResponsiveUtil.responsiveValue<double>(
                  context: context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtil.responsiveValue<double>(
                    context: context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
                onTap: () {
                  // Add haptic feedback or navigation
                },
                child: Padding(
                  padding: ResponsiveUtil.responsiveValue<EdgeInsets>(
                    context: context,
                    mobile: const EdgeInsets.all(12),
                    tablet: const EdgeInsets.all(16),
                    desktop: const EdgeInsets.all(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: ResponsiveUtil.responsiveValue<EdgeInsets>(
                          context: context,
                          mobile: const EdgeInsets.all(8),
                          tablet: const EdgeInsets.all(10),
                          desktop: const EdgeInsets.all(12),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: ResponsiveUtil.responsiveValue<double>(
                            context: context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveUtil.responsiveValue<double>(
                          context: context,
                          mobile: 8,
                          tablet: 12,
                          desktop: 16,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: ResponsiveUtil.responsiveValue<double>(
                              context: context,
                              mobile: 11,
                              tablet: 13,
                              desktop: 14,
                            ),
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveUtil.responsiveValue<double>(
                          context: context,
                          mobile: 4,
                          tablet: 6,
                          desktop: 8,
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 1500 + (index * 200)),
                        tween: Tween(begin: 0, end: value.toDouble()),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          final display = isCurrency
                              ? '₱${val.toStringAsFixed(2)}'
                              : val.toInt().toString();
                          return Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                display,
                                style: TextStyle(
                                  fontSize: ResponsiveUtil.responsiveValue<double>(
                                    context: context,
                                    mobile: 16,
                                    tablet: 20,
                                    desktop: 22,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}