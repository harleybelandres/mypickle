import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection('tournaments');
  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ── Tournaments ──────────────────────────────────────────────────────────

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
    final ref = _tournaments.doc();
    final data = TournamentModel(
      id: ref.id,
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
    ).toMap();
    await ref.set(data);
    return ref.id;
  }

  Stream<List<TournamentModel>> getApprovedTournaments() {
    return _tournaments
        .where('status', isEqualTo: 'approved')
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => TournamentModel.fromMap(d.data()))
        .toList());
  }

  Future<List<TournamentModel>> getPendingTournaments() async {
    final snap = await _tournaments
        .where('status', isEqualTo: 'pending')
        .orderBy('date')
        .get();
    return snap.docs.map((d) => TournamentModel.fromMap(d.data())).toList();
  }

  Future<List<TournamentModel>> getCreatedTournaments(String creatorId) async {
    final snap = await _tournaments
        .where('creatorId', isEqualTo: creatorId)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => TournamentModel.fromMap(d.data())).toList();
  }

  Future<List<TournamentModel>> getRegisteredTournaments(
      String playerId) async {
    final snap =
    await _tournaments.where('status', isEqualTo: 'approved').get();
    return snap.docs
        .map((d) => TournamentModel.fromMap(d.data()))
        .where((t) => t.categories.any((c) => c.players.contains(playerId)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<TournamentModel?> getTournamentById(String tournamentId) async {
    final doc = await _tournaments.doc(tournamentId).get();
    if (!doc.exists) return null;
    return TournamentModel.fromMap(doc.data()!);
  }

  Future<void> approveTournament({
    required String tournamentId,
    required bool approved,
  }) async {
    await _tournaments.doc(tournamentId).update({
      'isApproved': approved,
      'status': approved ? 'approved' : 'rejected',
    });
  }

  Future<void> rejectTournament({required String tournamentId}) async {
    await _tournaments.doc(tournamentId).update({
      'isApproved': false,
      'status': 'rejected',
    });
  }

  Future<void> registerPlayer({
    required String tournamentId,
    required String playerId,
    required String categoryName,
    Map<String, dynamic>? registrationDetails,
  }) async {
    final ref = _tournaments.doc(tournamentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Tournament not found');

      final tournament = TournamentModel.fromMap(snap.data()!);
      final now = DateTime.now();

      if (now.isBefore(tournament.registrationStart)) {
        throw Exception('Registration has not started yet');
      }
      if (now.isAfter(tournament.registrationEnd)) {
        throw Exception('Registration is closed');
      }
      if (playerId == tournament.creatorId) {
        throw Exception('Creator cannot register in their own event');
      }

      final catIndex =
      tournament.categories.indexWhere((c) => c.name == categoryName);
      if (catIndex == -1) throw Exception('Category not found');

      final category = tournament.categories[catIndex];
      if (category.players.contains(playerId)) {
        throw Exception('Already registered in this category');
      }
      if (category.players.length >= category.slots) {
        throw Exception('Category is full');
      }

      final updatedCategories = tournament.categories.map((c) {
        if (c.name != categoryName) return c.toMap();
        final players = List<String>.from(c.players)..add(playerId);
        return CategoryModel(
          name: c.name,
          skillLevel: c.skillLevel,
          slots: c.slots,
          players: players,
        ).toMap();
      }).toList();

      tx.update(ref, {
        'categories': updatedCategories,
        'registrations.$categoryName:$playerId': {
          'uid': playerId,
          'categoryName': categoryName,
          'details': registrationDetails ?? {},
          'registeredAt': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  Future<void> applyAsUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _tournaments.doc(tournamentId).update({
      'umpireApplications.$umpireId': {
        'umpireId': umpireId,
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> assignUmpire({
    required String tournamentId,
    required String umpireId,
  }) async {
    final batch = _db.batch();

    batch.update(_tournaments.doc(tournamentId), {
      'umpireId': umpireId,
      'umpireApplications.$umpireId.status': 'approved',
      'umpireApplications.$umpireId.reviewedAt': FieldValue.serverTimestamp(),
    });

    final matchSnap = await _matches
        .where('tournamentId', isEqualTo: tournamentId)
        .where('umpireId', isEqualTo: '')
        .get();
    for (final doc in matchSnap.docs) {
      batch.update(doc.reference, {'umpireId': umpireId});
    }

    await batch.commit();
  }

  Future<void> rejectUmpireApplication({
    required String tournamentId,
    required String umpireId,
  }) async {
    await _tournaments.doc(tournamentId).update({
      'umpireApplications.$umpireId.status': 'rejected',
      'umpireApplications.$umpireId.reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Matches & Bracketing ──────────────────────────────────────────────────

  /// Saves initial batch of matches for a bracket (e.g. Round 1)
  Future<void> saveGeneratedMatches({
    required String tournamentId,
    required String categoryName,
    required List<Map<String, dynamic>> matches,
  }) async {
    final batch = _db.batch();
    for (var matchData in matches) {
      final docRef = _matches.doc();
      batch.set(docRef, {
        ...matchData,
        'id': docRef.id,
        'isFinished': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Automatically moves winner to the correct slot in the next round
  Future<void> advancePlayerToMatch({
    required String tournamentId,
    required String categoryName,
    required int nextRound,
    required int nextMatchIndex,
    required String playerId,
    required bool isSlotA,
  }) async {
    final query = await _matches
        .where('tournamentId', isEqualTo: tournamentId)
        .where('categoryName', isEqualTo: categoryName)
        .where('round', isEqualTo: nextRound)
        .where('bracketIndex', isEqualTo: nextMatchIndex)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        isSlotA ? 'playerAId' : 'playerBId': playerId,
      });
    } else {
      await _matches.add({
        'tournamentId': tournamentId,
        'categoryName': categoryName,
        'round': nextRound,
        'bracketIndex': nextMatchIndex,
        'playerAId': isSlotA ? playerId : 'TBD',
        'playerBId': isSlotA ? 'TBD' : playerId,
        'scoreA': 0,
        'scoreB': 0,
        'isFinished': false,
        'status': 'scheduled',
        'umpireId': '',
        'courtNumber': '',
      });
    }
  }

  Future<String> createMatch({
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
    String format = '',
  }) async {
    final ref = _matches.doc();
    final match = MatchModel(
      id: ref.id,
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
    final data = match.toMap();
    if (format.isNotEmpty) data['format'] = format;
    await ref.set(data);
    return ref.id;
  }

  Future<void> updateScore({
    required String tournamentId,
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String winner,
  }) async {
    await _matches.doc(matchId).update({
      'scoreA': scoreA,
      'scoreB': scoreB,
      'winner': winner,
      'status': 'completed',
      'isFinished': true,
    });
  }

  Future<List<MatchModel>> getMatchesByTournament(String tournamentId) async {
    final snap = await _matches.where('tournamentId', isEqualTo: tournamentId).get();
    return snap.docs.map((d) => MatchModel.fromMap(d.data())).toList()
      ..sort((a, b) {
        if (a.round != b.round) return a.round.compareTo(b.round);
        return a.bracketIndex.compareTo(b.bracketIndex);
      });
  }

  Future<List<MatchModel>> getAssignedMatches(String umpireId) async {
    final snap = await _matches.where('umpireId', isEqualTo: umpireId).get();
    return snap.docs.map((d) => MatchModel.fromMap(d.data())).toList();
  }

  Future<List<TournamentModel>> getUmpiredTournaments(String umpireId) async {
    final snap = await _tournaments.where('umpireId', isEqualTo: umpireId).get();
    final appliedSnap = await _tournaments
        .where('umpireApplications.$umpireId.umpireId', isEqualTo: umpireId)
        .get();
    final ids = <String>{};
    final list = <TournamentModel>[];
    for (final doc in [...snap.docs, ...appliedSnap.docs]) {
      if (ids.add(doc.id)) {
        list.add(TournamentModel.fromMap(doc.data()));
      }
    }
    return list;
  }

  Future<List<UserModel>> getUmpires() async {
    final snap = await _users.where('role', isEqualTo: 'umpire').get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
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
    await _matches.doc(matchId).update({
      'umpireId': umpireId,
      'courtNumber': courtNumber,
    });
  }

  Future<void> saveBrackets({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    await _tournaments.doc(tournamentId).update({'brackets': bracketsByCategory});
  }

  Future<Map<String, Map<String, List<String>>>> getBrackets(
      String tournamentId) async {
    final doc = await _tournaments.doc(tournamentId).get();
    if (!doc.exists) return {};
    final raw = (doc.data()?['brackets'] as Map<String, dynamic>?) ?? {};
    final result = <String, Map<String, List<String>>>{};
    for (final catEntry in raw.entries) {
      final brackets = <String, List<String>>{};
      final bracketRaw = Map<String, dynamic>.from(catEntry.value as Map);
      for (final bEntry in bracketRaw.entries) {
        brackets[bEntry.key] = (bEntry.value as List).map((e) => e.toString()).toList();
      }
      result[catEntry.key] = brackets;
    }
    return result;
  }

  Future<void> generateRoundRobinGames({
    required String tournamentId,
    required Map<String, Map<String, List<String>>> bracketsByCategory,
  }) async {
    await saveBrackets(tournamentId: tournamentId, bracketsByCategory: bracketsByCategory);
    final tDoc = await _tournaments.doc(tournamentId).get();
    final umpireId = (tDoc.data()?['umpireId'] as String?) ?? '';

    final batch = _db.batch();
    for (final catEntry in bracketsByCategory.entries) {
      for (final bktEntry in catEntry.value.entries) {
        final players = bktEntry.value;
        for (var i = 0; i < players.length; i++) {
          for (var j = i + 1; j < players.length; j++) {
            final ref = _matches.doc();
            batch.set(ref, {
              'id': ref.id,
              'tournamentId': tournamentId,
              'categoryName': catEntry.key,
              'bracket': bktEntry.key,
              'playerAId': players[i],
              'playerBId': players[j],
              'scoreA': 0,
              'scoreB': 0,
              'winner': '',
              'status': 'scheduled',
              'format': 'round_robin',
              'round': 1,
              'umpireId': umpireId,
              'isFinished': false,
            });
          }
        }
      }
    }
    await batch.commit();
  }

  /// Fetches comprehensive stats for tie-breaker logic (Wins + Point Differential)
  Future<Map<String, num>> getPlayerStats(String playerId) async {
    final snap = await _matches
        .where('isFinished', isEqualTo: true)
        .get();

    int wins = 0;
    int losses = 0;
    int pointsFor = 0;
    int pointsAgainst = 0;

    for (final doc in snap.docs) {
      final d = doc.data();
      final pA = d['playerAId'] as String;
      final pB = d['playerBId'] as String;
      final sA = d['scoreA'] as int;
      final sB = d['scoreB'] as int;

      if (pA == playerId) {
        pointsFor += sA;
        pointsAgainst += sB;
        if (d['winner'] == playerId) wins++; else losses++;
      } else if (pB == playerId) {
        pointsFor += sB;
        pointsAgainst += sA;
        if (d['winner'] == playerId) wins++; else losses++;
      }
    }

    return {
      'wins': wins,
      'losses': losses,
      'pointsFor': pointsFor,
      'pointsAgainst': pointsAgainst,
      'pointDiff': pointsFor - pointsAgainst,
    };
  }

  // ── Users ──────────────────────────────────────────────────────────────

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<Map<String, UserModel>> getUsersById(List<String> uids) async {
    if (uids.isEmpty) return {};
    final result = <String, UserModel>{};
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
      final snap = await _users.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        result[doc.id] = UserModel.fromMap(doc.data());
      }
    }
    return result;
  }
}