import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tournament_model.dart';
import '../providers/tournament_provider.dart';

class TournamentInfoScreen extends StatelessWidget {
  final TournamentModel tournament;

  const TournamentInfoScreen({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.name),
        backgroundColor: const Color(0xFF183A2E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Location: ${tournament.location}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Date: ${tournament.date.toString().split(' ')[0]}", style: const TextStyle(fontSize: 16)),
            const Divider(height: 32),
            const Text("Registered Players by Category", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...tournament.categories.map((category) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.category, color: Colors.green),
                  title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${category.players.length} / ${category.slots} Slots"),
                  children: category.players.isEmpty
                      ? [const ListTile(title: Text("No players joined yet", style: TextStyle(color: Colors.grey)))]
                      : category.players.map((playerId) {
                    final user = provider.allUsers.firstWhere(
                          (u) => u.id == playerId,
                      orElse: () => provider.allUsers.first,
                    );
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(user.name.isNotEmpty ? user.name : "Player $playerId"),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}