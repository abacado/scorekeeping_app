import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

const _navy = Color(0xFF202740);
const _paper = Color(0xFFFFFAF0);
const _green = Color(0xFF216749);
const _deckColors = {
  PlayerColor.red: (label: 'Red carriage', swatch: Color(0xFFB93639)),
  PlayerColor.blue: (label: 'Blue plow', swatch: Color(0xFF245B9D)),
  PlayerColor.green: (label: 'Green pump', swatch: _green),
  PlayerColor.yellow: (label: 'Yellow pail', swatch: Color(0xFFF3CA52)),
  PlayerColor.redPlow: (label: 'Red plow', swatch: Color(0xFFB93639)),
  PlayerColor.bluePump: (label: 'Blue pump', swatch: Color(0xFF245B9D)),
  PlayerColor.greenPail: (label: 'Green pail', swatch: _green),
  PlayerColor.yellowCarriage: (
    label: 'Yellow carriage',
    swatch: Color(0xFFF3CA52),
  ),
  PlayerColor.orangeHat: (label: 'Orange hat', swatch: Color(0xFFF58A2C)),
  PlayerColor.navyWheelbarrow: (
    label: 'Navy wheelbarrow',
    swatch: Color(0xFF20365B),
  ),
  PlayerColor.pinkWateringCan: (
    label: 'Pink watering can',
    swatch: Color(0xFFEB86B2),
  ),
  PlayerColor.purpleButterChurn: (
    label: 'Purple butter churn',
    swatch: Color(0xFF723D9D),
  ),
};

void main() => runApp(const ScorekeeperApp());

class ScorekeeperApp extends StatelessWidget {
  const ScorekeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dutch Blitz Scorekeeper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          onSurface: _navy,
          surface: _paper,
        ),
        scaffoldBackgroundColor: _paper,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
        ),
      ),
      home: const Scorekeeper(),
    );
  }
}

class Scorekeeper extends StatefulWidget {
  const Scorekeeper({super.key});

  @override
  State<Scorekeeper> createState() => _ScorekeeperState();
}

class _ScorekeeperState extends State<Scorekeeper> {
  static const _storageKey = 'dutch_blitz_game_v1';
  Game? _game;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restoreGame();
  }

  Future<void> _restoreGame() async {
    Game? restored;
    var failed = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_storageKey);
      if (saved != null) {
        restored = Game.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _game = restored;
      _loading = false;
    });
    if (failed) _showMessage('Could not restore the saved game.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveGame(Game game) async {
    if (_saving) return;
    setState(() {
      _game = game;
      _saving = true;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _storageKey,
        jsonEncode(game.toJson()),
      );
      if (!saved && mounted) _showMessage('Could not save to this device.');
    } catch (_) {
      if (mounted) _showMessage('Could not save to this device.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _newGame() async {
    final game = await Navigator.of(context)
        .push<Game>(MaterialPageRoute(builder: (_) => const SetupScreen()));
    if (mounted && game != null) await _saveGame(game);
  }

  Future<void> _enterRound(Game game, {int? index}) async {
    final scores = await Navigator.of(context).push<List<RoundScore>>(
      MaterialPageRoute(
        builder: (_) => RoundScreen(
          players: game.players,
          playerColors: game.playerColors,
          number: (index ?? game.rounds.length) + 1,
          existing: index == null ? null : game.rounds[index],
        ),
      ),
    );
    if (mounted && scores != null) {
      await _saveGame(game.saveRound(scores, index: index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (game == null) return SetupScreen(onStart: _saveGame);

    final scores = game.totals;
    final winner = game.winner;
    final leaders = game.leadersAtTarget;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dutch Blitz'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _newGame,
            child: const Text('New game'),
          ),
        ],
      ),
      body: PageContent(
        children: [
          const DeckStripe(),
          const SizedBox(height: 24),
          Text(
            winner == null ? 'Scoreboard' : '${game.players[winner]} wins!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Target: ${game.target} points · ${game.rounds.length} rounds played',
          ),
          if (leaders.length > 1) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDAF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${leaders.map((i) => game.players[i]).join(', ')} '
                    'are tied for first at ${scores[leaders.first]} points. '
                    'Play another round to break the tie.',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final i in game.standings)
            Card(
              color: Colors.white,
              child: ListTile(
                leading: PlayerBadge(index: i, color: game.playerColors[i]),
                title: Text(game.players[i]),
                subtitle: Text(_deckColors[game.playerColors[i]]!.label),
                trailing: Text(
                  '${scores[i]}',
                  style: Theme.of(context).textTheme.titleLarge,
                  semanticsLabel: '${scores[i]} points',
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving
                ? null
                : winner == null
                ? () => _enterRound(game)
                : () => _saveGame(
                    Game(
                      players: game.players,
                      playerColors: game.playerColors,
                      target: game.target,
                    ),
                  ),
            child: Text(winner == null ? 'Add round' : 'Rematch'),
          ),
          if (game.rounds.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Round history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (var i = game.rounds.length - 1; i >= 0; i--)
              Card(
                color: Colors.white,
                child: ListTile(
                  title: Text('Round ${i + 1}'),
                  subtitle: Text(
                    [
                      for (
                        var player = 0;
                        player < game.players.length;
                        player++
                      )
                        '${game.players[player]}: ${game.rounds[i][player].points}',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _saving ? null : () => _enterRound(game, index: i),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.onStart});

  final ValueChanged<Game>? onStart;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _names = List.generate(8, (_) => TextEditingController());
  final _target = TextEditingController();
  final _colors = PlayerColor.values.toList();
  int _count = 2;
  bool _custom = false;

  @override
  void dispose() {
    for (final name in _names) {
      name.dispose();
    }
    _target.dispose();
    super.dispose();
  }

  void _start() {
    if (!_formKey.currentState!.validate()) return;
    final game = Game(
      players: [for (final name in _names.take(_count)) name.text.trim()],
      playerColors: _colors.take(_count).toList(),
      target: _custom ? int.parse(_target.text.trim()) : Game.standardTarget,
    );
    final onStart = widget.onStart;
    if (onStart == null) {
      Navigator.of(context).pop(game);
    } else {
      onStart(game);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dutch Blitz')),
      body: Form(
        key: _formKey,
        child: PageContent(
          children: [
            const DeckStripe(),
            const SizedBox(height: 24),
            Text('New game', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _count,
              decoration: const InputDecoration(labelText: 'Number of players'),
              items: [
                for (var i = 2; i <= 8; i++)
                  DropdownMenuItem(value: i, child: Text('$i players')),
              ],
              onChanged: (count) => setState(() => _count = count!),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _names[i],
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Player ${i + 1} name',
                    suffixIcon: PopupMenuButton<PlayerColor>(
                      tooltip:
                          'Player ${i + 1} color: ${_deckColors[_colors[i]]!.label}',
                      icon: const Icon(Icons.palette_outlined),
                      initialValue: _colors[i],
                      onSelected: (color) => setState(() => _colors[i] = color),
                      itemBuilder: (context) => [
                        for (final entry in _deckColors.entries)
                          PopupMenuItem(
                            value: entry.key,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 10,
                                backgroundColor: entry.value.swatch,
                              ),
                              title: Text(entry.value.label),
                            ),
                          ),
                      ],
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8),
                      child: PlayerBadge(index: i, color: _colors[i]),
                    ),
                  ),
                  validator: (text) => text == null || text.trim().isEmpty
                      ? 'Enter a name'
                      : null,
                ),
              ),
            const SizedBox(height: 8),
            Text('Game target', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Standard · 75')),
                ButtonSegment(value: true, label: Text('Custom')),
              ],
              selected: {_custom},
              onSelectionChanged: (selection) =>
                  setState(() => _custom = selection.single),
            ),
            if (_custom) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Points to win'),
                validator: (text) {
                  final points = int.tryParse(text?.trim() ?? '');
                  return points == null || points <= 0
                      ? 'Enter a positive whole number'
                      : null;
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _start, child: const Text('Start game')),
          ],
        ),
      ),
    );
  }
}

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class DeckStripe extends StatelessWidget {
  const DeckStripe({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          for (final color in PlayerColor.values.take(4))
            Expanded(
              child: ColoredBox(
                color: _deckColors[color]!.swatch,
                child: const SizedBox(height: 8),
              ),
            ),
        ],
      ),
    );
  }
}

class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.index, required this.color});

  final int index;
  final PlayerColor color;

  @override
  Widget build(BuildContext context) {
    final swatch = _deckColors[color]!.swatch;
    return CircleAvatar(
      radius: 16,
      backgroundColor: swatch,
      foregroundColor: swatch.computeLuminance() > 0.35 ? _navy : Colors.white,
      child: Text('${index + 1}'),
    );
  }
}

class RoundScreen extends StatefulWidget {
  const RoundScreen({
    super.key,
    required this.players,
    required this.playerColors,
    required this.number,
    this.existing,
  });

  final List<String> players;
  final List<PlayerColor> playerColors;
  final int number;
  final List<RoundScore>? existing;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  final _formKey = GlobalKey<FormState>();
  late final List<bool> _calculate;
  late final List<TextEditingController> _points;
  late final List<TextEditingController> _played;
  late final List<TextEditingController> _left;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final count = widget.players.length;
    _calculate = List.generate(count, (i) => existing?[i].played != null);
    _points = List.generate(
      count,
      (i) => TextEditingController(text: existing?[i].directPoints?.toString()),
    );
    _played = List.generate(
      count,
      (i) => TextEditingController(text: existing?[i].played?.toString()),
    );
    _left = List.generate(
      count,
      (i) => TextEditingController(text: existing?[i].blitzLeft?.toString()),
    );
  }

  @override
  void dispose() {
    for (final controller in [..._points, ..._played, ..._left]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop([
      for (var i = 0; i < widget.players.length; i++)
        if (_calculate[i])
          RoundScore.calculated(
            cardsPlayed: int.parse(_played[i].text.trim()),
            blitzCardsLeft: int.parse(_left[i].text.trim()),
          )
        else
          RoundScore.direct(int.parse(_points[i].text.trim())),
    ]);
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    int? max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(signed: max == null),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      onChanged: max == null ? null : (_) => setState(() {}),
      validator: (text) {
        final value = int.tryParse(text?.trim() ?? '');
        if (value == null) return 'Enter a whole number';
        if (max != null && (value < 0 || value > max)) {
          return 'Enter 0 to $max';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'Round ${widget.number}'
              : 'Edit round ${widget.number}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageContent(
          children: [
            for (var i = 0; i < widget.players.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _playerEntry(i),
              ),
            FilledButton(onPressed: _save, child: const Text('Save round')),
          ],
        ),
      ),
    );
  }

  Widget _playerEntry(int index) {
    final played = int.tryParse(_played[index].text.trim());
    final left = int.tryParse(_left[index].text.trim());
    final preview =
        played != null &&
            played >= 0 &&
            played <= 40 &&
            left != null &&
            left >= 0 &&
            left <= 10
        ? RoundScore.calculated(
            cardsPlayed: played,
            blitzCardsLeft: left,
          ).points
        : null;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PlayerBadge(index: index, color: widget.playerColors[index]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.players[index],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(_deckColors[widget.playerColors[index]]!.label),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Enter score')),
                ButtonSegment(value: true, label: Text('Calculate')),
              ],
              selected: {_calculate[index]},
              onSelectionChanged: (selection) =>
                  setState(() => _calculate[index] = selection.single),
            ),
            const SizedBox(height: 12),
            if (_calculate[index]) ...[
              _numberField(_played[index], 'Cards played', max: 40),
              const SizedBox(height: 12),
              _numberField(_left[index], 'Blitz cards left', max: 10),
              const SizedBox(height: 8),
              Text(
                preview == null
                    ? 'Cards played − (2 × Blitz cards left)'
                    : 'Round score: $preview',
              ),
            ] else
              _numberField(_points[index], 'Round points'),
          ],
        ),
      ),
    );
  }
}
