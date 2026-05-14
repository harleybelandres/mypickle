import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  @override
  void initState() {
    super.initState();
    // Load pending tournaments when screen opens
    context.read<TournamentProvider>().fetchPendingTournaments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Approvals"),
        backgroundColor: Colors.orange.shade800,
      ),
      body: Consumer<TournamentProvider>(
        builder: (context, provider, child) {
          final pending = provider.pendingTournaments;

          if (pending.isEmpty) {
            return const Center(child: Text("No tournaments awaiting approval."));
          }

          return ListView.builder(
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final tournament = pending[index];
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(tournament.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Location: ${tournament.location}\nDate: ${tournament.date.toString().split(' ')[0]}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => provider.approveTournament(tournamentId: tournament.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => provider.rejectTournament(tournamentId: tournament.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}