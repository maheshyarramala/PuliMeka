import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class PallanguzhiConfig {
  final bool vsComputer;
  final int humanPlayer; // 1 = South, 2 = North
  final Difficulty difficulty;

  const PallanguzhiConfig({
    required this.vsComputer,
    required this.humanPlayer,
    required this.difficulty,
  });
}

class PallanguzhiGame {
  final PallanguzhiConfig config;
  final List<int> pits; // 14 pits: 0..6 (Player 1 South), 7..13 (Player 2 North)
  final List<int> store; // Captured seeds: [P1, P2]
  int turn; // 1 or 2
  int? winner;

  PallanguzhiGame(this.config)
      : pits = List.filled(14, 5), // 5 seeds per pit = 70 seeds total
        store = [0, 0],
        turn = 1,
        winner = null;

  int get opponent => (turn == 1) ? 2 : 1;

  List<int> playablePits() {
    if (winner != null) return [];
    final start = (turn == 1) ? 0 : 7;
    final end = (turn == 1) ? 6 : 13;
    final list = <int>[];
    for (int i = start; i <= end; i++) {
      if (pits[i] > 0) list.add(i);
    }
    return list;
  }

  // Sows seeds counter-clockwise starting from [pitIndex]. Returns seeds captured.
  int sow(int pitIndex) {
    if (!playablePits().contains(pitIndex)) return 0;

    int hand = pits[pitIndex];
    pits[pitIndex] = 0;
    int curr = pitIndex;
    int capturedTotal = 0;

    while (hand > 0) {
      // Sow 1 seed per pit
      curr = (curr + 1) % 14;
      pits[curr]++;
      hand--;

      // When hand runs out:
      if (hand == 0) {
        final next = (curr + 1) % 14;
        // If next pit has seeds, pick them up and continue sowing!
        if (pits[next] > 0) {
          hand = pits[next];
          pits[next] = 0;
          curr = next;
        } else {
          // Next pit is EMPTY -> Capture the pit following it!
          final harvestPit = (next + 1) % 14;
          if (pits[harvestPit] > 0) {
            final harvest = pits[harvestPit];
            pits[harvestPit] = 0;
            store[turn - 1] += harvest;
            capturedTotal += harvest;

            // Check for double capture (Thodu) if pit following harvest is also empty
            final nextEmpty = (harvestPit + 1) % 14;
            if (pits[nextEmpty] == 0) {
              final secondHarvest = (nextEmpty + 1) % 14;
              if (pits[secondHarvest] > 0) {
                final h2 = pits[secondHarvest];
                pits[secondHarvest] = 0;
                store[turn - 1] += h2;
                capturedTotal += h2;
              }
            }
          }
          break; // Turn ends
        }
      }
    }

    _advanceTurn();
    return capturedTotal;
  }

  void _advanceTurn() {
    turn = opponent;
    // Check if game is over (no playable pits for current player)
    if (playablePits().isEmpty) {
      // Remaining seeds go to their respective side
      for (int i = 0; i < 7; i++) {
        store[0] += pits[i];
        pits[i] = 0;
      }
      for (int i = 7; i < 14; i++) {
        store[1] += pits[i];
        pits[i] = 0;
      }

      if (store[0] > store[1]) {
        winner = 1;
      } else if (store[1] > store[0]) {
        winner = 2;
      } else {
        winner = 0; // Draw
      }
    }
  }
}

class PallanguzhiAI {
  final Difficulty difficulty;
  final Random _rng = Random();

  PallanguzhiAI({required this.difficulty});

  int? pickPit(PallanguzhiGame g) {
    final playable = g.playablePits();
    if (playable.isEmpty) return null;
    if (playable.length == 1) return playable.first;

    if (difficulty == Difficulty.easy && _rng.nextDouble() < 0.45) {
      return playable[_rng.nextInt(playable.length)];
    }

    int bestPit = playable.first;
    int maxCapture = -1;

    // Simulate each playable pit to find the one yielding maximum captures
    for (final pit in playable) {
      final sim = PallanguzhiGame(g.config);
      for (int i = 0; i < 14; i++) {
        sim.pits[i] = g.pits[i];
      }
      sim.store[0] = g.store[0];
      sim.store[1] = g.store[1];
      sim.turn = g.turn;

      final captured = sim.sow(pit);
      if (captured > maxCapture) {
        maxCapture = captured;
        bestPit = pit;
      }
    }
    return bestPit;
  }
}

class PallanguzhiPainter extends CustomPainter {
  final PallanguzhiGame game;

  PallanguzhiPainter({required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Wooden Board Base
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );
    final woodPaint = Paint()..color = const Color(0xFF4A321F);
    canvas.drawRRect(boardRect, woodPaint);
    canvas.drawRRect(
      boardRect,
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 2. Compute 14 Pit Centers (2 rows of 7)
    final colWidth = size.width / 7.0;
    final rowHeight = size.height / 2.0;
    final pitRadiusW = colWidth * 0.40;
    final pitRadiusH = rowHeight * 0.38;

    final playable = game.playablePits();

    for (int col = 0; col < 7; col++) {
      // Row 0 (Top / North / Player 2): pits 13 down to 7 (right to left)
      final p2PitIndex = 13 - col;
      final topCenter = Offset((col + 0.5) * colWidth, rowHeight * 0.48);
      _drawPit(canvas, topCenter, pitRadiusW, pitRadiusH, game.pits[p2PitIndex], playable.contains(p2PitIndex), const Color(0xFF10B981));

      // Row 1 (Bottom / South / Player 1): pits 0 up to 6 (left to right)
      final p1PitIndex = col;
      final bottomCenter = Offset((col + 0.5) * colWidth, rowHeight * 1.52);
      _drawPit(canvas, bottomCenter, pitRadiusW, pitRadiusH, game.pits[p1PitIndex], playable.contains(p1PitIndex), const Color(0xFFFFD54F));
    }
  }

  void _drawPit(Canvas canvas, Offset center, double rw, double rh, int count, bool isPlayable, Color glowColor) {
    final pitRect = Rect.fromCenter(center: center, width: rw * 2, height: rh * 2);

    // Pit Depth Shadow
    canvas.drawOval(pitRect, Paint()..color = const Color(0xFF261910));
    canvas.drawOval(
      pitRect,
      Paint()
        ..color = const Color(0xFF1C130D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Glow for playable pits
    if (isPlayable) {
      canvas.drawOval(
        pitRect.inflate(3.5),
        Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    if (count > 0) {
      // Render Tamarind Seeds inside pit
      final seedRadius = min(rw, rh) * 0.22;
      final seedCountToDraw = min(count, 8);
      for (int i = 0; i < seedCountToDraw; i++) {
        final angle = (2 * pi * i) / seedCountToDraw;
        final spread = min(rw, rh) * 0.45;
        final sc = center + Offset(cos(angle) * spread, sin(angle) * spread * 0.75);

        // Tamarind seed (dark glossy amber pebble)
        canvas.drawCircle(sc + const Offset(1, 1), seedRadius, Paint()..color = Colors.black45);
        canvas.drawCircle(sc, seedRadius, Paint()..color = const Color(0xFFD4AF37));
        canvas.drawCircle(sc, seedRadius * 0.6, Paint()..color = const Color(0xFFFFF0B8));
      }

      // Seed Count Badge
      final tp = TextPainter(
        text: TextSpan(
          text: '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant PallanguzhiPainter oldDelegate) => true;
}

class PallanguzhiScreen extends StatefulWidget {
  final PallanguzhiConfig config;
  const PallanguzhiScreen({super.key, required this.config});

  @override
  State<PallanguzhiScreen> createState() => _PallanguzhiScreenState();
}

class _PallanguzhiScreenState extends State<PallanguzhiScreen> {
  late PallanguzhiGame game;
  bool _thinking = false;
  int _gen = 0;

  PallanguzhiConfig get config => widget.config;

  bool get isComputerTurn =>
      config.vsComputer && game.winner == null && game.turn != config.humanPlayer;

  @override
  void initState() {
    super.initState();
    game = PallanguzhiGame(config);
    _maybeComputerMove();
  }

  void restart() {
    _gen++;
    _thinking = false;
    setState(() {
      game = PallanguzhiGame(config);
    });
    _maybeComputerMove();
  }

  void _tapPit(int index) {
    if (isComputerTurn || game.winner != null) return;
    if (!game.playablePits().contains(index)) return;

    setState(() {
      final captured = game.sow(index);
      if (captured > 0) {
        Sound.play(Sfx.capture);
        Haptics.heavy();
      } else {
        Sound.play(Sfx.move);
        Haptics.light();
      }
    });

    if (game.winner != null) {
      final humanWon = !config.vsComputer || game.winner == config.humanPlayer;
      Sound.play(humanWon ? Sfx.win : Sfx.lose);
      Haptics.heavy();
      return;
    }

    _maybeComputerMove();
  }

  void _maybeComputerMove() {
    if (!isComputerTurn || _thinking || game.winner != null) return;
    _thinking = true;
    final token = _gen;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || token != _gen) return;

      final pit = PallanguzhiAI(difficulty: config.difficulty).pickPit(game);
      if (pit != null) {
        setState(() {
          final captured = game.sow(pit);
          if (captured > 0) {
            Sound.play(Sfx.capture);
          } else {
            Sound.play(Sfx.move);
          }
          _thinking = false;
        });
      } else {
        _thinking = false;
      }

      if (game.winner != null) {
        final humanWon = !config.vsComputer || game.winner == config.humanPlayer;
        Sound.play(humanWon ? Sfx.win : Sfx.lose);
        Haptics.heavy();
        return;
      }

      _maybeComputerMove();
    });
  }

  String get statusText {
    if (game.winner != null) {
      if (game.winner == 0) return "It's a Tie! (Equal seeds)";
      final name = (game.winner == 1) ? 'South (Gold)' : 'North (Jade)';
      if (config.vsComputer) {
        return (game.winner == config.humanPlayer) ? 'You win with more seeds!' : '$name (Computer) wins!';
      }
      return '$name won the game!';
    }
    if (isComputerTurn) {
      final name = (game.turn == 1) ? 'South' : 'North';
      return '$name (Computer) is sowing…';
    }
    final name = (game.turn == 1) ? 'South (Gold)' : 'North (Jade)';
    return "$name's turn: touch a pit to sow seeds";
  }

  Widget boardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = constraints.maxWidth * 0.95;
        final boardHeight = boardWidth * 0.52;

        return Center(
          child: SizedBox(
            width: boardWidth,
            height: boardHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final colWidth = boardWidth / 7.0;
                final rowHeight = boardHeight / 2.0;

                final col = (details.localPosition.dx / colWidth).floor().clamp(0, 6);
                final isTopRow = details.localPosition.dy < rowHeight;

                final pitIndex = isTopRow ? (13 - col) : col;
                _tapPit(pitIndex);
              },
              child: CustomPaint(
                size: Size(boardWidth, boardHeight),
                painter: PallanguzhiPainter(game: game),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Pallanguzhi',
      status: statusText,
      counters: [
        statCounter('SOUTH CAPTURED', '${game.store[0]} seeds'),
        statCounter('NORTH CAPTURED', '${game.store[1]} seeds'),
        statCounter('TOTAL SEEDS', '70'),
      ],
      board: boardArea(),
      endButtons: endButtonsRow(
        context,
        show: game.winner != null,
        onPlayAgain: restart,
      ),
      onRestart: restart,
    );
  }
}
