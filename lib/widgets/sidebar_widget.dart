import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive_util.dart';

class SidebarWidget extends StatefulWidget {
  final Function(String) onNavigate;
  final String? currentRoute;

  const SidebarWidget({
    Key? key,
    required this.onNavigate,
    this.currentRoute,
  }) : super(key: key);

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late List<AnimationController> _itemControllers;
  String? _hoveredItem;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'title': 'Dashboard', 'route': 'dashboard'},
    {'icon': Icons.people_alt, 'title': 'Manage Users', 'route': 'users'},
    {'icon': Icons.verified_user, 'title': 'Seller Verification', 'route': 'seller_verification'},
    {'icon': Icons.inventory, 'title': 'Products', 'route': 'products'},
    {'icon': Icons.payments, 'title': 'Release Payouts', 'route': 'release_payouts'},
  ];

  @override
  void initState() {
    super.initState();

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

    _itemControllers = List.generate(
      _menuItems.length,
          (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _fadeController.forward();
    _slideController.forward();
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 * i), () {
        if (mounted) _itemControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildAnimatedHeader() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Curves.elasticOut,
          )),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade800,
                  Colors.blue.shade600,
                  Colors.blue.shade400,
                ],
                stops: const [0.0, 0.7, 1.0],
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
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 80,
                    height: 80,
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedNavItem(
      IconData icon,
      String title,
      String route,
      int index,
      ) {
    final bool isActive = widget.currentRoute == route;
    final bool isHovered = _hoveredItem == route;

    return AnimatedBuilder(
      animation: _itemControllers[index],
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _itemControllers[index],
            curve: Curves.elasticOut,
          )),
          child: FadeTransition(
            opacity: _itemControllers[index],
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onNavigate(route),
                  onHover: (hovered) {
                    setState(() {
                      _hoveredItem = hovered ? route : null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isActive
                          ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade800,
                          Colors.blue.shade600,
                          Colors.blue.shade400,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      )
                          : null,
                      color: !isActive
                          ? (isHovered ? Colors.blue.shade50 : Colors.transparent)
                          : null,
                      border: isActive
                          ? Border.all(color: Colors.blue.shade300, width: 1)
                          : null,
                      boxShadow: isActive || isHovered
                          ? [
                        BoxShadow(
                          color: isActive
                              ? Colors.blue.shade200
                              : Colors.grey.shade200,
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withOpacity(0.2)
                                : isHovered
                                ? Colors.blue.shade100
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            color: isActive
                                ? Colors.white
                                : isHovered
                                ? Colors.blue.shade700
                                : Colors.grey.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isActive
                                  ? Colors.white
                                  : isHovered
                                  ? Colors.blue.shade700
                                  : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogout() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
          )),
          child: Container(
            margin: const EdgeInsets.all(8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  try {
                    await Supabase.instance.client.auth.signOut();

                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pushReplacementNamed('/');
                    }
                  } catch (e) {
                    debugPrint('Logout failed: $e');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.logout,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenu(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildAnimatedHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._menuItems.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> item = entry.value;
                  return _buildAnimatedNavItem(
                    item['icon'],
                    item['title'],
                    item['route'],
                    index,
                  );
                }),
                const SizedBox(height: 20),
                _buildAnimatedLogout(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget menuWidget = _buildMenu(context);

    if (ResponsiveUtil.isDesktop(context)) {
      return Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: menuWidget,
      );
    } else {
      return Drawer(
        backgroundColor: Colors.white,
        elevation: 16,
        child: menuWidget,
      );
    }
  }
}