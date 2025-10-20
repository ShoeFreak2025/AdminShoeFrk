import 'package:flutter/material.dart';
import 'package:shoefrk_admin/screens/artworks_tab.dart';
import 'package:shoefrk_admin/screens/orders_screen.dart';
import 'package:shoefrk_admin/screens/shoes_tab.dart';
import 'package:shoefrk_admin/screens/reported_shoes_tab.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';
import 'package:shoefrk_admin/widgets/sidebar_widget.dart';

class ProductScreen extends StatefulWidget {
  final Function(String)? onNavigate;

  const ProductScreen({super.key, this.onNavigate});

  @override
  State<ProductScreen> createState() => _ProductScreenState();

}

class _ProductScreenState extends State<ProductScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleNavigation(String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      String routeName;
      switch (route) {
        case 'dashboard':
          routeName = '/dashboard';
          break;
        case 'users':
          routeName = '/users';
          break;
        case 'seller_verification':
          routeName = '/seller-verification';
          break;
        case 'products':
          routeName = '/products';
          break;
        case 'release_payouts':
          routeName = '/release-payouts';
          break;
        default:
          routeName = '/dashboard';
      }
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  Widget _buildAnimatedTab(IconData icon, String text, double iconSize, double spacing, int index) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _fadeController,
              curve: Interval(
                index * 0.2,
                1.0,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.5),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _slideController,
              curve: Interval(
                index * 0.1,
                1.0,
                curve: Curves.elasticOut,
              ),
            )),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(height: spacing),
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: ResponsiveUtil.responsiveValue(
                          context: context,
                          mobile: 9,
                          tablet: 10,
                          desktop: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTabs(BuildContext context, bool isMobile, double screenWidth) {
    final double iconSize = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 16,
      tablet: 18,
      desktop: 20,
    );

    final double spacing = ResponsiveUtil.responsiveValue(
      context: context,
      mobile: 2.0,
      tablet: 3.0,
      desktop: 4.0,
    );

    final List<Map<String, dynamic>> tabData = [
      {'icon': Icons.shopping_bag, 'text': 'Shoes'},
      {'icon': Icons.brush, 'text': 'Artworks'},
      {'icon': Icons.report, 'text': 'Reported'},
      {'icon': Icons.receipt_long, 'text': 'Orders'},
    ];

    if (isMobile) {
      return tabData.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> tab = entry.value;
        return _buildAnimatedTab(
          tab['icon'],
          tab['text'],
          iconSize,
          spacing,
          index,
        );
      }).toList();
    }

    return tabData.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> tab = entry.value;
      return Tab(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _fadeController,
                  curve: Interval(
                    index * 0.15,
                    1.0,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(tab['icon'], size: iconSize),
                    ),
                    SizedBox(height: spacing),
                    Flexible(
                      child: Text(
                        tab['text'],
                        style: TextStyle(
                          fontSize: ResponsiveUtil.responsiveValue(
                            context: context,
                            mobile: 9,
                            tablet: 10,
                            desktop: 11,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }

  Widget _buildHeader() {
    final bool showHamburger = !ResponsiveUtil.isDesktop(context);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          height: ResponsiveUtil.responsiveValue(
            context: context,
            mobile: 130,
            tablet: 140,
            desktop: 150,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade800,
                Colors.blue.shade600,
                Colors.blue.shade400,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200,
                spreadRadius: 2,
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: ResponsiveUtil.responsiveValue(
                  context: context,
                  mobile: 55,
                  tablet: 60,
                  desktop: 65,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtil.responsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 20.0,
                    desktop: 24.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showHamburger)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: ResponsiveUtil.responsiveValue(
                                context: context,
                                mobile: 24,
                                tablet: 24,
                                desktop: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showHamburger)
                      const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory,
                        color: Colors.white,
                        size: ResponsiveUtil.responsiveValue(
                          context: context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Manage Products',
                        style: TextStyle(
                          fontSize: ResponsiveUtil.responsiveValue(
                            context: context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtil.responsiveValue(
                          context: context,
                          mobile: 8.0,
                          tablet: 16.0,
                          desktop: 24.0,
                        ),
                        vertical: 8.0,
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        tabAlignment: TabAlignment.fill,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: TextStyle(
                          fontSize: ResponsiveUtil.responsiveValue(
                            context: context,
                            mobile: 9,
                            tablet: 10,
                            desktop: 11,
                          ),
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: ResponsiveUtil.responsiveValue(
                            context: context,
                            mobile: 8,
                            tablet: 9,
                            desktop: 10,
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
                        tabs: _buildTabs(context, ResponsiveUtil.isMobile(context),
                            MediaQuery.of(context).size.width),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
        )),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: TabBarView(
            controller: _tabController,
            children: const [
              ShoesTab(),
              ArtworksTab(),
              ReportedShoesTab(),
              OrdersTab(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showDrawer = !ResponsiveUtil.isDesktop(context);

    if (widget.onNavigate != null) {
      return Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: showDrawer
          ? SidebarWidget(
        onNavigate: _handleNavigation,
        currentRoute: 'products',
      )
          : null,
      body: Row(
        children: [
          if (ResponsiveUtil.isDesktop(context))
            SidebarWidget(
              onNavigate: _handleNavigation,
              currentRoute: 'products',
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}