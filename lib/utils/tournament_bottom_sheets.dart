import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../providers/tournament_provider.dart';
import '../widgets/common_ui.dart';
import '../widgets/match_card.dart';

class TournamentBottomSheets {
  /// Opens the bottom sheet to assign a match to a court and an umpire.
  static Future<Map<String, String>?> showAssignMatchSheet(
      BuildContext context, {
        required MatchModel match,
        required List<UserModel> umpires,
      }) {
    var umpireId = match.umpireId.isNotEmpty
        ? match.umpireId
        : (umpires.isNotEmpty ? umpires.first.id : '');
    final courtController = TextEditingController(text: match.courtNumber);

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign game',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: umpireId.isEmpty ? null : umpireId,
                      decoration: const InputDecoration(labelText: 'Umpire'),
                      items: umpires
                          .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.name),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => umpireId = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courtController,
                      decoration: const InputDecoration(
                        labelText: 'Court number',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, {
                          'umpireId': umpireId,
                          'courtNumber': courtController.text.trim(),
                        }),
                        icon: const Icon(Icons.check),
                        label: const Text('Save assignment'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Opens the sheet displaying all games in a tournament.
  static void showTournamentGamesSheet(
      BuildContext context,
      TournamentProvider provider, {
        required String currentUmpireId,
        required Map<String, String> userCache,
      }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tournament Games',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (provider.matches.isEmpty)
                  const EmptyState(
                    title: 'No games yet',
                    message: 'Games will appear after the creator generates them.',
                    icon: Icons.scoreboard_outlined,
                  )
                else
                  for (final match in provider.matches) ...[
                    MatchCard(
                      match: match,
                      canScore: match.umpireId == currentUmpireId,
                      onScore: () => showScoreSheetForMatch(
                        sheetContext, provider, match, userCache,
                      ),
                      userCache: userCache,
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the scoring sheet for umpires to update match results.
  static Future<void> showScoreSheetForMatch(
      BuildContext context,
      TournamentProvider provider,
      MatchModel match,
      Map<String, String> userCache,
      ) async {
    final playerNameA = userCache[match.playerA] ?? match.playerA;
    final playerNameB = userCache[match.playerB] ?? match.playerB;
    final scoreAController = TextEditingController(
      text: match.scoreA == 0 ? '' : match.scoreA.toString(),
    );
    final scoreBController = TextEditingController(
      text: match.scoreB == 0 ? '' : match.scoreB.toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Score',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            playerNameA,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: scoreAController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(labelText: 'Score'),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black38)),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            playerNameB,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: scoreBController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(labelText: 'Score'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final scoreA = int.tryParse(scoreAController.text) ?? 0;
                      final scoreB = int.tryParse(scoreBController.text) ?? 0;
                      provider.updateMatchScore(match.id, scoreA, scoreB);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save match score'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}