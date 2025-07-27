import 'package:flutter/material.dart';
import 'package:shoefrk_admin/models/dashboard_stats.dart';
import 'package:shoefrk_admin/screens/ReleasePayoutScreen.dart';
import 'package:shoefrk_admin/screens/product_screen.dart';
import 'package:shoefrk_admin/screens/seller_verification_screen.dart';
import 'package:shoefrk_admin/screens/users_screen.dart';
import 'package:shoefrk_admin/widgets/ActiveSellersWidget.dart';
import 'package:shoefrk_admin/widgets/sidebar_widget.dart';
import 'package:shoefrk_admin/widgets/stats_card.dart';
import 'package:shoefrk_admin/widgets/top_items_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  DashboardStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
      builder: (context) => AlertDialog(
        title: const Text('Create Announcement'),
        content: TextField(
          controller: _controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter your message here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                  const SnackBar(content: Text('Announcement sent!')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(String route) {
    Navigator.pop(context);

    if (route == 'users') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UsersScreen()),
      );
    } else if (route == 'products') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProductScreen()),
      );
    } else if (route == 'seller_verification') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SellerVerificationScreen()),
      );
    } else if (route == 'release_payouts') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReleasePayoutScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SidebarWidget(onNavigate: _handleNavigation),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _showAnnouncementDialog,
            icon: const Icon(Icons.announcement, color: Colors.white),
            label: const Text('Announce', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildError()
          : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDashboardData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_stats == null) return const SizedBox();

    return Container(
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.dashboard, size: 48, color: Colors.blue.shade600),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Admin Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor your marketplace performance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3,
              children: [
                StatsCard(
                  title: 'Total Sellers',
                  value: _stats!.totalSellers.toString(),
                  icon: Icons.store,
                  color: Colors.blue,
                ),
                StatsCard(
                  title: 'Total Buyers',
                  value: _stats!.totalBuyers.toString(),
                  icon: Icons.people,
                  color: Colors.green,
                ),
                StatsCard(
                  title: 'Admin Wallet',
                  value: '₱${_stats!.adminWallet.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet,
                  color: Colors.teal,
                ),
                StatsCard(
                  title: 'Revenue',
                  value: '₱${_stats!.totalRevenue.toStringAsFixed(2)}',
                  icon: Icons.wallet,
                  color: Colors.orange,
                ),
                StatsCard(
                  title: 'Commission',
                  value: '₱${_stats!.commissionEarned.toStringAsFixed(2)}',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
                StatsCard(
                  title: 'Pending Application',
                  value: _stats!.pendingSellers.toString(),
                  icon: Icons.timelapse,
                  color: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (MediaQuery.of(context).size.width > 800)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TopItemsWidget()),
                  const SizedBox(width: 24),
                  Expanded(child: ActiveSellersWidget(sellers: _stats!.activeSellers)),
                ],
              )
            else
              Column(
                children: [
                  TopItemsWidget(),
                  const SizedBox(height: 24),
                  ActiveSellersWidget(sellers: _stats!.activeSellers),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
