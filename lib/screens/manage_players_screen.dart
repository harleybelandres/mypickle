import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart'; // Added this import
import '../providers/tournament_provider.dart';

class ManagePlayersScreen extends StatelessWidget {
  final TournamentModel tournament;

  const ManagePlayersScreen({super.key, required this.tournament});

  // Helper method to look up names
  String getPlayerName(String id, List<UserModel> allUsers) {
    final user = allUsers.firstWhere(
          (u) => u.id == id,
      orElse: () => UserModel(id: id, name: "Unknown Player", email: "", role: ""),
    );
    return user.name;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();

    // Get fresh tournament data from the provider
    final currentTournament = provider.tournaments.firstWhere(
          (t) => t.id == tournament.id,
      orElse: () => tournament,
    );

    return ListView.builder(
      itemCount: currentTournament.categories.length,
      itemBuilder: (context, catIndex) {
        final category = currentTournament.categories[catIndex];

        return ExpansionTile(
          // Using a darker green/grey to match your theme
          backgroundColor: Colors.black.withValues(alpha: 0.05),
          title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF183A2E))
          ),
          subtitle: Text('${category.players.length} / ${category.slots} Slots Filled'),
          children: category.players.isEmpty
              ? [const ListTile(title: Text("No players registered yet", style: TextStyle(color: Colors.grey)))]
              : category.players.map((playerId) {

            // LOOKUP: Get the actual name from allUsers
            final String displayName = getPlayerName(playerId, provider.allUsers);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF183A2E),
                radius: 16,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(displayName),
              subtitle: Text("ID: ${playerId.substring(0, 5)}..."), // Small ID reference
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () {
                  // Logic to remove player from category
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Player removal logic not implemented yet'))
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}