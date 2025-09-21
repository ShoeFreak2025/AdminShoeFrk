import 'package:flutter/material.dart';
import 'package:shoefrk_admin/screens/artworks_tab.dart';
import 'package:shoefrk_admin/screens/orders_screen.dart';
import 'package:shoefrk_admin/screens/shoes_tab.dart';
import 'package:shoefrk_admin/screens/reported_shoes_tab.dart';
import 'package:shoefrk_admin/screens/dashboard_screen.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtil.isMobile(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
          ),
          title: Text(
            'Manage Products',
            style: TextStyle(
              fontSize: ResponsiveUtil.responsiveValue(
                context: context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(
              ResponsiveUtil.responsiveValue(
                context: context,
                mobile: 70.0,
                tablet: 65.0,
                desktop: 60.0,
              ),
            ),
            child: Container(
              color: Colors.blue.shade700,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtil.responsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 16.0,
                  desktop: 24.0,
                ),
              ),
              child: TabBar(
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                dividerColor: Colors.transparent,
                indicator: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white,
                      width: 3.0,
                    ),
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: ResponsiveUtil.responsiveValue(
                    context: context,
                    mobile: 11,
                    tablet: 13,
                    desktop: 15,
                  ),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: ResponsiveUtil.responsiveValue(
                    context: context,
                    mobile: 10,
                    tablet: 12,
                    desktop: 14,
                  ),
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                overlayColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.pressed)) {
                    return Colors.white.withOpacity(0.1);
                  }
                  return Colors.transparent;
                }),
                tabs: _buildTabs(context, isMobile, screenWidth),
              ),
            ),
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

  List<Widget> _buildTabs(BuildContext context, bool isMobile, double screenWidth) {
    final double iconSize = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 22,
      tablet: 26,
      desktop: 28,
    );

    final double spacing = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 6.0,
      tablet: 8.0,
      desktop: 10.0,
    );
    if (isMobile) {
      return [
        _buildMobileTab(Icons.shopping_bag, 'Shoes', iconSize, spacing),
        _buildMobileTab(Icons.brush, 'Artworks', iconSize, spacing),
        _buildMobileTab(Icons.report, 'Reported', iconSize, spacing),
        _buildMobileTab(Icons.receipt_long, 'Orders', iconSize, spacing),
      ];
    }
    return [
      Tab(
        icon: Icon(Icons.shopping_bag, size: iconSize),
        text: 'Shoes',
        iconMargin: EdgeInsets.only(bottom: spacing),
      ),
      Tab(
        icon: Icon(Icons.brush, size: iconSize),
        text: 'Artworks',
        iconMargin: EdgeInsets.only(bottom: spacing),
      ),
      Tab(
        icon: Icon(Icons.report, size: iconSize),
        text: 'Reported',
        iconMargin: EdgeInsets.only(bottom: spacing),
      ),
      Tab(
        icon: Icon(Icons.receipt_long, size: iconSize),
        text: 'Orders',
        iconMargin: EdgeInsets.only(bottom: spacing),
      ),
    ];
  }

  Widget _buildMobileTab(IconData icon, String text, double iconSize, double spacing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
          ),
          SizedBox(height: spacing),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}