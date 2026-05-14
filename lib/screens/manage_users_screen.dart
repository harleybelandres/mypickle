import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';
import '../widgets/common_ui.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TournamentProvider>().fetchAllUsers());
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<TournamentProvider>().allUsers;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return Surface(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF183A2E),
                child: Text(user.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(user.email),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user.role == 'admin' ? Colors.amber.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: user.role == 'admin' ? Colors.amber.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}