class MatchModel {
  final String id;
  final String tournamentId;
  final String categoryName;
  final String bracket;
  final int round;
  final String playerA;
  final String playerB;
  final int scoreA;
  final int scoreB;
  final String winner;
  final String umpireId;
  final String courtNumber;
  final String status;

  // For the Bracket Logic (added safely)
  final int bracketIndex;
  final bool isFinished;

  const MatchModel({
    required this.id,
    this.tournamentId = '',
    this.categoryName = '',
    this.bracket = '',
    this.round = 1,
    this.bracketIndex = 0, // Default to 0
    required this.playerA,
    required this.playerB,
    required this.scoreA,
    required this.scoreB,
    required this.winner,
    required this.umpireId,
    this.courtNumber = '',
    this.status = 'scheduled',
    this.isFinished = false, // Default to false
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tournamentId': tournamentId,
    'categoryName': categoryName,
    'bracket': bracket,
    'round': round,
    'bracketIndex': bracketIndex,
    'playerA': playerA,
    'playerB': playerB,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'winner': winner,
    'umpireId': umpireId,
    'courtNumber': courtNumber,
    'status': status,
    'isFinished': isFinished,
  };

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: (map['id'] ?? map['matchId'] ?? '') as String,
      tournamentId: (map['tournamentId'] ?? '') as String,
      categoryName: (map['categoryName'] ?? '') as String,
      bracket: (map['bracket'] ?? '') as String,
      round: ((map['round'] as num?) ?? 1).toInt(),
      bracketIndex: ((map['bracketIndex'] as num?) ?? 0).toInt(),
      // This part handles both the old 'playerA' and the new 'playerAId' names
      playerA: (map['playerA'] ?? map['playerAId'] ?? map['player1'] ?? 'TBD') as String,
      playerB: (map['playerB'] ?? map['playerBId'] ?? map['player2'] ?? 'TBD') as String,
      scoreA: ((map['scoreA'] ?? map['score1']) as num?)?.toInt() ?? 0,
      scoreB: ((map['scoreB'] ?? map['score2']) as num?)?.toInt() ?? 0,
      winner: (map['winner'] as String?) ?? '',
      umpireId: (map['umpireId'] as String?) ?? '',
      courtNumber: (map['courtNumber'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'scheduled',
      isFinished: (map['isFinished'] as bool?) ?? (map['status'] == 'completed'),
    );
  }
}