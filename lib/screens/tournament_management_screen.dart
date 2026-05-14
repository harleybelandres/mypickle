import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tournament_model.dart';
import '../models/match_model.dart';
import '../providers/tournament_provider.dart';
import '../widgets/match_card.dart';
import 'manage_umpires_screen.dart';

class TournamentManagementScreen extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentManagementScreen({super.key, required this.tournament});

  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TournamentProvider>().fetchMatchesByTournament(widget.tournament.id);
    });
  }

  void _showAssignmentDialog(BuildContext context, MatchModel match) {
    String selectedUmpireId = match.umpireId;
    final courtController = TextEditingController(text: match.courtNumber);
    final provider = context.read<TournamentProvider>();

    final List<String> approvedUmpireIds = widget.tournament.umpireApplications.entries
        .where((entry) => entry.value == 'approved')
        .map((entry) => entry.key)
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Assign Court & Umpire'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: courtController,
                  decoration: const InputDecoration(
                      labelText: 'Court Number',
                      prefixIcon: Icon(Icons.apps),
                      hintText: 'e.g. Court 1'
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Select Approved Umpire:", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedUmpireId.isEmpty ? null : selectedUmpireId,
                  hint: const Text("Select Umpire"),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("No Umpire")),
                    ...approvedUmpireIds.map((String uId) {

                      // Find the user by ID
                      final user = provider.allUsers.firstWhere(
                            (u) => u.id == uId,
                        orElse: () => provider.allUsers.first, // Fallback
                      );

                      return DropdownMenuItem(
                        value: uId,
                        child: Text(user.name.isNotEmpty ? user.name : "Umpire ${uId.substring(0, 4)}"),
                      );
                    }),
                  ],
                  onChanged: (val) => setDialogState(() => selectedUmpireId = val ?? ""),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  await provider.updateMatchAssignment(
                    tournamentId: widget.tournament.id,
                    matchId: match.id,
                    umpireId: selectedUmpireId,
                    courtNumber: courtController.text,
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF183A2E),
          foregroundColor: Colors.white,
          title: const Text('Tournament Manager'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.sports_tennis), text: 'Matches'),
              Tab(icon: Icon(Icons.people), text: 'Umpires'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: MATCH MANAGEMENT
            Consumer<TournamentProvider>(
              builder: (context, provider, child) {
                final matches = provider.matches
                    .where((m) => m.tournamentId == widget.tournament.id)
                    .toList();

                if (matches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No matches generated yet.'),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          onPressed: () {
                            // This would call your automated generation
                            // provider.generateRoundRobinGames(...)
                          },
                          label: const Text('Generate Initial Matches'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onLongPress: () => _showAssignmentDialog(context, match),
                        child: MatchCard(
                          match: match,
                          canEdit: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // TAB 2: UMPIRE MANAGEMENT
            ManageUmpiresScreen(tournament: widget.tournament),
          ],
        ),
      ),
    );
  }
}