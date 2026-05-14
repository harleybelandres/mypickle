import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tournament_model.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../providers/tournament_provider.dart';
import '../widgets/match_card.dart';
import 'manage_umpires_screen.dart';
import 'manage_players_screen.dart';

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
      final provider = context.read<TournamentProvider>();
      provider.fetchMatchesByTournament(widget.tournament.id);
      provider.fetchAllUsers();
    });
  }

  // --- SCOREKEEPING DIALOG ---
  void _showScoreDialog(BuildContext context, MatchModel match) {
    final provider = context.read<TournamentProvider>();
    int scoreA = match.scoreA;
    int scoreB = match.scoreB;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Update Score"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _scoreCounter("Player A", scoreA, (val) => setDialogState(() => scoreA = val)),
                    const Text("VS", style: TextStyle(fontWeight: FontWeight.bold)),
                    _scoreCounter("Player B", scoreB, (val) => setDialogState(() => scoreB = val)),
                  ],
                ),
                if (scoreA == scoreB && scoreA != 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text("Scores cannot be tied", style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: scoreA == scoreB ? null : () async {
                  await provider.updateScore(
                    tournamentId: widget.tournament.id,
                    matchId: match.id,
                    scoreA: scoreA,
                    scoreB: scoreB,
                    playerAId: match.playerA,
                    playerBId: match.playerB,
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Save Result"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scoreCounter(String label, int value, Function(int) onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => onChanged(value + 1)),
        Text("$value", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => value > 0 ? onChanged(value - 1) : null),
      ],
    );
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
                  decoration: const InputDecoration(labelText: 'Court Number', prefixIcon: Icon(Icons.apps)),
                ),
                const SizedBox(height: 20),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedUmpireId.isEmpty ? null : selectedUmpireId,
                  hint: const Text("Select Umpire"),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("No Umpire")),
                    ...approvedUmpireIds.map((uId) {
                      final user = provider.allUsers.firstWhere((u) => u.id == uId, orElse: () => provider.allUsers.first);
                      return DropdownMenuItem(value: uId, child: Text(user.name));
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
                child: const Text('Save'),
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF183A2E),
          foregroundColor: Colors.white,
          title: const Text('Tournament Manager'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            isScrollable: false,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
            tabs: [
              Tab(icon: Icon(Icons.sports_tennis, color: Colors.white), text: 'Matches'),
              Tab(icon: Icon(Icons.group, color: Colors.white), text: 'Players'),
              Tab(icon: Icon(Icons.gavel, color: Colors.white), text: 'Umpires'),
              Tab(icon: Icon(Icons.leaderboard, color: Colors.white), text: 'Standings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: MATCHES
            Consumer<TournamentProvider>(
              builder: (context, provider, child) {
                final matches = provider.matches.where((m) => m.tournamentId == widget.tournament.id).toList();

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
                            // Check for at least 2 players in at least one category
                            bool canGenerate = widget.tournament.categories.any((cat) => cat.players.length >= 2);

                            if (canGenerate) {
                              final bracketData = {for (var cat in widget.tournament.categories) cat.name: {"players": cat.players}};
                              provider.generateRoundRobinGames(tournamentId: widget.tournament.id, bracketsByCategory: bracketData);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Each category needs at least 2 players to generate matches!")),
                              );
                            }
                          },
                          label: const Text('Generate Round Robin Matches'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF183A2E),
                            foregroundColor: Colors.white,
                          ),
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
                    return GestureDetector(
                      onTap: () => _showScoreDialog(context, match),
                      onLongPress: () => _showAssignmentDialog(context, match),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: MatchCard(match: match, canEdit: true),
                      ),
                    );
                  },
                );
              },
            ),

            // TAB 2: PLAYERS
            ManagePlayersScreen(tournament: widget.tournament),

            // TAB 3: UMPIRES
            ManageUmpiresScreen(tournament: widget.tournament),

            // TAB 4: STANDINGS
            _StandingsTab(tournamentId: widget.tournament.id),
          ],
        ),
      ),
    );
  }
}

class _StandingsTab extends StatelessWidget {
  final String tournamentId;
  const _StandingsTab({required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TournamentProvider>();
    final standings = provider.getSortedStandings();

    if (standings.isEmpty) {
      return const Center(child: Text("No standings data yet. Save match scores to see results!"));
    }

    return ListView.builder(
      itemCount: standings.length,
      itemBuilder: (context, index) {
        final entry = standings[index];
        final user = provider.allUsers.firstWhere(
                (u) => u.id == entry.key,
            orElse: () => provider.allUsers.isNotEmpty ? provider.allUsers.first : const UserModel(id: '', name: 'Unknown', email: '', role: '')
        );

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF183A2E),
            child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
          ),

          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Wins: ${entry.value['wins'] ?? 0} | Points For: ${entry.value['pointsFor'] ?? 0}"),
          trailing: Text("${entry.value['pointsFor'] ?? 0} pts", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}