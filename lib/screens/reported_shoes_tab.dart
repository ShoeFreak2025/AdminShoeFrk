import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';

class ReportedShoesTab extends StatefulWidget {
  const ReportedShoesTab({Key? key}) : super(key: key);

  @override
  State<ReportedShoesTab> createState() => _ReportedShoesTabState();
}

class _ReportedShoesTabState extends State<ReportedShoesTab> {
  final supabase = Supabase.instance.client;
  List<dynamic> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);

    final response = await supabase
        .from('reported_shoes')
        .select('*, shoes(shoe_name, brand, seller_id, users(full_name))')
        .order('created_at', ascending: false);

    setState(() {
      _reports = response;
      _loading = false;
    });
  }

  Future<void> _markAsResolved(String reportId) async {
    await supabase
        .from('reported_shoes')
        .update({'is_resolved': true})
        .eq('id', reportId);
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return const Center(child: Text("No reported shoes"));
    }

    final double fontSize = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 12,
      tablet: 14,
      desktop: 16,
    );

    final double iconSize = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 20,
      tablet: 28,
      desktop: 32,
    );

    final EdgeInsets cardMargin = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: const EdgeInsets.all(8),
      tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );

    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final shoe = report['shoes'];

        return Card(
          margin: cardMargin,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ResponsiveUtil.isMobile(context)
                ? _buildMobileLayout(report, shoe, fontSize, iconSize)
                : _buildWideLayout(report, shoe, fontSize, iconSize),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(
      Map<String, dynamic> report,
      Map<String, dynamic>? shoe,
      double fontSize,
      double iconSize,
      ) {
    return ListTile(
      leading: Icon(Icons.warning, color: Colors.red, size: iconSize),
      title: Text(
        shoe?['shoe_name'] ?? 'Unknown',
        style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Brand: ${shoe?['brand']}", style: TextStyle(fontSize: fontSize)),
          Text("Seller: ${shoe?['users']?['full_name'] ?? shoe?['seller_id']}",
              style: TextStyle(fontSize: fontSize)),
          Text("Reason: ${report['reason']}", style: TextStyle(fontSize: fontSize)),
          Text("Reported on: ${report['created_at']}",
              style: TextStyle(fontSize: fontSize - 1, color: Colors.grey)),
          if (report['is_resolved'] == true)
            Text("Status: Resolved",
                style: TextStyle(color: Colors.green, fontSize: fontSize))
          else
            Text("Status: Pending",
                style: TextStyle(color: Colors.red, fontSize: fontSize)),
        ],
      ),
      trailing: report['is_resolved'] == true
          ? Icon(Icons.check, color: Colors.green, size: iconSize)
          : IconButton(
        icon: Icon(Icons.done, size: iconSize),
        tooltip: "Mark as Resolved",
        onPressed: () => _markAsResolved(report['id']),
      ),
    );
  }

  Widget _buildWideLayout(
      Map<String, dynamic> report,
      Map<String, dynamic>? shoe,
      double fontSize,
      double iconSize,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning, color: Colors.red, size: iconSize),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shoe?['shoe_name'] ?? 'Unknown',
                  style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold)),
              Text("Brand: ${shoe?['brand']}", style: TextStyle(fontSize: fontSize)),
              Text("Seller: ${shoe?['users']?['full_name'] ?? shoe?['seller_id']}",
                  style: TextStyle(fontSize: fontSize)),
              Text("Reason: ${report['reason']}", style: TextStyle(fontSize: fontSize)),
              Text("Reported on: ${report['created_at']}",
                  style: TextStyle(fontSize: fontSize - 1, color: Colors.grey)),
              if (report['is_resolved'] == true)
                Text("Status: Resolved",
                    style: TextStyle(color: Colors.green, fontSize: fontSize))
              else
                Text("Status: Pending",
                    style: TextStyle(color: Colors.red, fontSize: fontSize)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        report['is_resolved'] == true
            ? Icon(Icons.check, color: Colors.green, size: iconSize)
            : ElevatedButton.icon(
          icon: Icon(Icons.done, size: iconSize - 6),
          label: const Text("Resolve"),
          onPressed: () => _markAsResolved(report['id']),
        ),
      ],
    );
  }
}
