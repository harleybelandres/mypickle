import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match_model.dart';
import '../providers/tournament_provider.dart';

class ScoringScreen extends StatefulWidget {
  final MatchModel match;

  const ScoringScreen({super.key, required this.match});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  late int scoreA;
  late int scoreB;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    scoreA = widget.match.scoreA;
    scoreB = widget.match.scoreB;
  }

  Future<void> _finalizeMatch() async {
    if (scoreA == scoreB) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickleball matches cannot end in a tie!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<TournamentProvider>().updateScore(
        tournamentId: widget.match.tournamentId,
        matchId: widget.match.id,
        scoreA: scoreA,
        scoreB: scoreB,
        playerAId: widget.match.playerA, // Using the 'Safe' field names
        playerBId: widget.match.playerB,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match Finalized and Bracket Updated!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildScoreColumn(String name, int score, Function(int) onUpdate) {
    return Column(
      children: [
        Text(name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text('$score',
          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.blueAccent),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: score > 0 ? () => onUpdate(score - 1) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
              child: const Icon(Icons.remove, size: 30, color: Colors.red),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () => onUpdate(score + 1),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
              child: const Icon(Icons.add, size: 30, color: Colors.green),
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Scoring')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: [
              _buildScoreColumn(widget.match.playerA, scoreA, (val) => setState(() => scoreA = val)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30.0),
                child: Divider(thickness: 2, indent: 40, endIndent: 40),
              ),
              _buildScoreColumn(widget.match.playerB, scoreB, (val) => setState(() => scoreB = val)),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: _finalizeMatch,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('FINALIZE MATCH', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}