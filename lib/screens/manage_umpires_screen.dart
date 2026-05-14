import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tournament_model.dart';
import '../providers/tournament_provider.dart';

class ManageUmpiresScreen extends StatefulWidget {
  final TournamentModel tournament;

  const ManageUmpiresScreen({super.key, required this.tournament});

  @override
  State<ManageUmpiresScreen> createState() => _ManageUmpiresScreenState();
}

class _ManageUmpiresScreenState extends State<ManageUmpiresScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();

    final currentTournament = provider.tournaments.firstWhere(
          (t) => t.id == widget.tournament.id,
      orElse: () => widget.tournament, // fallback
    );

    final List<String> pendingUmpireIds = currentTournament.umpireApplications.entries
        .where((entry) => entry.value == 'pending')
        .map((entry) => entry.key)
        .toList();

    return pendingUmpireIds.isEmpty
        ? const Center(
      child: Text(
        'No pending applications.',
        style: TextStyle(color: Colors.white),
      ),
    )
        : ListView.builder(
      itemCount: pendingUmpireIds.length,
      itemBuilder: (context, index) {
        final String umpireId = pendingUmpireIds[index];

        final userMatches = provider.allUsers.where((u) => u.id == umpireId);
        final name = userMatches.isNotEmpty
            ? userMatches.first.name
            : 'Umpire ${umpireId.substring(0, 4)}';

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(name),
            subtitle: const Text('Wants to umpire this event'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _handleApproval(umpireId, true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _handleApproval(umpireId, false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleApproval(String umpireId, bool approve) async {
    final provider = context.read<TournamentProvider>();
    if (approve) {
      await provider.assignUmpire(
        tournamentId: widget.tournament.id,
        umpireId: umpireId,
      );
    } else {
      await provider.rejectUmpireApplication(
        tournamentId: widget.tournament.id,
        umpireId: umpireId,
      );
    }
  }
}