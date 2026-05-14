import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/tournament_model.dart';
import 'common_ui.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({
    super.key,
    required this.tournament,
    this.onTap,
  });

  final TournamentModel tournament;
  final VoidCallback? onTap;

  // Extracted cover URL logic that was previously in the monolith
  static String _coverUrl(TournamentModel t) {
    if (t.imagePath.isNotEmpty && !t.imagePath.startsWith('data:image')) {
      return t.imagePath;
    }
    return 'https://via.placeholder.com/400x200.png?text=Tournament';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: _TournamentCoverImage(tournament: tournament),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tournament.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tournament.location,
                    style: const TextStyle(color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                  tournament.date.toLocal().toString().split(' ').first,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCoverImage extends StatelessWidget {
  const _TournamentCoverImage({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.imagePath.startsWith('data:image')) {
      return Image.memory(
        base64Decode(tournament.imagePath.split(',').last),
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      TournamentCard._coverUrl(tournament),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF183A2E),
          child: const Center(
            child: Icon(Icons.sports_tennis, color: Colors.white, size: 44),
          ),
        );
      },
    );
  }
}