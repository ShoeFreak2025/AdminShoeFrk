import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class ReleasePayoutScreen extends StatefulWidget {
  const ReleasePayoutScreen({super.key});

  @override
  State<ReleasePayoutScreen> createState() => _ReleasePayoutScreenState();
}

class _ReleasePayoutScreenState extends State<ReleasePayoutScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingTransactions();
  }

  Future<void> _loadPendingTransactions() async {
    setState(() => _loading = true);

    try {
      final response = await supabase
          .from('transactions')
          .select('*')
          .in_('status', ['PAID', 'CANCEL REQUESTED', 'CANCEL APPROVED', 'CANCEL DECLINED'])
          .order('created_at', ascending: false);

      if (response is List) {
        print('✅ Loaded transactions: ${response.length}');
        setState(() {
          _transactions = response;
          _loading = false;
        });
      } else {
        print('❌ Supabase error: $response');
        setState(() {
          _transactions = [];
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Exception: $e');
      setState(() {
        _transactions = [];
        _loading = false;
      });
    }
  }

  Future<void> _releaseToSeller(String transactionId) async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ User not logged in')),
      );
      return;
    }

    final url = Uri.parse(
      'https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/release-to-seller',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({'transaction_id': transactionId}),
    );

    final Map<String, dynamic> result = jsonDecode(response.body);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '✅ Seller paid successfully')),
      );

      await supabase.functions.invoke(
        'log_action',
        body: {
          'admin_id': session.user.id,
          'action': 'release_payout',
          'target_id': transactionId,
          'target_type': 'transaction',
          'details': {'result': result},
        },
      );

      _loadPendingTransactions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${result['error'] ?? 'Operation failed'}')),
      );
    }
  }

  Future<void> _refundToBuyer(String transactionId) async {
    print("🔄 Initiating refund process for transaction: $transactionId");

    final txn = await supabase
        .from('transactions')
        .select('typeofSeller')
        .eq('id', transactionId)
        .maybeSingle();

    if (txn == null) {
      print("❌ Transaction not found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Transaction not found')),
      );
      return;
    }

    print("✅ Transaction data fetched: $txn");

    if (txn['typeofSeller'] == null) {
      print("❌ typeofSeller missing in transaction");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ typeofSeller not found')),
      );
      return;
    }

    final String typeofSeller = txn['typeofSeller'] as String;
    print("🔍 typeofSeller = $typeofSeller");

    final String endpoint =
    (typeofSeller.toLowerCase() == 'seller') ? 'Refund' : 'Refund-Artist';

    final session = supabase.auth.currentSession;
    if (session == null || session.user == null) {
      print("❌ No authenticated admin session found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not authenticated')),
      );
      return;
    }

    final adminId = session.user!.id;
    final accessToken = session.accessToken;

    final url = Uri.parse(
        'https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/$endpoint');

    print("🚀 Sending refund request to $url");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'transaction_id': transactionId}),
    );

    final Map<String, dynamic> result = jsonDecode(response.body);
    print("📡 Edge Function response [${response.statusCode}]: $result");

    if (response.statusCode == 200) {
      print("✅ Refund processed successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? '✅ Buyer refunded successfully')),
      );

      await supabase.functions.invoke(
        'log_action',
        body: {
          'admin_id': adminId,
          'action': 'refund_buyer',
          'target_id': transactionId,
          'target_type': 'transaction',
          'details': {
            'typeofSeller': typeofSeller,
            'result': result,
          },
        },
      );

      _loadPendingTransactions();
    } else {
      print("❌ Refund failed: ${result['error'] ?? 'Unknown error'}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${result['error'] ?? 'Refund failed'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Payouts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(child: Text('No pending payouts'))
          : ListView.builder(
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final txn = _transactions[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transaction ID: ${txn['id']}'),
                        Text('Amount: ₱${txn['amount']}'),
                        Text('Seller ID: ${txn['seller_id']}'),
                        Text('Buyer ID: ${txn['user_id']}'),
                        Text('Status: ${txn['status']}'),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => _releaseToSeller(txn['id']),
                        child: const Text('Release'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _refundToBuyer(txn['id']),
                        child: const Text('Refund'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
