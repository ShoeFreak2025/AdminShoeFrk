import 'package:flutter/material.dart';
import 'package:shoefrk_admin/screens/artworks_tab.dart';
import 'package:shoefrk_admin/screens/orders_screen.dart';
import 'package:shoefrk_admin/screens/shoes_tab.dart';
import 'package:shoefrk_admin/screens/reported_shoes_tab.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Products'),
          backgroundColor: Colors.blue.shade700,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_bag), text: 'Shoes'),
              Tab(icon: Icon(Icons.brush), text: 'Artworks'),
              Tab(icon: Icon(Icons.report), text: 'Reported'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Orders')
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ShoesTab(),
            ArtworksTab(),
            ReportedShoesTab(),
            OrdersTab(),
          ],
        ),
      ),
    );
  }
}
