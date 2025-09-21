import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shoefrk_admin/models/dashboard_stats.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';

class TopItemsWidget extends StatefulWidget {
  const TopItemsWidget({Key? key}) : super(key: key);

  @override
  _TopItemsWidgetState createState() => _TopItemsWidgetState();
}

class _TopItemsWidgetState extends State<TopItemsWidget> {
  List<TopItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTopItems();
  }

  Future<void> fetchTopItems() async {
    try {
      final url = Uri.parse(
          'https://mnrqpptcreskqnynhevx.supabase.co/functions/v1/Get-Top-Items');
      final response = await http.get(
        url,
        headers: {
          'Authorization':
          'Bearer 4be938ecc8b125c07f219550ce94c62b1ee325c32320318b49235d11104cda91'
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _items = data.map((e) => TopItem.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        throw Exception('Failed to load top items');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double padding = ResponsiveUtil.responsiveValue<double>(
      context: context,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    final double iconSize = ResponsiveUtil.responsiveValue<double>(
      context: context,
      mobile: 20,
      tablet: 22,
      desktop: 24,
    );

    final double titleSize = ResponsiveUtil.responsiveValue<double>(
      context: context,
      mobile: 16,
      tablet: 18,
      desktop: 20,
    );

    final double subtitleSize = ResponsiveUtil.responsiveValue<double>(
      context: context,
      mobile: 12,
      tablet: 13,
      desktop: 14,
    );

    return Container(
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
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up,
                    color: Colors.orange.shade600, size: iconSize),
                const SizedBox(width: 8),
                Text(
                  'Top Items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: titleSize,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),

            SizedBox(height: padding),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_items.isEmpty)
              Container(
                padding: EdgeInsets.all(padding * 2),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: iconSize * 2, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No sold items yet',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: subtitleSize),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.shade200,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: padding / 2),
                    child: Row(
                      children: [
                        Container(
                          width: ResponsiveUtil.responsiveValue<double>(
                            context: context,
                            mobile: 36,
                            tablet: 40,
                            desktop: 44,
                          ),
                          height: ResponsiveUtil.responsiveValue<double>(
                            context: context,
                            mobile: 36,
                            tablet: 40,
                            desktop: 44,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: subtitleSize,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: titleSize)),
                              const SizedBox(height: 4),
                              Text('${item.quantitySold} sold',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: subtitleSize)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₱${item.revenue.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: titleSize,
                                    color: Colors.green)),
                            const SizedBox(height: 4),
                            Text('Revenue',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: subtitleSize)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
