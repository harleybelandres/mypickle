import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';
import '../widgets/tournament_card.dart';

class ManageTournamentsScreen extends StatefulWidget {
  const ManageTournamentsScreen({super.key});

  @override
  State<ManageTournamentsScreen> createState() => _ManageTournamentsScreenState();
}

class _ManageTournamentsScreenState extends State<ManageTournamentsScreen> {
  @override
  void initState() {
    super.initState();
    // Load pending tournaments as soon as the screen opens
    Future.microtask(() =>
        context.read<TournamentProvider>().fetchPendingTournaments());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();
    final pending = provider.pendingTournaments;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tournaments')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchPendingTournaments(),
        child: pending.isEmpty
            ? const Center(child: Text('No pending requests.'))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final t = pending[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                children: [
                  TournamentCard(tournament: t),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => provider.rejectTournament(tournamentId: t.id),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => provider.approveTournament(tournamentId: t.id),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}