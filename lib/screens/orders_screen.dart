import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';

enum OrderStatus {
  PENDING_APPROVAL,
  TO_SHIP,
  SHIPPED,
  TO_DELIVER,
  DELIVERED,
  REFUNDED,
  RETURNED,
}

extension OrderStatusExtension on OrderStatus {
  String get name => toString().split('.').last;
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      final data = await supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      if (data != null) {
        setState(() {
          orders = List<Map<String, dynamic>>.from(data as List);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching orders: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateOrderStatus(
      String orderId,
      OrderStatus status, {
        String? trackingNumber,
      }) async {
    try {
      await supabase.from('orders').update({
        'status': status.name,
        if (trackingNumber != null) 'tracking_number': trackingNumber,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      final logRes = await supabase.functions.invoke(
        'log_action',
        body: {
          'action': 'update_order_status',
          'target_id': orderId,
          'target_type': 'order',
          'details': {
            'new_status': status.name,
            if (trackingNumber != null) 'tracking_number': trackingNumber,
          },
        },
      );

      if (logRes.status != 200) {
        debugPrint("⚠️ Log failed [${logRes.status}]: ${logRes.data}");
      }

      await fetchOrders();
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cardPadding = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 12,
      tablet: 16,
      desktop: 20,
    );

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'No orders found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(cardPadding),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final status = order['status'] ?? 'UNKNOWN';
        final tracking = order['tracking_number'];

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(cardPadding),
            title: Text(
              'Order #${order['id']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $status'),
                  if (tracking != null) Text('Tracking: $tracking'),
                ],
              ),
            ),
            trailing: PopupMenuButton<OrderStatus>(
              onSelected: (newStatus) {
                updateOrderStatus(order['id'], newStatus);
              },
              itemBuilder: (context) {
                return OrderStatus.values.map((status) {
                  return PopupMenuItem(
                    value: status,
                    child: Text(status.name),
                  );
                }).toList();
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Update Status',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
