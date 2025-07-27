class DashboardStats {
  final int totalSellers;
  final int totalBuyers;
  final double totalRevenue;
  final double commissionEarned;
  final double adminWallet;
  final List<dynamic> topItems;
  final List<dynamic> activeSellers;
  final int pendingSellers;

  DashboardStats({
    required this.totalSellers,
    required this.totalBuyers,
    required this.totalRevenue,
    required this.commissionEarned,
    required this.adminWallet,
    required this.topItems,
    required this.activeSellers,
    required this.pendingSellers,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSellers: json['total_sellers'] ?? 0,
      totalBuyers: json['total_buyers'] ?? 0,
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      commissionEarned: (json['commission_earned'] ?? 0).toDouble(),
      adminWallet: (json['admin_wallet'] ?? 0).toDouble(),
      topItems: json['top_items'] ?? [],
      activeSellers: json['active_sellers'] ?? [],
      pendingSellers: json['active_sellers'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_sellers': totalSellers,
      'total_buyers': totalBuyers,
      'total_revenue': totalRevenue,
      'commission_earned': commissionEarned,
      'admin_wallet': adminWallet,
      'top_items': topItems,
      'active_sellers': activeSellers,
    };
  }
}

class TopItem {
  final String name;
  final int quantitySold;
  final double revenue;

  TopItem({
    required this.name,
    required this.quantitySold,
    required this.revenue,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      name: json['name'] ?? 'Unnamed Item',
      quantitySold: json['quantity_sold'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
    );
  }
}

class ActiveSeller {
  final String id;
  final String fullName;
  final String userName;
  final String email;

  ActiveSeller({
    required this.id,
    required this.fullName,
    required this.userName,
    required this.email,
  });

  factory ActiveSeller.fromJson(Map<String, dynamic> json) {
    return ActiveSeller(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? 'Unknown',
      userName: json['user_name'] ?? 'Unknown',
      email: json['email'] ?? 'No email',
    );
  }
}