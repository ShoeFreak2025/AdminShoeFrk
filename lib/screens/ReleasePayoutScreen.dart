import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shoefrk_admin/utils/responsive_util.dart';

class ReleasePayoutScreen extends StatefulWidget {
  const ReleasePayoutScreen({super.key});

  @override
  State<ReleasePayoutScreen> createState() => _ReleasePayoutScreenState();
}

class _ReleasePayoutScreenState extends State<ReleasePayoutScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
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

    final url = Uri.parse(
        'https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/release-to-seller');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'transaction_id': transactionId}),
      );

      final result = _parseJson(response.body);

      if (response.statusCode == 200) {
        _showMessage(result['message'] ?? '✅ Seller paid successfully');

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
        _showMessage('❌ ${result['error'] ?? 'Operation failed'}');
      }
    } catch (e) {
      debugPrint('❌ Error releasing payout: $e');
      _showMessage('❌ Failed to release payout');
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
      final endpoint =
      (typeofSeller.toLowerCase() == 'seller') ? 'Refund' : 'Refund-Artist';

      final session = supabase.auth.currentSession;
      if (session == null) {
        _showMessage('❌ Not authenticated');
        return;
      }

      final url = Uri.parse(
          'https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/$endpoint');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'transaction_id': transactionId}),
      );

      final result = _parseJson(response.body);

      if (response.statusCode == 200) {
        _showMessage(result['message'] ?? '✅ Buyer refunded successfully');

        await supabase.functions.invoke(
          'log_action',
          body: {
            'admin_id': session.user.id,
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
        _showMessage('❌ ${result['error'] ?? 'Refund failed'}');
      }
    } catch (e) {
      debugPrint('❌ Error refunding buyer: $e');
      _showMessage('❌ Refund process failed');
    }
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveUtil.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Payouts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(child: Text('No pending payouts'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final txn = _transactions[index];
          return _TransactionCard(
            txn: txn,
            onRelease: () => _releaseToSeller(txn['id']),
            onRefund: () => _refundToBuyer(txn['id']),
            isHorizontal: isDesktop,
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> txn;
  final VoidCallback onRelease;
  final VoidCallback onRefund;
  final bool isHorizontal;

  const _TransactionCard({
    required this.txn,
    required this.onRelease,
    required this.onRefund,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transaction ID: ${txn['id']}'),
        Text('Amount: ₱${txn['amount']}'),
        Text('Seller ID: ${txn['seller_id']}'),
        Text('Buyer ID: ${txn['user_id']}'),
        Text('Status: ${txn['status']}'),
      ],
    );

    final actions = Column(
      children: [
        ElevatedButton(onPressed: onRelease, child: const Text('Release')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRefund, child: const Text('Refund')),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isHorizontal
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            actions,
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            details,
            const SizedBox(height: 12),
            actions,
          ],
        ),
      ),
    );
  }
}
