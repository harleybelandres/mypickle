import 'package:hive_flutter/hive_flutter.dart';

import '../models/category_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';

/// Local persistence for PickleTrack (no Firebase).
///
/// Boxes store plain Maps so we can reuse existing `toMap/fromMap`.
class LocalDbService {
  LocalDbService._();

  static final LocalDbService instance = LocalDbService._();

  static const _usersBox = 'users';
  static const _tournamentsBox = 'tournaments';
  static const _matchesBox = 'matches';

  static const _sessionBox = 'session';
  static const _currentUserIdKey = 'currentUserId';

  Future<void> init() async {
    await Hive.initFlutter();

    // One-time open boxes.
    await Future.wait([
      Hive.openBox<Map>(_usersBox),
      Hive.openBox<Map>(_tournamentsBox),
      Hive.openBox<Map>(_matchesBox),
      Hive.openBox<Map>(_sessionBox),
    ]);
  }

  Box<Map> get _users => Hive.box<Map>(_usersBox);
  Box<Map> get _tournaments => Hive.box<Map>(_tournamentsBox);
  Box<Map> get _matches => Hive.box<Map>(_matchesBox);
  Box<Map> get _session => Hive.box<Map>(_sessionBox);

  Map<String, dynamic> _mutableMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _mutableUmpireApplications(Object? value) {
    final raw = _mutableMap(value);
    final apps = <String, dynamic>{};

    for (final entry in raw.entries) {
      final appValue = entry.value;
      if (appValue is Map) {
        apps[entry.key] = Map<String, dynamic>.from(appValue);
      } else {
        apps[entry.key] = {
          'umpireId': entry.key,
          'status': (appValue ?? 'pending').toString(),
        };
      }
    }

    return apps;
  }

  // -------------------- Auth/session --------------------

  String? getCurrentUserId() {
    final map = _session.get(_currentUserIdKey);
    if (map == null) return null;
    return map['value'] as String?;
  }

  Future<void> setCurrentUserId(String? userId) async {
    if (userId == null) {
      await _session.delete(_currentUserIdKey);
      return;
    }
    await _session.put(_currentUserIdKey, {'value': userId});
  }

  // -------------------- Users --------------------

  Future<void> upsertUser({required UserModel user}) async {
    await _users.put(user.id, user.toMap());
  }

  UserModel? getUserById(String userId) {
    final data = _users.get(userId);
    if (data == null) return null;
    return UserModel.fromMap(Map<String, dynamic>.from(data));
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final all = _users.values;
    for (final v in all) {
      final map = Map<String, dynamic>.from(v);
      if ((map['email'] ?? '') == email) {
        return UserModel.fromMap(map);
      }
    }
    return null;
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    final users = _users.values
        .map((v) => UserModel.fromMap(Map<String, dynamic>.from(v)))
        .where((user) => user.role == role)
        .toList();
    users.sort((a, b) => a.name.compareTo(b.name));
    return users;
  }

  // -------------------- Tournaments --------------------

  Future<String> createTournament({
    required String name,
    required String location,
    required DateTime date,
    required DateTime registrationStart,
    required DateTime registrationEnd,
    required String creatorId,
    required bool isApproved,
    String imagePath = '',
    required List<CategoryModel> categories,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final tournament = TournamentModel(
      id: id,
      name: name,
      location: location,
      date: date,
      registrationStart: registrationStart,
      registrationEnd: registrationEnd,
      creatorId: creatorId,
      isApproved: isApproved,
      status: isApproved ? 'approved' : 'pending',
      imagePath: imagePath,
      categories: categories,
    );

    await _tournaments.put(id, tournament.toMap());
    return id;
  }

  Future<List<TournamentModel>> getApprovedTournaments() async {
    await purgeExpiredTournaments();
    final list = _tournaments.values
        .map((v) => TournamentModel.fromMap(Map<String, dynamic>.from(v)))
        .where((t) => t.isApproved)
        .toList();

    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<List<TournamentModel>> getTournamentsByStatus(String status) async {
    await purgeExpiredTournaments();
    final list = _tournaments.values
        .map((v) => TournamentModel.fromMap(Map<String, dynamic>.from(v)))
        .where((t) => t.status == status)
        .toList();

    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<List<TournamentModel>> getCreatedTournaments(String creatorId) async {
    await purgeExpiredTournaments();
    final list = _tournaments.values
        .map((v) => TournamentModel.fromMap(Map<String, dynamic>.from(v)))
        .where((t) => t.creatorId == creatorId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<TournamentModel>> getRegisteredTournaments(
    String playerId,
  ) async {
    await purgeExpiredTournaments();
    final list = _tournaments.values
        .map((v) => TournamentModel.fromMap(Map<String, dynamic>.from(v)))
        .where((t) => t.categories.any((c) => c.players.contains(playerId)))
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> purgeExpiredTournaments() async {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final key in _tournaments.keys) {
      final data = _tournaments.get(key);
      if (data == null) continue;
      final tournament = TournamentModel.fromMap(
        Map<String, dynamic>.from(data),
      );
      if (now.isAfter(tournament.date.add(const Duration(days: 5)))) {
        expiredIds.add(key.toString());
      }
    }

    for (final tournamentId in expiredIds) {
      await _tournaments.delete(tournamentId);
      final matchIds = <dynamic>[];
      for (final key in _matches.keys) {
        final data = _matches.get(key);
        if (data == null) continue;
        final match = Map<String, dynamic>.from(data);
        if ((match['tournamentId'] ?? '') == tournamentId) {
          matchIds.add(key);
        }
      }
      for (final matchId in matchIds) {
        await _matches.delete(matchId);
      }
    }
  }

  Future<TournamentModel?> getTournamentById(String tournamentId) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return null;
    return TournamentModel.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> approveTournament({
    required String tournamentId,
    required bool approved,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return;

    final updated = Map<String, dynamic>.from(data);
    updated['isApproved'] = approved;
    updated['status'] = approved ? 'approved' : 'rejected';
    await _tournaments.put(tournamentId, updated);
  }

  Future<void> rejectTournament({required String tournamentId}) async {
    await approveTournament(tournamentId: tournamentId, approved: false);
  }

  Future<void> deleteTournamentByName(String name) async {
    final deleteIds = <dynamic>[];
    for (final key in _tournaments.keys) {
      final data = _tournaments.get(key);
      if (data == null) continue;
      final tournament = TournamentModel.fromMap(
        Map<String, dynamic>.from(data),
      );
      if (tournament.name == name) deleteIds.add(key);
    }

    for (final tournamentId in deleteIds) {
      await _tournaments.delete(tournamentId);
      final matchIds = <dynamic>[];
      for (final key in _matches.keys) {
        final data = _matches.get(key);
        if (data == null) continue;
        final match = Map<String, dynamic>.from(data);
        if ((match['tournamentId'] ?? '') == tournamentId.toString()) {
          matchIds.add(key);
        }
      }
      for (final matchId in matchIds) {
        await _matches.delete(matchId);
      }
    }
  }

  Future<void> updateTournamentCreator({
    required String tournamentId,
    required String creatorId,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return;

    final updated = Map<String, dynamic>.from(data);
    updated['creatorId'] = creatorId;
    await _tournaments.put(tournamentId, updated);
  }

  Future<void> updateTournamentCategories({
    required String tournamentId,
    required List<CategoryModel> categories,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return;

    final updated = Map<String, dynamic>.from(data);
    updated['categories'] = categories.map((c) => c.toMap()).toList();
    await _tournaments.put(tournamentId, updated);
  }

  // -------------------- Matches & scoring --------------------
  // Matches are stored flat with tournamentId included.

  Future<void> createMatch({
    required String tournamentId,
    String categoryName = '',
    String bracket = '',
    int round = 1,
    required String playerA,
    required String playerB,
    required int scoreA,
    required int scoreB,
    required String winner,
    required String umpireId,
    String courtNumber = '',
  }) async {
    final matchId = DateTime.now().microsecondsSinceEpoch.toString();

    final match = MatchModel(
      id: matchId,
      tournamentId: tournamentId,
      categoryName: categoryName,
      bracket: bracket,
      round: round,
      playerA: playerA,
      playerB: playerB,
      scoreA: scoreA,
      scoreB: scoreB,
      winner: winner,
      umpireId: umpireId,
      courtNumber: courtNumber,
      status: winner.isEmpty ? 'scheduled' : 'completed',
    );

    await _matches.put(matchId, match.toMap());
  }

  Future<List<MatchModel>> getMatchesByTournament(String tournamentId) async {
    final results = <MatchModel>[];

    for (final v in _matches.values) {
      final map = Map<String, dynamic>.from(v);
      if ((map['tournamentId'] ?? '') != tournamentId) continue;

      results.add(MatchModel.fromMap(map));
    }

    results.sort((a, b) {
      final category = a.categoryName.compareTo(b.categoryName);
      if (category != 0) return category;
      final bracket = a.bracket.compareTo(b.bracket);
      if (bracket != 0) return bracket;
      final round = a.round.compareTo(b.round);
      if (round != 0) return round;
      return a.id.compareTo(b.id);
    });
    return results;
  }

  Future<List<MatchModel>> getAssignedMatches(String umpireId) async {
    final results = <MatchModel>[];

    for (final v in _matches.values) {
      final map = Map<String, dynamic>.from(v);
      if ((map['umpireId'] ?? '') != umpireId) continue;
      results.add(MatchModel.fromMap(map));
    }

    results.sort((a, b) => a.id.compareTo(b.id));
    return results;
  }

  Future<List<TournamentModel>> getUmpiredTournaments(String umpireId) async {
    await purgeExpiredTournaments();
    final list = <TournamentModel>[];
    for (final v in _tournaments.values) {
      final map = Map<String, dynamic>.from(v);
      final apps = _mutableUmpireApplications(map['umpireApplications']);
      final isAssigned = (map['umpireId'] ?? '') == umpireId;
      final hasApplied = apps.containsKey(umpireId);
      final hasAssignedMatch = _matches.values.any((m) {
        final match = Map<String, dynamic>.from(m);
        return (match['tournamentId'] ?? '') == (map['id'] ?? '') &&
            (match['umpireId'] ?? '') == umpireId;
      });
      if (isAssigned || hasApplied || hasAssignedMatch) {
        list.add(TournamentModel.fromMap(map));
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> scheduleMatch({
    required String tournamentId,
    required String categoryName,
    required String bracket,
    required String playerA,
    required String playerB,
    required String umpireId,
    required String courtNumber,
  }) async {
    await createMatch(
      tournamentId: tournamentId,
      categoryName: categoryName,
      bracket: bracket,
      round: 1,
      playerA: playerA,
      playerB: playerB,
      scoreA: 0,
      scoreB: 0,
      winner: '',
      umpireId: umpireId,
      courtNumber: courtNumber,
    );
  }

  Future<void> updateMatchAssignment({
    required String matchId,
    required String umpireId,
    required String courtNumber,
  }) async {
    final data = _matches.get(matchId);
    if (data == null) return;
    final updated = Map<String, dynamic>.from(data);
    updated['umpireId'] = umpireId;
    updated['courtNumber'] = courtNumber;
    await _matches.put(matchId, updated);
  }

  Future<void> updateScore({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String winner,
  }) async {
    final data = _matches.get(matchId);
    if (data == null) return;

    final updated = Map<String, dynamic>.from(data);
    updated['scoreA'] = scoreA;
    updated['scoreB'] = scoreB;
    updated['winner'] = winner;
    updated['status'] = 'completed';
    await _matches.put(matchId, updated);

    await _advanceWinnersIfRoundComplete(MatchModel.fromMap(updated));
  }

  Future<void> generateBrackets({required String tournamentId}) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) {
      throw Exception('Tournament not found');
    }

    final tournament = TournamentModel.fromMap(Map<String, dynamic>.from(data));
    final umpireId =
        (Map<String, dynamic>.from(data)['umpireId'] ?? '') as String;
    final bracketsByCategory = <String, Map<String, List<String>>>{};

    for (final category in tournament.categories) {
      final groups = <String, List<String>>{
        'A': <String>[],
        'B': <String>[],
        'C': <String>[],
        'D': <String>[],
      };

      if (category.players.isEmpty) {
        bracketsByCategory[category.name] = groups;
        continue;
      }

      final groupSize = (category.players.length / groups.length)
          .ceil()
          .clamp(1, category.players.length)
          .toInt();
      for (var i = 0; i < category.players.length; i++) {
        final bracketIndex = (i / groupSize)
            .floor()
            .clamp(0, groups.length - 1)
            .toInt();
        final bracket = groups.keys.elementAt(bracketIndex);
        groups[bracket]!.add(category.players[i]);
      }

      bracketsByCategory[category.name] = groups;

      for (final entry in groups.entries) {
        await _createRoundMatches(
          tournamentId: tournamentId,
          categoryName: category.name,
          bracket: entry.key,
          round: 1,
          players: entry.value,
          umpireId: umpireId,
        );
      }
    }

    final updated = Map<String, dynamic>.from(data);
    updated['brackets'] = bracketsByCategory;
    await _tournaments.put(tournamentId, updated);
  }

  Future<void> saveBrackets({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) throw Exception('Tournament not found');

    final updated = Map<String, dynamic>.from(data);
    updated['brackets'] = bracketsByCategory;
    await _tournaments.put(tournamentId, updated);
  }

  Future<Map<String, Map<String, List<String>>>> getBrackets(
    String tournamentId,
  ) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return {};

    final raw = (Map<String, dynamic>.from(data)['brackets'] as Map?) ?? {};
    final result = <String, Map<String, List<String>>>{};
    for (final categoryEntry in raw.entries) {
      final brackets = <String, List<String>>{};
      final bracketRaw = Map<String, dynamic>.from(categoryEntry.value as Map);
      for (final bracketEntry in bracketRaw.entries) {
        brackets[bracketEntry.key.toString()] =
            (bracketEntry.value as List?)?.map((e) => e.toString()).toList() ??
            <String>[];
      }
      result[categoryEntry.key.toString()] = brackets;
    }
    return result;
  }

  Future<void> generateRoundRobinGames({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) throw Exception('Tournament not found');
    final umpireId =
        (Map<String, dynamic>.from(data)['umpireId'] ?? '') as String;

    await saveBrackets(
      tournamentId: tournamentId,
      bracketsByCategory: bracketsByCategory,
    );

    for (final categoryEntry in bracketsByCategory.entries) {
      for (final bracketEntry in categoryEntry.value.entries) {
        final players = bracketEntry.value;
        for (var i = 0; i < players.length; i++) {
          for (var j = i + 1; j < players.length; j++) {
            await _createRoundRobinMatch(
              tournamentId: tournamentId,
              categoryName: categoryEntry.key,
              bracket: bracketEntry.key,
              playerA: players[i],
              playerB: players[j],
              umpireId: umpireId,
            );
          }
        }
      }
    }
  }

  Future<void> _createRoundRobinMatch({
    required String tournamentId,
    required String categoryName,
    required String bracket,
    required String playerA,
    required String playerB,
    required String umpireId,
  }) async {
    final duplicate = _matches.values.any((v) {
      final map = Map<String, dynamic>.from(v);
      if ((map['tournamentId'] ?? '') != tournamentId ||
          (map['categoryName'] ?? '') != categoryName ||
          (map['bracket'] ?? '') != bracket ||
          ((map['format'] ?? '') as String) != 'round_robin') {
        return false;
      }

      final existingA = (map['playerA'] ?? '') as String;
      final existingB = (map['playerB'] ?? '') as String;
      return (existingA == playerA && existingB == playerB) ||
          (existingA == playerB && existingB == playerA);
    });
    if (duplicate) return;

    final matchId =
        '${DateTime.now().microsecondsSinceEpoch}_${categoryName}_${bracket}_rr_${playerA.hashCode}_${playerB.hashCode}';
    final match = MatchModel(
      id: matchId,
      tournamentId: tournamentId,
      categoryName: categoryName,
      bracket: bracket,
      round: 1,
      playerA: playerA,
      playerB: playerB,
      scoreA: 0,
      scoreB: 0,
      winner: '',
      umpireId: umpireId,
      courtNumber: '',
      status: 'scheduled',
    ).toMap();
    match['format'] = 'round_robin';
    await _matches.put(matchId, match);
  }

  Future<Map<String, num>> getPlayerStats(String playerId) async {
    var wins = 0;
    var losses = 0;

    for (final v in _matches.values) {
      final match = MatchModel.fromMap(Map<String, dynamic>.from(v));
      if (match.status != 'completed') continue;
      if (match.playerB == 'BYE') continue;
      final played = match.playerA == playerId || match.playerB == playerId;
      if (!played) continue;

      if (match.winner == playerId) {
        wins++;
      } else {
        losses++;
      }
    }

    final total = wins + losses;
    return {
      'wins': wins,
      'losses': losses,
      'winRate': total == 0 ? 0 : wins / total,
    };
  }

  Future<void> _createRoundMatches({
    required String tournamentId,
    required String categoryName,
    required String bracket,
    required int round,
    required List<String> players,
    String umpireId = '',
  }) async {
    for (var i = 0; i < players.length; i += 2) {
      final playerA = players[i];
      final playerB = i + 1 < players.length ? players[i + 1] : 'BYE';
      final winner = playerB == 'BYE' ? playerA : '';
      final status = playerB == 'BYE' ? 'completed' : 'scheduled';

      final duplicate = _matches.values.any((v) {
        final map = Map<String, dynamic>.from(v);
        if ((map['tournamentId'] ?? '') != tournamentId ||
            (map['categoryName'] ?? '') != categoryName ||
            (map['bracket'] ?? '') != bracket ||
            ((map['round'] as num?) ?? 1).toInt() != round) {
          return false;
        }

        final existingA = (map['playerA'] ?? '') as String;
        final existingB = (map['playerB'] ?? '') as String;
        return (existingA == playerA && existingB == playerB) ||
            (existingA == playerB && existingB == playerA);
      });

      if (duplicate) continue;

      final matchId =
          '${DateTime.now().microsecondsSinceEpoch}_${categoryName}_${bracket}_${round}_$i';
      final match = MatchModel(
        id: matchId,
        tournamentId: tournamentId,
        categoryName: categoryName,
        bracket: bracket,
        round: round,
        playerA: playerA,
        playerB: playerB,
        scoreA: 0,
        scoreB: 0,
        winner: winner,
        umpireId: umpireId,
        courtNumber: '',
        status: status,
      );

      await _matches.put(matchId, match.toMap());
    }
  }

  Future<void> _advanceWinnersIfRoundComplete(MatchModel completedMatch) async {
    if (completedMatch.tournamentId.isEmpty ||
        completedMatch.categoryName.isEmpty ||
        completedMatch.bracket.isEmpty) {
      return;
    }

    final currentRound = <MatchModel>[];
    for (final v in _matches.values) {
      final match = MatchModel.fromMap(Map<String, dynamic>.from(v));
      if (match.tournamentId == completedMatch.tournamentId &&
          match.categoryName == completedMatch.categoryName &&
          match.bracket == completedMatch.bracket &&
          match.round == completedMatch.round) {
        currentRound.add(match);
      }
    }

    if (currentRound.isEmpty ||
        currentRound.any((m) => m.status != 'completed' || m.winner.isEmpty)) {
      return;
    }

    final nextRound = completedMatch.round + 1;
    final nextRoundExists = _matches.values.any((v) {
      final match = MatchModel.fromMap(Map<String, dynamic>.from(v));
      return match.tournamentId == completedMatch.tournamentId &&
          match.categoryName == completedMatch.categoryName &&
          match.bracket == completedMatch.bracket &&
          match.round == nextRound;
    });
    if (nextRoundExists) return;

    final winners = currentRound
        .map((m) => m.winner)
        .where((w) => w.isNotEmpty)
        .toList();
    if (winners.length < 2) return;

    await _createRoundMatches(
      tournamentId: completedMatch.tournamentId,
      categoryName: completedMatch.categoryName,
      bracket: completedMatch.bracket,
      round: nextRound,
      players: winners,
      umpireId: completedMatch.umpireId,
    );
  }

  // -------------------- Registrations / umpires (minimal) --------------------
  // For now, the existing UI/provider doesn't rely heavily on these.
  // We'll keep a simple record inside tournament data as nested maps.

  Future<void> registerPlayer({
    required String tournamentId,
    required String playerId,
    required String categoryName,
    Map<String, dynamic>? registrationDetails,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) {
      throw Exception('Tournament not found');
    }

    final map = Map<String, dynamic>.from(data);
    final tournament = TournamentModel.fromMap(map);
    final now = DateTime.now();
    if (now.isBefore(tournament.registrationStart)) {
      throw Exception('Registration has not started yet');
    }
    if (now.isAfter(tournament.registrationEnd)) {
      throw Exception('Registration is closed');
    }
    if (playerId == tournament.creatorId) {
      throw Exception('Tournament creator cannot register in their own event');
    }
    final categoryIndex = tournament.categories.indexWhere(
      (c) => c.name == categoryName,
    );
    if (categoryIndex == -1) {
      throw Exception('Category not found');
    }

    final category = tournament.categories[categoryIndex];
    if (category.players.contains(playerId)) {
      throw Exception('Player is already registered in this category');
    }
    if (category.players.length >= category.slots) {
      throw Exception('Category is full');
    }

    final registrations = _mutableMap(map['registrations']);
    final alreadyRegistered = registrations.values.any((v) {
      final reg = Map<String, dynamic>.from(v as Map);
      return reg['uid'] == playerId && reg['categoryName'] == categoryName;
    });
    if (alreadyRegistered) {
      throw Exception('Player is already registered in this category');
    }

    registrations['$categoryName:$playerId'] = {
      'uid': playerId,
      'categoryName': categoryName,
      'details': registrationDetails ?? <String, dynamic>{},
      'registeredAt': DateTime.now().millisecondsSinceEpoch,
    };

    map['registrations'] = registrations;
    await _tournaments.put(tournamentId, map);

    final updatedCategories = tournament.categories.map((c) {
      if (c.name != categoryName) return c;
      final nextPlayers = List<String>.from(c.players);
      nextPlayers.add(playerId);
      return CategoryModel(
        name: c.name,
        skillLevel: c.skillLevel,
        slots: c.slots,
        players: nextPlayers,
      );
    }).toList();

    await updateTournamentCategories(
      tournamentId: tournamentId,
      categories: updatedCategories,
    );
  }

  Future<void> applyAsUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) {
      throw Exception('Tournament not found');
    }

    final map = Map<String, dynamic>.from(data);
    final user = getUserById(umpireId);
    if (user == null) {
      throw Exception('Only signed-in users can apply');
    }
    if ((map['creatorId'] ?? '') == umpireId) {
      throw Exception('Tournament creator cannot apply as umpire');
    }
    final assignedUmpireId = (map['umpireId'] ?? '').toString();
    if (assignedUmpireId.isNotEmpty) {
      throw Exception('This tournament already has an assigned umpire');
    }

    final apps = _mutableUmpireApplications(map['umpireApplications']);
    final existingStatus = _mutableMap(apps[umpireId])['status']?.toString();
    if (existingStatus == 'pending') {
      throw Exception('Umpire application is already pending');
    }
    if (existingStatus == 'approved') {
      throw Exception('Umpire application is already approved');
    }

    apps[umpireId] = {
      'umpireId': umpireId,
      'status': 'pending',
      'appliedAt': DateTime.now().millisecondsSinceEpoch,
    };

    map['umpireApplications'] = apps;
    await _tournaments.put(tournamentId, map);
  }

  Future<void> rejectUmpireApplication({
    required String tournamentId,
    required String umpireId,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return;

    final map = Map<String, dynamic>.from(data);
    final apps = _mutableUmpireApplications(map['umpireApplications']);
    final app = _mutableMap(apps[umpireId]);
    app['umpireId'] = umpireId;
    app['status'] = 'rejected';
    app['reviewedAt'] = DateTime.now().millisecondsSinceEpoch;
    apps[umpireId] = app;
    map['umpireApplications'] = apps;
    await _tournaments.put(tournamentId, map);
  }

  Future<void> assignUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    final data = _tournaments.get(tournamentId);
    if (data == null) return;

    final map = Map<String, dynamic>.from(data);
    final apps = _mutableUmpireApplications(map['umpireApplications']);
    final app = _mutableMap(apps[umpireId]);
    app['umpireId'] = umpireId;
    app['status'] = 'approved';
    app['reviewedAt'] = DateTime.now().millisecondsSinceEpoch;
    apps[umpireId] = app;
    map['umpireApplications'] = apps;
    map['umpireId'] = umpireId;
    await _tournaments.put(tournamentId, map);

    for (final key in _matches.keys) {
      final data = _matches.get(key);
      if (data == null) continue;
      final match = Map<String, dynamic>.from(data);
      if ((match['tournamentId'] ?? '') != tournamentId) continue;
      if (((match['umpireId'] ?? '') as String).isNotEmpty) continue;

      match['umpireId'] = umpireId;
      await _matches.put(key, match);
    }
  }
}
