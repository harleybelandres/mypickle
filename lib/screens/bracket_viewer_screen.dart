import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tournament_provider.dart';
import '../widgets/match_card.dart';
import '../models/match_model.dart';

class BracketViewerScreen extends StatefulWidget {
  final String tournamentId;
  final String categoryName;

  const BracketViewerScreen({
    super.key,
    required this.tournamentId,
    required this.categoryName,
  });

  @override
  State<BracketViewerScreen> createState() => _BracketViewerScreenState();
}

class _BracketViewerScreenState extends State<BracketViewerScreen> {
  int _selectedRound = 1;

  @override
  void initState() {
    super.initState();
    // Fetch latest matches when opening the bracket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TournamentProvider>().fetchMatchesByTournament(widget.tournamentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Bracket'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Consumer<TournamentProvider>(
            builder: (context, provider, child) {
              // Determine how many rounds exist
              final categoryMatches = provider.matches
                  .where((m) => m.categoryName == widget.categoryName)
                  .toList();

              if (categoryMatches.isEmpty) return const SizedBox.shrink();

              final maxRound = categoryMatches
                  .map((m) => m.round)
                  .reduce((a, b) => a > b ? a : b);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: List.generate(maxRound, (index) {
                    final roundNum = index + 1;
                    String roundLabel = "Round $roundNum";
                    if (roundNum == maxRound) roundLabel = "Finals";
                    else if (roundNum == maxRound - 1) roundLabel = "Semifinals";

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(roundLabel),
                        selected: _selectedRound == roundNum,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRound = roundNum);
                        },
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
      body: Consumer<TournamentProvider>(
        builder: (context, provider, child) {
          final roundMatches = provider.matches
              .where((m) =>
          m.categoryName == widget.categoryName &&
              m.round == _selectedRound)
              .toList();

          // Sort by bracket index to keep the tree order consistent
          roundMatches.sort((a, b) => a.bracketIndex.compareTo(b.bracketIndex));

          if (roundMatches.isEmpty) {
            return const Center(child: Text('No matches scheduled for this round.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roundMatches.length,
            itemBuilder: (context, index) {
              final match = roundMatches[index];
              return Column(
                children: [
                  MatchCard(match: match, canEdit: false),
                  if (index < roundMatches.length - 1)
                    const Icon(Icons.vignette_outlined, color: Colors.grey, size: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }
}