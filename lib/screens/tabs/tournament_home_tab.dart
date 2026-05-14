import 'package:flutter/material.dart';
import '../../models/tournament_model.dart';

import '../../widgets/common_ui.dart';
import '../../widgets/tournament_card.dart';
import '../../widgets/animated_in.dart';
import '../tournament_details_screen.dart';

class TournamentHomeTab extends StatelessWidget {
  const TournamentHomeTab({
    super.key,
    required this.tournaments,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  final List<TournamentModel> tournaments;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final filtered = _filterTournaments(tournaments, searchQuery);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const AnimatedIn(
            child: HeroPanel(
              title: 'Find approved tournaments',
              message:
              'Browse active pickleball events, categories, slots, and locations.',
              icon: Icons.sports_tennis,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search tournaments',
              hintText: 'Title, address, date, category, skill level',
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle(title: 'Approved Tournaments', count: filtered.length),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: filtered.isEmpty
                ? const EmptyState(
              key: ValueKey('no-approved'),
              title: 'No tournaments found',
              message:
              'Try another title, address, date, category, or skill.',
              icon: Icons.event_busy_outlined,
            )
                : Column(
              key: const ValueKey('approved-list'),
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  AnimatedIn(
                    delay: 80 + (i * 45),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TournamentDetailsScreen(
                              tournament: filtered[i],
                            ),
                          ),
                        );
                      },
                      child: TournamentCard(tournament: filtered[i]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<TournamentModel> _filterTournaments(
      List<TournamentModel> tournaments,
      String query,
      ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return tournaments;

    return tournaments.where((t) {
      final date = t.date.toLocal().toString().split(' ').first;
      final haystack = [
        t.name,
        t.location,
        date,
        for (final category in t.categories) category.name,
        for (final category in t.categories) category.skillLevel,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }
}