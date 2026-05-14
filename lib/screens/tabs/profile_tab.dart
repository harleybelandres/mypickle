import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../widgets/common_ui.dart';
import '../../widgets/typography_and_rows.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.user,
    required this.isAdmin,
    required this.onLogout,
  });

  final UserModel? user;
  final bool isAdmin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HeroPanel(
          title: user!.name,
          message: user!.email,
          icon: Icons.person,
        ),
        const SizedBox(height: 20),
        SectionTitle(title: 'Account Information', count: 0),
        const SizedBox(height: 10),
        Surface(
          child: Column(
            children: [
              ProfileRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: user!.role.toUpperCase(),
              ),
              const Divider(height: 20),
              ProfileRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: user!.email,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ),
      ],
    );
  }
}