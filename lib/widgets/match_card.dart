import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../screens/scoring_screen.dart';

class MatchCard extends StatelessWidget {
  final MatchModel match;
  final bool canEdit;

  const MatchCard({super.key, required this.match, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            // Player A
            Expanded(
              child: Text(
                match.playerA,
                textAlign: TextAlign.start,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            // Score Center
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${match.scoreA} - ${match.scoreB}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            // Player B
            Expanded(
              child: Text(
                match.playerB,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Court: ${match.courtNumber.isEmpty ? "TBD" : match.courtNumber} | ${match.categoryName}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: canEdit
            ? const Icon(Icons.edit_note, color: Colors.blue)
            : (match.isFinished ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : null),
        onTap: canEdit
            ? () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ScoringScreen(match: match)),
        )
            : null,
      ),
    );
  }
}