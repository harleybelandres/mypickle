import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/tournament_provider.dart';
import '../services/auth_service.dart';

import 'my_hosted_tournaments_screen.dart';
import 'tabs/tournament_home_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/profile_tab.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _searchController = TextEditingController();

  var _selectedIndex = 0;
  var _isRefreshing = false;
  var _searchQuery = '';

  UserModel? get _currentUser => _auth.getCurrentUser();
  bool get _isAdmin => _currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TournamentProvider>(context, listen: false);
      // Only call this if the method exists in your provider
      provider.subscribeToApprovedTournaments();
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = Provider.of<TournamentProvider>(context, listen: false);
      await provider.fetchApprovedTournaments();
    } catch (e) {
      debugPrint("Refresh error: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _handleLogout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    final List<Widget> pages = [
      TournamentHomeTab(
        tournaments: provider.tournaments,
        searchController: _searchController,
        searchQuery: _searchQuery,
        onSearchChanged: (val) => setState(() => _searchQuery = val),
        onRefresh: _refresh,
      ),
      DashboardTab(
        user: _currentUser,
        isAdmin: _isAdmin,
        onManageTournaments: () {
          Navigator.pushNamed(context, '/manage_tournaments');
        },
        onManageHostedTournaments: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyHostedTournamentsScreen(
                userId: _currentUser?.id ?? '', // FIXED: Added the underscore here!
              ),
            ),
          );
        },
        onManageUsers: () {
          Navigator.pushNamed(context, '/manage_users');
        },
        onViewReports: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reports coming soon!')),
          );
        },
      ),
      ProfileTab(
        user: _currentUser,
        isAdmin: _isAdmin,
        onLogout: _handleLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF183A2E),
        title: const Text(
          'Pickleball Manager',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_tennis_outlined),
            label: 'Tournaments',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}