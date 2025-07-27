import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final shoe = report['shoes'];

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: Text(shoe['shoe_name'] ?? 'Unknown'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Brand: ${shoe['brand']}"),
                Text("Seller: ${shoe['shoe_name']}"),
                Text("Reason: ${report['reason']}"),
                Text("Reported on: ${report['created_at']}"),
                if (report['is_resolved'] == true)
                  const Text("Status: Resolved", style: TextStyle(color: Colors.green))
                else
                  const Text("Status: Pending", style: TextStyle(color: Colors.red)),
              ],
            ),
            trailing: report['is_resolved'] == true
                ? const Icon(Icons.check, color: Colors.green)
                : IconButton(
              icon: const Icon(Icons.done),
              tooltip: "Mark as Resolved",
              onPressed: () => _markAsResolved(report['id']),
            ),
          ),
        );
      },
    );
  }
}
