import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';
import '../models/user_model.dart';

class StandingsScreen extends StatefulWidget {
  final String tournamentId;
  final String categoryName;

  const StandingsScreen({
    super.key,
    required this.tournamentId,
    required this.categoryName,
  });

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<TournamentProvider>();
    // 1. Fetch all matches to ensure stats are current
    await provider.fetchMatchesByTournament(widget.tournamentId);

    // 2. Identify all players in this category
    final matches = provider.matches.where((m) => m.categoryName == widget.categoryName).toList();
    final playerIds = <String>{};
    for (var m in matches) {
      if (m.playerA != 'BYE' && m.playerA != 'TBD') playerIds.add(m.playerA);
      if (m.playerB != 'BYE' && m.playerB != 'TBD') playerIds.add(m.playerB);
    }

    // 3. Fetch stats for each player
    for (var id in playerIds) {
      await provider.fetchPlayerStats(id);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.categoryName} Standings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<TournamentProvider>(
        builder: (context, provider, child) {
          final standings = provider.getSortedStandings();

          if (standings.isEmpty) {
            return const Center(child: Text('No match data available yet.'));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
              columns: const [
                DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Player', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('W-L', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Diff', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List<DataRow>.generate(standings.length, (index) {
                final entry = standings[index];
                final stats = entry.value;
                final isTopThree = index < 3;

                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}',
                        style: TextStyle(fontWeight: isTopThree ? FontWeight.bold : FontWeight.normal))),
                    DataCell(Text(entry.key.split('@')[0])), // Showing partial ID or Name
                    DataCell(Text('${stats['wins']}-${stats['losses']}')),
                    DataCell(
                      Text(
                        '${(stats['pointDiff'] ?? 0) > 0 ? "+" : ""}${stats['pointDiff']}',
                        style: TextStyle(
                          color: (stats['pointDiff'] ?? 0) > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          );
        },
      ),
    );
  }
}