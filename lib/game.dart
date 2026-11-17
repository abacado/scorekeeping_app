enum PlayerColor {
  red,
  blue,
  green,
  yellow,
  redPlow,
  bluePump,
  greenPail,
  yellowCarriage,
  orangeHat,
  navyWheelbarrow,
  pinkWateringCan,
  purpleButterChurn;

  static PlayerColor fromSavedName(String name) => switch (name) {
    'coral' => redPlow,
    'skyBlue' => bluePump,
    'mint' => greenPail,
    'gold' => yellowCarriage,
    _ => values.byName(name),
  };
}

class RoundScore {
  const RoundScore.direct(int points)
    : directPoints = points,
      played = null,
      blitzLeft = null;

  const RoundScore.calculated({
    required int cardsPlayed,
    required int blitzCardsLeft,
  }) : directPoints = null,
       played = cardsPlayed,
       blitzLeft = blitzCardsLeft;

  final int? directPoints;
  final int? played;
  final int? blitzLeft;

  int get points => directPoints ?? (played! - 2 * blitzLeft!);

  Map<String, int> toJson() => switch (directPoints) {
    final points? => {'points': points},
    null => {'played': played!, 'blitzLeft': blitzLeft!},
  };

  factory RoundScore.fromJson(Map<String, dynamic> json) {
    final points = json['points'];
    if (points is int) return RoundScore.direct(points);
    return RoundScore.calculated(
      cardsPlayed: json['played'] as int,
      blitzCardsLeft: json['blitzLeft'] as int,
    );
  }
}

class Game {
  Game({
    required List<String> players,
    required this.target,
    List<PlayerColor>? playerColors,
    List<List<RoundScore>> rounds = const [],
  }) : players = List.unmodifiable(players),
       playerColors = List.unmodifiable(
         playerColors ?? PlayerColor.values.take(players.length),
       ),
       rounds = List.unmodifiable(rounds.map(List<RoundScore>.unmodifiable));

  static const standardTarget = 75;
  final List<String> players;
  final List<PlayerColor> playerColors;
  final int target;
  final List<List<RoundScore>> rounds;

  List<int> get totals {
    final totals = List<int>.filled(players.length, 0);
    for (final round in rounds) {
      for (var player = 0; player < players.length; player++) {
        totals[player] += round[player].points;
      }
    }
    return totals;
  }

  List<int> get standings {
    final scores = totals;
    return List.generate(players.length, (index) => index)..sort((a, b) {
      final byScore = scores[b].compareTo(scores[a]);
      return byScore == 0 ? a.compareTo(b) : byScore;
    });
  }

  List<int> get leadersAtTarget {
    final scores = totals;
    final highest = scores.reduce((a, b) => a > b ? a : b);
    if (highest < target) return [];
    return [
      for (var i = 0; i < scores.length; i++)
        if (scores[i] == highest) i,
    ];
  }

  int? get winner {
    final leaders = leadersAtTarget;
    return leaders.length == 1 ? leaders.single : null;
  }

  Game saveRound(List<RoundScore> scores, {int? index}) {
    final updated = [...rounds];
    if (index == null) {
      updated.add(scores);
    } else {
      updated[index] = scores;
    }
    return Game(
      players: players,
      playerColors: playerColors,
      target: target,
      rounds: updated,
    );
  }

  Map<String, dynamic> toJson() => {
    'players': players,
    'playerColors': [for (final color in playerColors) color.name],
    'target': target,
    'rounds': [
      for (final round in rounds) [for (final score in round) score.toJson()],
    ],
  };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    players: List<String>.from(json['players'] as List),
    target: json['target'] as int,
    playerColors: (json['playerColors'] as List?)
        ?.map((name) => PlayerColor.fromSavedName(name as String))
        .toList(),
    rounds: [
      for (final round in json['rounds'] as List)
        [
          for (final score in round as List)
            RoundScore.fromJson(score as Map<String, dynamic>),
        ],
    ],
  );
}
