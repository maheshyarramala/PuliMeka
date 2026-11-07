import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class ParamapadhamConfig {
  final bool vsComputer;
  final int playerCount; // 2 or 4
  final Difficulty difficulty;

  const ParamapadhamConfig({
    required this.vsComputer,
    required this.playerCount,
    required this.difficulty,
  });
}

// Traditional Ladders (Virtues that elevate the soul)
const Map<int, int> kLadders = {
  4: 14,
  9: 31,
  20: 38,
  28: 84,
  40: 59,
  51: 67,
  63: 81,
  71: 91,
};

// Traditional Snakes (Vices that pull the soul down)
const Map<int, int> kSnakes = {
  17: 7,
  54: 34,
  62: 19,
  64: 60,
  87: 24,
  93: 73,
  95: 75,
  99: 78,
};

// Converts square 1..100 to grid coordinate (col 0..9, row 0..9)
Offset squareToGrid(int square) {
  if (square < 1) square = 1;
  if (square > 100) square = 100;
  final zeroIndex = square - 1;
  final rowFromBottom = zeroIndex ~/ 10;
  final row = 9 - rowFromBottom;
  final colInRow = zeroIndex % 10;
  // Boustrophedon: even rows from bottom go left-to-right, odd go right-to-left
  final col = (rowFromBottom % 2 == 0) ? colInRow : (9 - colInRow);
  return Offset(col.toDouble(), row.toDouble());
}

class ParamapadhamPlayer {
  final int id;
  final String name;
  final Color color;
  int square; // 0 = not started, 1..100 = on board

  ParamapadhamPlayer({
    required this.id,
    required this.name,
    required this.color,
  }) : square = 1;

  bool get hasReachedMoksha => square >= 100;
}

class ParamapadhamGame {
  final ParamapadhamConfig config;
  final List<ParamapadhamPlayer> players;
  final Random rng = Random();
  int currentTurn = 0;
  int? lastDice;
  bool awaitingRoll = true;
  String? eventNotice;
  int? winner;

  ParamapadhamGame(this.config)
      : players = _buildPlayers(config.playerCount);

  static List<ParamapadhamPlayer> _buildPlayers(int count) {
    if (count == 2) {
      return [
        ParamapadhamPlayer(id: 0, name: 'Red', color: const Color(0xFFE53935)),
        ParamapadhamPlayer(id: 1, name: 'Gold', color: const Color(0xFFFFD54F)),
      ];
    }
    return [
      ParamapadhamPlayer(id: 0, name: 'Red', color: const Color(0xFFE53935)),
      ParamapadhamPlayer(id: 1, name: 'Jade', color: const Color(0xFF10B981)),
      ParamapadhamPlayer(id: 2, name: 'Gold', color: const Color(0xFFFFD54F)),
      ParamapadhamPlayer(id: 3, name: 'Blue', color: const Color(0xFF1E88E5)),
    ];
  }

  ParamapadhamPlayer get currentPlayer => players[currentTurn];

  int roll() {
    final d = rng.nextInt(6) + 1;
    lastDice = d;
    awaitingRoll = false;
    eventNotice = null;

    final p = currentPlayer;
    int target = p.square + d;

    // Must land with exact roll to reach 100 (Moksha)
    if (target > 100) {
      eventNotice = "Overshot 100! Need exact roll.";
      if (d == 6) {
        awaitingRoll = true;
      } else {
        _advanceTurn();
      }
      return d;
    }

    p.square = target;

    // Check Ladder
    if (kLadders.containsKey(target)) {
      final dest = kLadders[target]!;
      p.square = dest;
      eventNotice = "Climbed Virtue Ladder to $dest! 🪜";
    }
    // Check Snake
    else if (kSnakes.containsKey(target)) {
      final dest = kSnakes[target]!;
      p.square = dest;
      eventNotice = "Bitten by Vice Snake down to $dest! 🐍";
    }

    if (p.hasReachedMoksha) {
      winner = p.id;
      return d;
    }

    // Extra roll on 6
    if (d == 6) {
      awaitingRoll = true;
      eventNotice = (eventNotice != null) ? "$eventNotice (Rolled 6: Extra roll!)" : "Rolled 6: Bonus roll!";
    } else {
      _advanceTurn();
    }
    return d;
  }

  void _advanceTurn() {
    awaitingRoll = true;
    currentTurn = (currentTurn + 1) % players.length;
  }
}

class ParamapadhamPainter extends CustomPainter {
  final ParamapadhamGame game;

  ParamapadhamPainter({required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 10.0;

    Offset cellCenter(int square) {
      final grid = squareToGrid(square);
      return Offset((grid.dx + 0.5) * cellSize, (grid.dy + 0.5) * cellSize);
    }

    // 1. Draw 100 Tiles with subtle checkerboard cloth colors
    for (int sq = 1; sq <= 100; sq++) {
      final grid = squareToGrid(sq);
      final rect = Rect.fromLTWH(grid.dx * cellSize, grid.dy * cellSize, cellSize, cellSize);

      final isEven = (grid.dx.toInt() + grid.dy.toInt()) % 2 == 0;
      final tileColor = (sq == 100)
          ? const Color(0xFFFFD54F)
          : (isEven ? const Color(0xFFF7EBD2) : const Color(0xFFECD5A5));

      canvas.drawRect(rect, Paint()..color = tileColor);
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF8B6B4A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Number Label
      final tp = TextPainter(
        text: TextSpan(
          text: '$sq',
          style: TextStyle(
            color: (sq == 100) ? const Color(0xFF3B2A1A) : const Color(0xFF6B4C28),
            fontSize: cellSize * 0.28,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + 3, rect.top + 2));
    }

    // 2. Draw Ladders (Green/Gold Rails with Rungs)
    final railPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rungPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 2.0;

    for (final entry in kLadders.entries) {
      final start = cellCenter(entry.key);
      final end = cellCenter(entry.value);

      final diff = end - start;
      final normal = Offset(-diff.dy, diff.dx) / diff.distance * (cellSize * 0.18);

      final leftStart = start + normal;
      final leftEnd = end + normal;
      final rightStart = start - normal;
      final rightEnd = end - normal;

      canvas.drawLine(leftStart, leftEnd, railPaint);
      canvas.drawLine(rightStart, rightEnd, railPaint);

      const rungsCount = 6;
      for (int i = 1; i <= rungsCount; i++) {
        final t = i / (rungsCount + 1);
        final p1 = Offset.lerp(leftStart, leftEnd, t)!;
        final p2 = Offset.lerp(rightStart, rightEnd, t)!;
        canvas.drawLine(p1, p2, rungPaint);
      }
    }

    // 3. Draw Snakes (Curved Serpentine Bodies with Head & Eyes)
    final snakeBodyPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    for (final entry in kSnakes.entries) {
      final head = cellCenter(entry.key);
      final tail = cellCenter(entry.value);

      final mid = (head + tail) / 2;
      final offset = Offset(sin(head.dx) * (cellSize * 0.4), cos(head.dy) * (cellSize * 0.4));

      final path = Path();
      path.moveTo(head.dx, head.dy);
      path.quadraticBezierTo(mid.dx + offset.dx, mid.dy + offset.dy, tail.dx, tail.dy);
      canvas.drawPath(path, snakeBodyPaint);

      canvas.drawCircle(head, cellSize * 0.22, Paint()..color = const Color(0xFFB71C1C));
      canvas.drawCircle(head + const Offset(-2, -2), 1.8, Paint()..color = Colors.white);
      canvas.drawCircle(head + const Offset(2, -2), 1.8, Paint()..color = Colors.white);
    }

    // 4. Draw Player Pawns
    final Map<int, List<ParamapadhamPlayer>> pawnsOnSq = {};
    for (final p in game.players) {
      pawnsOnSq.putIfAbsent(p.square, () => []).add(p);
    }

    for (final entry in pawnsOnSq.entries) {
      final sq = entry.key;
      final list = entry.value;
      final center = cellCenter(sq);

      for (int i = 0; i < list.length; i++) {
        final p = list[i];
        final shift = (list.length > 1)
            ? Offset((i - (list.length - 1) / 2) * (cellSize * 0.24), 0)
            : Offset.zero;

        final pawnCenter = center + shift;
        final radius = cellSize * 0.26;

        canvas.drawCircle(pawnCenter + const Offset(1, 2), radius, Paint()..color = const Color(0x66000000));
        canvas.drawCircle(pawnCenter, radius, Paint()..color = p.color);
        canvas.drawCircle(
          pawnCenter,
          radius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParamapadhamPainter oldDelegate) => true;
}

class ParamapadhamScreen extends StatefulWidget {
  final ParamapadhamConfig config;
  const ParamapadhamScreen({super.key, required this.config});

  @override
  State<ParamapadhamScreen> createState() => _ParamapadhamScreenState();
}

class _ParamapadhamScreenState extends State<ParamapadhamScreen> {
  late ParamapadhamGame game;
  bool _thinking = false;
  int _gen = 0;

  ParamapadhamConfig get config => widget.config;

  bool get isComputerTurn =>
      config.vsComputer && game.winner == null && game.currentTurn != 0;

  @override
  void initState() {
    super.initState();
    game = ParamapadhamGame(config);
  }

  void restart() {
    _gen++;
    _thinking = false;
    setState(() {
      game = ParamapadhamGame(config);
    });
  }

  void _roll() {
    if (!game.awaitingRoll || game.winner != null || isComputerTurn) return;
    Haptics.medium();
    Sound.play(Sfx.select);

    setState(() {
      final d = game.roll();
      if (game.eventNotice?.contains('Ladder') == true) {
        Sound.play(Sfx.win);
        Haptics.heavy();
      } else if (game.eventNotice?.contains('Snake') == true) {
        Sound.play(Sfx.lose);
        Haptics.heavy();
      } else {
        Sound.play(Sfx.move);
        Haptics.light();
      }
    });

    _maybeComputerMove();
  }

  void _maybeComputerMove() {
    if (!isComputerTurn || _thinking || game.winner != null) return;
    _thinking = true;
    final token = _gen;

    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || token != _gen) return;

      setState(() {
        final d = game.roll();
        if (game.eventNotice?.contains('Ladder') == true) {
          Sound.play(Sfx.win);
        } else if (game.eventNotice?.contains('Snake') == true) {
          Sound.play(Sfx.lose);
        } else {
          Sound.play(Sfx.move);
        }
        _thinking = false;
      });

      if (game.winner != null) {
        final humanWon = !config.vsComputer || game.winner == 0;
        Sound.play(humanWon ? Sfx.win : Sfx.lose);
        Haptics.heavy();
        return;
      }

      _maybeComputerMove();
    });
  }

  String get statusText {
    final w = game.winner;
    if (w != null) {
      final winnerPlayer = game.players.firstWhere((p) => p.id == w);
      if (config.vsComputer) {
        return w == 0 ? 'You reached Moksha (Heaven)!' : '${winnerPlayer.name} won the race!';
      }
      return '${winnerPlayer.name} reached Moksha!';
    }
    if (isComputerTurn) {
      final cur = game.currentPlayer;
      return '${cur.name} (Computer) is rolling…';
    }
    final cur = game.currentPlayer;
    final who = (config.vsComputer && cur.id == 0) ? 'Your turn (Red)' : "${cur.name}'s turn";
    if (game.eventNotice != null) {
      return '$who: ${game.eventNotice!}';
    }
    return '$who: roll the die to advance';
  }

  Widget boardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight) * 0.95;
        return Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: ParamapadhamPainter(game: game),
            ),
          ),
        );
      },
    );
  }

  Widget dicePanel() {
    final cur = game.currentPlayer;
    final d = game.lastDice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1F12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cur.color, width: 2.2),
        boxShadow: [
          BoxShadow(color: cur.color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cur.color, width: 2),
            ),
            child: Center(
              child: Text(
                d != null ? '$d' : '-',
                style: TextStyle(color: cur.color, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: (!isComputerTurn && game.winner == null) ? _roll : null,
                style: FilledButton.styleFrom(
                  backgroundColor: cur.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.casino, size: 22),
                label: Text(
                  "${cur.name.toUpperCase()} • ROLL DIE",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = game.currentPlayer;

    return GameFrame(
      title: 'Paramapadham',
      status: statusText,
      counters: [
        statCounter('LAST ROLL', game.lastDice != null ? '${game.lastDice}' : '-'),
        statCounter('POSITION', '${cur.square}/100'),
        statCounter('GOAL', 'Square 100'),
      ],
      board: Column(
        children: [
          Expanded(child: boardArea()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: dicePanel(),
          ),
        ],
      ),
      endButtons: endButtonsRow(
        context,
        show: game.winner != null,
        onPlayAgain: restart,
      ),
      onRestart: restart,
    );
  }
}
