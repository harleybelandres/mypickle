import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';
import 'tournament_management_screen.dart';

class MyHostedTournamentsScreen extends StatelessWidget {
  final String userId;

  const MyHostedTournamentsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();

    // Filter to only show tournaments created by this user
    final hostedTournaments = provider.tournaments
        .where((t) => t.creatorId == userId) // Make sure 'creatorId' matches your TournamentModel
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage My Tournaments'),
        backgroundColor: const Color(0xFF183A2E),
        foregroundColor: Colors.white,
      ),
      body: hostedTournaments.isEmpty
          ? const Center(child: Text('You are not hosting any tournaments.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: hostedTournaments.length,
        itemBuilder: (context, index) {
          final tournament = hostedTournaments[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: Text(tournament.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${tournament.status.toUpperCase()} - ${tournament.date}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to the Management Tab we built!
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TournamentManagementScreen(
                      tournament: tournament,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}