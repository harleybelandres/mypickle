import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../widgets/animated_in.dart';
import '../../widgets/common_ui.dart';
import '../admin_approval_screen.dart';
import '../tournament_create_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.user,
    required this.isAdmin,
    required this.onManageTournaments,
    required this.onManageHostedTournaments,
    required this.onManageUsers,
    required this.onViewReports,
  });

  final UserModel? user;
  final bool isAdmin;
  final VoidCallback onManageTournaments;
  final VoidCallback onManageHostedTournaments;
  final VoidCallback onManageUsers;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    final userName = user?.name ?? 'Player';
    final userRole = user?.role ?? 'player';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        AnimatedIn(
          child: _DashboardHeader(
            name: userName,
            role: userRole,
            isAdmin: isAdmin,
          ),
        ),
        const SizedBox(height: 24),
        AnimatedIn(
          delay: 80,
          child: SectionTitle(
              title: 'Quick Actions',
              count: isAdmin ? 6 : 3
          ),
        ),
        const SizedBox(height: 12),

        // --- 1. HOST A TOURNAMENT (Visible to all users) ---
        AnimatedIn(
          delay: 100,
          child: _QuickActionCard(
            icon: Icons.add_circle_outline,
            title: 'Host a Tournament',
            message: 'Submit a new event for community approval',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TournamentCreateScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // --- 2. MANAGE HOSTED TOURNAMENTS (Visible to all users) ---
        AnimatedIn(
          delay: 110,
          child: _QuickActionCard(
            icon: Icons.settings_suggest_outlined, // A nice gear icon
            title: 'Manage Hosted Tournaments',
            message: 'Approve umpires, assign courts, and manage matches',
            onTap: onManageHostedTournaments,
          ),
        ),
        const SizedBox(height: 12),

        // --- 3. MANAGE / MY TOURNAMENTS ---
        AnimatedIn(
          delay: 120,
          child: _QuickActionCard(
            icon: Icons.emoji_events_outlined,
            title: isAdmin ? 'Manage All Tournaments' : 'My Registered Events',
            message: isAdmin
                ? 'Create, edit, or delete events'
                : 'View events you have registered for',
            onTap: onManageTournaments,
          ),
        ),
        const SizedBox(height: 12),

        // --- 4. ADMIN ONLY: PENDING APPROVALS ---
        if (isAdmin) ...[
          AnimatedIn(
            delay: 140,
            child: _QuickActionCard(
              icon: Icons.fact_check_outlined,
              title: 'Tournament Approvals',
              message: 'Review and approve new event requests',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminApprovalScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          AnimatedIn(
            delay: 160,
            child: _QuickActionCard(
              icon: Icons.people_outline,
              title: 'Manage Users',
              message: 'Update roles and view user profiles',
              onTap: onManageUsers,
            ),
          ),
          const SizedBox(height: 12),

          AnimatedIn(
            delay: 200,
            child: _QuickActionCard(
              icon: Icons.bar_chart_outlined,
              title: 'System Reports',
              message: 'View analytics and activity logs',
              onTap: onViewReports,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.role,
    required this.isAdmin,
  });

  final String name;
  final String role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return HeroPanel(
      title: name,
      message: '${role.toUpperCase()} workspace',
      icon: isAdmin ? Icons.admin_panel_settings_outlined : Icons.person,
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Surface(
        child: Row(
          children: [
            _IconBadge(
              icon: icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}