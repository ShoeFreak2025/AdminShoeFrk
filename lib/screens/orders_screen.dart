import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum OrderStatus {
  PENDING_APPROVAL,
  TO_SHIP,
  SHIPPED,
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
      debugPrint('Error fetching orders: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status, {String? trackingNumber}) async {
    try {
      await supabase
          .from('orders')
          .update({
        'status': status.name,
        if (trackingNumber != null) 'tracking_number': trackingNumber,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', orderId);

      // Refresh orders list
      await fetchOrders();
    } catch (e) {
      debugPrint('Error updating order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return ListTile(
          title: Text('Order ${order['id']}'),
          subtitle: Text('Status: ${order['status']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (order['tracking_number'] != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text('Tracking: ${order['tracking_number']}'),
                ),
              PopupMenuButton<OrderStatus>(
                onSelected: (status) {
                  updateOrderStatus(order['id'], status);
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Update Status',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
