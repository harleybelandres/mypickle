import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tournament_model.dart';
import '../providers/tournament_provider.dart';
import '../services/auth_service.dart';
import 'tournament_management_screen.dart';
import 'bracket_viewer_screen.dart';
import 'standings_screen.dart';

class TournamentDetailsScreen extends StatelessWidget {
  final TournamentModel tournament;

  const TournamentDetailsScreen({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthService>();
    final isCreator = authProvider.getCurrentUser()?.id == tournament.creatorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.name),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentManagementScreen(tournament: tournament),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Image/Info
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.blueGrey.shade100,
              child: const Icon(Icons.sports_tennis, size: 80, color: Colors.white),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tournament.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(tournament.location),
                    ],
                  ),
                  const Divider(height: 32),

                  // 2. Tournament Actions
                  const Text("Tournament Hub", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.account_tree,
                          label: "Brackets",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BracketViewerScreen(
                                tournamentId: tournament.id,
                                categoryName: tournament.categories.first.name,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.emoji_events,
                          label: "Standings",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StandingsScreen(
                                tournamentId: tournament.id,
                                categoryName: tournament.categories.first.name,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Category Registration List
                  const Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tournament.categories.length,
                    itemBuilder: (context, index) {
                      final category = tournament.categories[index];
                      final isFull = category.players.length >= category.slots;
                      final isRegistered = category.players.contains(authProvider.getCurrentUser()?.id);

                      return Card(
                        child: ListTile(
                          title: Text(category.name),
                          subtitle: Text("Slots: ${category.players.length}/${category.slots}"),
                          trailing: isRegistered
                              ? const Chip(label: Text("Registered"), backgroundColor: Colors.greenAccent)
                              : ElevatedButton(
                            onPressed: (isFull || isCreator) ? null : () => _register(context, category.name),
                            child: Text(isFull ? "Full" : "Join"),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 4. Umpire Volunteer Button
                  if (!isCreator)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text("Volunteer as Umpire"),
                        onPressed: () => _applyAsUmpire(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _register(BuildContext context, String categoryName) async {
    final authProvider = context.read<AuthService>();
    final user = authProvider.getCurrentUser();

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to register.")),
      );
      return;
    }

    try {
      // Show a loading indicator
      await context.read<TournamentProvider>().registerPlayer(
        tournamentId: tournament.id,
        playerId: user.id,
        categoryName: categoryName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registered successfully!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: ${e.toString()}")),
        );
      }
    }
  }

  void _applyAsUmpire(BuildContext context) async {
    try {
      await context.read<TournamentProvider>().applyAsUmpire(
        tournamentId: tournament.id,
        umpireId: context.read<AuthService>().getCurrentUser()!.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application sent to creator!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}