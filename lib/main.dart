import 'package:flutter/material.dart';
import 'package:shoefrk_admin/screens/ReleasePayoutScreen.dart';
import 'package:shoefrk_admin/screens/product_screen.dart';
import 'package:shoefrk_admin/screens/seller_verification_screen.dart';
import 'package:shoefrk_admin/screens/users_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mnrqpptcreskqnynhevx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ucnFwcHRjcmVza3FueW5oZXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzUxOTgsImV4cCI6MjA2Njc1MTE5OH0.OJb88vi6TYrLDDkwY5P2J4XKNvJxCLM-cDFveM51500',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // root
      routes: {
        '/': (context) => const AuthWrapper(),
        '/dashboard': (context) => const DashboardScreen(),
        '/users': (context) => const UsersScreen(),
        '/seller-verification': (context) => const SellerVerificationScreen(),
        '/products': (context) => const ProductScreen(),
        '/release-payouts': (context) => const ReleasePayoutScreen(),
      },
    );
  }
}


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final supabase = Supabase.instance.client;
  User? _user;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    supabase.auth.onAuthStateChange.listen((data) {
      setState(() {
        _user = data.session?.user;
      });
      if (_user != null) {
        _checkAdminStatus();
      } else {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _checkAuth() async {
    setState(() => _isLoading = true);
    final session = supabase.auth.currentSession;
    _user = session?.user;

    if (_user != null) {
      await _checkAdminStatus();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    if (_user == null) return;

    try {
      final response = await supabase
          .from('users')
          .select('is_admin')
          .eq('id', _user!.id)
          .single();

      setState(() {
        _isAdmin = response['is_admin'] == true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null || !_isAdmin) {
      return const LoginScreen();
    }

    return const DashboardScreen();
  }
}