import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';

// ---------------------------------------------------------------------------
// ASHTA CHAMMA (7x7 Board with Cowrie Shells)
// ---------------------------------------------------------------------------

class AshtaConfig {
  final bool vsComputer;
  final int playerCount; // 2 or 4
  final Difficulty difficulty;
  const AshtaConfig({
    required this.vsComputer,
    required this.playerCount,
    required this.difficulty,
  });
}

class GridPos {
  final int r;
  final int c;
  const GridPos(this.r, this.c);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPos && runtimeType == other.runtimeType && r == other.r && c == other.c;

  @override
  int get hashCode => r.hashCode ^ c.hashCode;
}

// The 9 crossed safe zones from the traditional 7x7 Ashta Chamma cloth board
final Set<GridPos> kAshtaSafeHouses = {
  const GridPos(6, 3), // South Home (Player 0 - Red)
  const GridPos(3, 0), // West Home (Player 1 - Green)
  const GridPos(0, 3), // North Home (Player 2 - Yellow)
  const GridPos(3, 6), // East Home (Player 3 - Blue)
  const GridPos(5, 1), // Inner SW Safe
  const GridPos(1, 1), // Inner NW Safe
  const GridPos(1, 5), // Inner NE Safe
  const GridPos(5, 5), // Inner SE Safe
  const GridPos(3, 3), // Center Goal (Heaven / Moksha)
};

// Generates the 42-step anti-clockwise spiral path for each starting side
List<GridPos> generateAshtaPath(int playerIndex) {
  // Base outer ring (24 squares) starting from South (6,3) moving anti-clockwise
  const outer = [
    GridPos(6, 3), GridPos(6, 4), GridPos(6, 5), GridPos(6, 6),
    GridPos(5, 6), GridPos(4, 6), GridPos(3, 6), GridPos(2, 6), GridPos(1, 6), GridPos(0, 6),
    GridPos(0, 5), GridPos(0, 4), GridPos(0, 3), GridPos(0, 2), GridPos(0, 1), GridPos(0, 0),
    GridPos(1, 0), GridPos(2, 0), GridPos(3, 0), GridPos(4, 0), GridPos(5, 0), GridPos(6, 0),
    GridPos(6, 1), GridPos(6, 2),
  ];

  // Middle ring (16 squares, clockwise) and path into center goal (3,3)
  const inner = [
    GridPos(5, 3), GridPos(5, 2), GridPos(5, 1),
    GridPos(4, 1), GridPos(3, 1), GridPos(2, 1), GridPos(1, 1),
    GridPos(1, 2), GridPos(1, 3), GridPos(1, 4), GridPos(1, 5),
    GridPos(2, 5), GridPos(3, 5), GridPos(4, 5), GridPos(5, 5),
    GridPos(5, 4),
    // Final entry step and goal
    GridPos(4, 3), GridPos(3, 3),
  ];

  // Helper to rotate coordinates clockwise around center (3,3)
  GridPos rot(GridPos p, int times) {
    int r = p.r;
    int c = p.c;
    for (int i = 0; i < times; i++) {
      final oldR = r;
      r = c;
      c = 6 - oldR;
    }
    return GridPos(r, c);
  }

  // playerIndex 0 = South (0 rot), 1 = West (1 rot), 2 = North (2 rot), 3 = East (3 rot)
  final int rotations = playerIndex % 4;
  final fullBase = [...outer, ...inner];
  return fullBase.map((p) => rot(p, rotations)).toList();
}

class CowrieRoll {
  final List<bool> shells; // true = mouth open/facing up, false = down
  final int value;
  final bool grantsExtraTurn;

  const CowrieRoll(this.shells, this.value, this.grantsExtraTurn);

  factory CowrieRoll.roll(Random rng) {
    final s = List.generate(4, (_) => rng.nextBool());
    final upCount = s.where((up) => up).length;
    // 0 up = 8 (Ashta), 4 up = 4 (Chamma), 1..3 up = 1..3
    final val = (upCount == 0) ? 8 : (upCount == 4 ? 4 : upCount);
    final extra = (val == 4 || val == 8);
    return CowrieRoll(s, val, extra);
  }
}

class AshtaPawn {
  int stepIndex; // 0 = at starting home house, 1..40 = on path, 41 = finished in center goal
  AshtaPawn() : stepIndex = 0;
  bool get atGoal => stepIndex >= 41;
}

class AshtaPlayer {
  final int id;
  final String name;
  final Color color;
  final List<AshtaPawn> pawns;
  final List<GridPos> path;
  bool hasKilled;

  AshtaPlayer({
    required this.id,
    required this.name,
    required this.color,
    required int pawnCount,
  })  : pawns = List.generate(pawnCount, (_) => AshtaPawn()),
        path = generateAshtaPath(id),
        hasKilled = false;

  bool get isWinner => pawns.every((p) => p.atGoal);
  int get pawnsHomeCount => pawns.where((p) => p.atGoal).length;
}

class AshtaGame {
  final AshtaConfig config;
  final List<AshtaPlayer> players;
  final Random rng = Random();
  int currentTurn = 0;
  CowrieRoll? lastRoll;
  bool awaitingRoll = true;
  int? selectedPawn;
  int? winner;

  AshtaGame(this.config)
      : players = _buildPlayers(config.playerCount);

  static List<AshtaPlayer> _buildPlayers(int count) {
    if (count == 2) {
      return [
        AshtaPlayer(id: 0, name: 'Red', color: const Color(0xFFE53935), pawnCount: 4),
        AshtaPlayer(id: 2, name: 'Yellow', color: const Color(0xFFFBC02D), pawnCount: 4),
      ];
    }
    return [
      AshtaPlayer(id: 0, name: 'Red', color: const Color(0xFFE53935), pawnCount: 4),
      AshtaPlayer(id: 1, name: 'Green', color: const Color(0xFF43A047), pawnCount: 4),
      AshtaPlayer(id: 2, name: 'Yellow', color: const Color(0xFFFBC02D), pawnCount: 4),
      AshtaPlayer(id: 3, name: 'Blue', color: const Color(0xFF1E88E5), pawnCount: 4),
    ];
  }

  AshtaPlayer get currentPlayer => players[currentTurn];

  CowrieRoll roll() {
    final r = CowrieRoll.roll(rng);
    lastRoll = r;
    awaitingRoll = false;
    selectedPawn = null;

    final valid = movablePawns();
    if (valid.isEmpty) {
      // No move possible with this roll
      if (!r.grantsExtraTurn) {
        _advanceTurn();
      } else {
        awaitingRoll = true; // Still gets their bonus roll
      }
    } else if (valid.length == 1) {
      // Auto-select the only movable pawn
      selectedPawn = valid.first;
    }
    return r;
  }

  List<int> movablePawns() {
    if (lastRoll == null) return [];
    final p = currentPlayer;
    final rollVal = lastRoll!.value;
    final valid = <int>[];

    for (int i = 0; i < p.pawns.length; i++) {
      final pawn = p.pawns[i];
      if (pawn.atGoal) continue;

      int target = pawn.stepIndex + rollVal;
      // If player has not killed an opponent, they cannot enter the inner ring (steps 24+)
      if (pawn.stepIndex < 24 && target >= 24 && !p.hasKilled) {
        // Wrap around outer ring (24 squares)
        target = target % 24;
      }

      // Exact landing required for center goal (step 41)
      if (target <= 41) {
        valid.add(i);
      }
    }
    return valid;
  }

  // Returns true if a capture occurred
  bool applyMove(int pawnIndex) {
    if (awaitingRoll || lastRoll == null) return false;
    final p = currentPlayer;
    final roll = lastRoll!;
    final pawn = p.pawns[pawnIndex];

    int target = pawn.stepIndex + roll.value;
    if (pawn.stepIndex < 24 && target >= 24 && !p.hasKilled) {
      target = target % 24;
    }
    if (target > 41) return false;

    pawn.stepIndex = target;
    selectedPawn = null;

    bool captured = false;
    final targetPos = p.path[target];

    // Check for capture on non-safe houses
    if (!kAshtaSafeHouses.contains(targetPos) && target < 41) {
      for (final other in players) {
        if (other == p) continue;
        for (final oppPawn in other.pawns) {
          if (!oppPawn.atGoal && other.path[oppPawn.stepIndex] == targetPos) {
            // Captured! Send opponent back to their starting home house
            oppPawn.stepIndex = 0;
            p.hasKilled = true;
            captured = true;
          }
        }
      }
    }

    if (p.isWinner) {
      winner = p.id;
      return captured;
    }

    // Extra roll granted if rolled 4/8 or captured
    if (roll.grantsExtraTurn || captured) {
      awaitingRoll = true;
      lastRoll = null;
    } else {
      _advanceTurn();
    }
    return captured;
  }

  void _advanceTurn() {
    lastRoll = null;
    selectedPawn = null;
    awaitingRoll = true;
    currentTurn = (currentTurn + 1) % players.length;
  }
}

// ---------------------------------------------------------------------------
// ASHTA CHAMMA AI
// ---------------------------------------------------------------------------

class AshtaAI {
  final Difficulty difficulty;
  final Random _random = Random();
  AshtaAI({required this.difficulty});

  int? pickPawn(AshtaGame game) {
    final movable = game.movablePawns();
    if (movable.isEmpty) return null;
    if (movable.length == 1) return movable.first;

    final mistakeChance = switch (difficulty) {
      Difficulty.easy => 0.40,
      Difficulty.medium => 0.12,
      Difficulty.hard => 0.0,
    };

    if (mistakeChance > 0 && _random.nextDouble() < mistakeChance) {
      return movable[_random.nextInt(movable.length)];
    }

    final p = game.currentPlayer;
    final rollVal = game.lastRoll!.value;
    int bestPawn = movable.first;
    double bestScore = -999999;

    for (final idx in movable) {
      final pawn = p.pawns[idx];
      int target = pawn.stepIndex + rollVal;
      if (pawn.stepIndex < 24 && target >= 24 && !p.hasKilled) {
        target = target % 24;
      }
      final targetPos = p.path[target];
      double score = 0;

      // 1. Prioritize landing on center goal
      if (target == 41) score += 1200;

      // 2. Prioritize capturing opponent
      if (!kAshtaSafeHouses.contains(targetPos)) {
        for (final other in game.players) {
          if (other == p) continue;
          for (final opp in other.pawns) {
            if (!opp.atGoal && other.path[opp.stepIndex] == targetPos) {
              score += 700; // Big capture bonus + grants extra turn
            }
          }
        }
      }

      // 3. Prioritize landing on safe house
      if (kAshtaSafeHouses.contains(targetPos)) {
        score += 250;
      }

      // 4. Moving pawns that are currently in danger
      final curPos = p.path[pawn.stepIndex];
      if (!kAshtaSafeHouses.contains(curPos)) {
        score += 100; // Reward getting off an open unsafe square
      }

      // 5. Advancing forward
      score += target * 2.5;

      if (score > bestScore) {
        bestScore = score;
        bestPawn = idx;
      }
    }
    return bestPawn;
  }
}

// ---------------------------------------------------------------------------
// PROCEDURAL COWRIE SHELL & BOARD PAINTERS
// ---------------------------------------------------------------------------

void drawCowrieShell(Canvas canvas, Offset center, double size, bool mouthUp) {
  canvas.save();
  canvas.translate(center.dx, center.dy);

  final shellWidth = size * 0.9;
  final shellHeight = size * 1.35;
  final bodyRect = Rect.fromCenter(center: Offset.zero, width: shellWidth, height: shellHeight);

  // Outer glossy shell body
  final basePaint = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.2, -0.3),
      colors: mouthUp
          ? [const Color(0xFFFFF9E6), const Color(0xFFECD5A5), const Color(0xFFC7A870)]
          : [const Color(0xFFFFF8E7), const Color(0xFFE6C895), const Color(0xFFA8824B)],
    ).createShader(bodyRect);

  final borderPaint = Paint()
    ..color = const Color(0xFF6B4C28)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.5, size * 0.06);

  canvas.drawOval(bodyRect, basePaint);
  canvas.drawOval(bodyRect, borderPaint);

  if (mouthUp) {
    // Open mouth / aperture with serrated teeth edges
    final slitRect = Rect.fromCenter(center: Offset.zero, width: shellWidth * 0.32, height: shellHeight * 0.72);
    final slitPaint = Paint()..color = const Color(0xFF3E2712);
    canvas.drawOval(slitRect, slitPaint);

    final toothPaint = Paint()
      ..color = const Color(0xFFFFF9E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, size * 0.05);

    // Grooved ridges along aperture
    for (double y = -shellHeight * 0.28; y <= shellHeight * 0.28; y += shellHeight * 0.1) {
      canvas.drawLine(Offset(-shellWidth * 0.16, y), Offset(-shellWidth * 0.04, y), toothPaint);
      canvas.drawLine(Offset(shellWidth * 0.04, y), Offset(shellWidth * 0.16, y), toothPaint);
    }
  } else {
    // Smooth back with glossy highlight
    final highlightPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-shellWidth * 0.12, -shellHeight * 0.15), width: shellWidth * 0.4, height: shellHeight * 0.5),
      highlightPaint,
    );
  }
  canvas.restore();
}

class AshtaBoardPainter extends CustomPainter {
  final AshtaGame game;
  final int? selectedPawn;

  AshtaBoardPainter({required this.game, this.selectedPawn});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 7.0;

    // Cloth texture background
    final bgPaint = Paint()..color = const Color(0xFFF7EBD2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF3B2A1A)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final safeFillPaint = Paint()..color = const Color(0xFFEAD2A8);

    // Draw 7x7 grid and safe houses
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        final isSafe = kAshtaSafeHouses.contains(GridPos(r, c));

        if (isSafe) {
          canvas.drawRect(rect, safeFillPaint);
        }
        canvas.drawRect(rect, linePaint);

        if (isSafe) {
          // Draw the traditional X
          canvas.drawLine(rect.topLeft, rect.bottomRight, linePaint);
          canvas.drawLine(rect.topRight, rect.bottomLeft, linePaint);
        }
      }
    }

    // List of movable pawn indexes for current player
    final List<int> movable = (!game.awaitingRoll) ? game.movablePawns() : [];

    // Highlight target destination of selected pawn with green ring
    if (selectedPawn != null && game.lastRoll != null) {
      final p = game.currentPlayer;
      final pawn = p.pawns[selectedPawn!];
      int target = pawn.stepIndex + game.lastRoll!.value;
      if (pawn.stepIndex < 24 && target >= 24 && !p.hasKilled) {
        target = target % 24;
      }
      if (target <= 41) {
        final pos = p.path[target];
        final center = Offset((pos.c + 0.5) * cellSize, (pos.r + 0.5) * cellSize);
        final targetPaint = Paint()
          ..color = const Color(0xFF2E7D32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        canvas.drawCircle(center, cellSize * 0.40, targetPaint);
      }
    }

    // Collect pawns per square to draw them neatly without overlapping
    final Map<GridPos, List<_PawnDrawInfo>> pawnsOnSquare = {};
    for (final player in game.players) {
      for (int i = 0; i < player.pawns.length; i++) {
        final pawn = player.pawns[i];
        final pos = player.path[pawn.stepIndex];
        final isCurrent = (player == game.currentPlayer);
        final canMove = isCurrent && movable.contains(i);
        pawnsOnSquare.putIfAbsent(pos, () => []).add(
          _PawnDrawInfo(
            player: player,
            pawnIndex: i,
            isCurrentPlayer: isCurrent,
            canMove: canMove,
            isSelected: isCurrent && i == selectedPawn,
          ),
        );
      }
    }

    // Render pawns
    for (final entry in pawnsOnSquare.entries) {
      final pos = entry.key;
      final pawns = entry.value;
      final squareCenter = Offset((pos.c + 0.5) * cellSize, (pos.r + 0.5) * cellSize);

      if (pawns.length == 1) {
        _renderSinglePawn(canvas, squareCenter, cellSize * 0.32, pawns.first);
      } else {
        // Multi-pawn arrangement inside one square
        final count = pawns.length;
        final subRadius = cellSize * 0.18;
        final spread = cellSize * 0.22;
        for (int i = 0; i < count; i++) {
          final angle = (2 * pi * i) / count - pi / 2;
          final offset = squareCenter + Offset(cos(angle) * spread, sin(angle) * spread);
          _renderSinglePawn(canvas, offset, subRadius, pawns[i]);
        }
      }
    }
  }

  void _renderSinglePawn(Canvas canvas, Offset center, double radius, _PawnDrawInfo info) {
    // Pulsing/Glowing ring for ANY coin that CAN MOVE!
    if (info.canMove) {
      canvas.drawCircle(
        center,
        radius * 1.55,
        Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
      canvas.drawCircle(
        center,
        radius * 1.35,
        Paint()
          ..color = const Color(0x66FFD54F)
          ..style = PaintingStyle.fill,
      );
    }

    // Selected pawn halo
    if (info.isSelected) {
      canvas.drawCircle(
        center,
        radius * 1.7,
        Paint()
          ..color = const Color(0xFF00E676)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    // Dark shadow base
    canvas.drawCircle(center + const Offset(1, 2), radius, Paint()..color = const Color(0x66000000));

    // Pawn coin face
    final fillPaint = Paint()..color = info.player.color;
    canvas.drawCircle(center, radius, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.4, radius * 0.16);
    canvas.drawCircle(center, radius, borderPaint);

    // Inner gold ring
    canvas.drawCircle(center, radius * 0.65, Paint()..color = const Color(0x44FFFFFF));
  }

  @override
  bool shouldRepaint(covariant AshtaBoardPainter oldDelegate) => true;
}

class _PawnDrawInfo {
  final AshtaPlayer player;
  final int pawnIndex;
  final bool isCurrentPlayer;
  final bool canMove;
  final bool isSelected;
  const _PawnDrawInfo({
    required this.player,
    required this.pawnIndex,
    required this.isCurrentPlayer,
    required this.canMove,
    required this.isSelected,
  });
}

// ---------------------------------------------------------------------------
// ASHTA CHAMMA GAME SCREEN
// ---------------------------------------------------------------------------

class AshtaChammaScreen extends StatefulWidget {
  final AshtaConfig config;
  const AshtaChammaScreen({super.key, required this.config});

  @override
  State<AshtaChammaScreen> createState() => _AshtaChammaScreenState();
}

class _AshtaChammaScreenState extends State<AshtaChammaScreen> {
  late AshtaGame game;
  bool _thinking = false;
  int _gen = 0;

  AshtaConfig get config => widget.config;

  // In vsComputer, player 0 is human. Any other player (1, 2, 3) is a computer!
  // In Pass & Play, ALL players are humans (isComputerTurn is always false)!
  bool get isComputerTurn =>
      config.vsComputer && game.winner == null && game.currentTurn != 0;

  @override
  void initState() {
    super.initState();
    game = AshtaGame(config);
  }

  void restart() {
    _gen++;
    _thinking = false;
    setState(() {
      game = AshtaGame(config);
    });
  }

  void _roll() {
    if (!game.awaitingRoll || game.winner != null || isComputerTurn) return;
    Haptics.medium();
    Sound.play(Sfx.select);

    setState(() {
      final roll = game.roll();
      if (roll.grantsExtraTurn) {
        Sound.play(Sfx.win);
      }
    });

    _maybeComputerMove();
  }

  void _tapPawn(int pawnIdx) {
    if (game.awaitingRoll || game.winner != null || isComputerTurn) return;
    if (!game.movablePawns().contains(pawnIdx)) return;

    final captured = game.applyMove(pawnIdx);
    if (captured) {
      Sound.play(Sfx.capture);
      Haptics.heavy();
    } else {
      Sound.play(Sfx.move);
      Haptics.light();
    }

    setState(() {});

    if (game.winner != null) {
      final humanWon = !config.vsComputer || game.winner == 0;
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

      if (game.awaitingRoll) {
        setState(() {
          final roll = game.roll();
          Sound.play(Sfx.select);
          if (roll.grantsExtraTurn) Sound.play(Sfx.win);
        });
        _thinking = false;
        _maybeComputerMove();
      } else {
        final chosen = AshtaAI(difficulty: config.difficulty).pickPawn(game);
        if (chosen != null) {
          final captured = game.applyMove(chosen);
          if (captured) {
            Sound.play(Sfx.capture);
            Haptics.heavy();
          } else {
            Sound.play(Sfx.move);
            Haptics.light();
          }
        }
        _thinking = false;
        setState(() {});

        if (game.winner != null) {
          final humanWon = !config.vsComputer || game.winner == 0;
          Sound.play(humanWon ? Sfx.win : Sfx.lose);
          Haptics.heavy();
          return;
        }

        _maybeComputerMove();
      }
    });
  }

  String get statusText {
    final w = game.winner;
    if (w != null) {
      final winnerPlayer = game.players.firstWhere((p) => p.id == w);
      if (config.vsComputer) {
        return w == 0 ? 'You win!' : '${winnerPlayer.name} wins!';
      }
      return '${winnerPlayer.name} wins!';
    }
    if (isComputerTurn) {
      final cur = game.currentPlayer;
      return '${cur.name} (Computer) is thinking…';
    }
    final cur = game.currentPlayer;
    final who = (config.vsComputer && cur.id == 0) ? 'Your turn (Red)' : "${cur.name}'s turn";

    if (game.awaitingRoll) {
      return '$who: roll the shells';
    }
    final rollVal = game.lastRoll?.value ?? 0;
    final rollName = switch (rollVal) {
      4 => '4 (Chamma!) - Extra roll',
      8 => '8 (Ashta!) - Extra roll',
      _ => '$rollVal',
    };
    return '$who: rolled $rollName • Touch a coin to move';
  }

  Widget boardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight) * 0.94;
        final cellSize = boardSize / 7.0;

        return Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (game.awaitingRoll || isComputerTurn || game.winner != null) return;
                final r = (details.localPosition.dy / cellSize).floor();
                final c = (details.localPosition.dx / cellSize).floor();
                if (r < 0 || r >= 7 || c < 0 || c >= 7) return;
                final tappedPos = GridPos(r, c);

                final cur = game.currentPlayer;
                final validPawns = game.movablePawns();

                // 1. Check if user directly tapped on a square containing their movable coin
                for (final idx in validPawns) {
                  final pawn = cur.pawns[idx];
                  if (cur.path[pawn.stepIndex] == tappedPos) {
                    _tapPawn(idx);
                    return;
                  }
                }

                // 2. Check if user tapped on the destination square of a movable pawn
                if (game.lastRoll != null) {
                  final rollVal = game.lastRoll!.value;
                  for (final idx in validPawns) {
                    final pawn = cur.pawns[idx];
                    int target = pawn.stepIndex + rollVal;
                    if (pawn.stepIndex < 24 && target >= 24 && !cur.hasKilled) {
                      target = target % 24;
                    }
                    if (target <= 41 && cur.path[target] == tappedPos) {
                      _tapPawn(idx);
                      return;
                    }
                  }
                }
              },
              child: CustomPaint(
                size: Size(boardSize, boardSize),
                painter: AshtaBoardPainter(
                  game: game,
                  selectedPawn: game.selectedPawn,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget cowriePanel() {
    final cur = game.currentPlayer;
    final roll = game.lastRoll;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1F12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cur.color, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: cur.color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 4 Cowrie shells display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final mouthUp = roll != null ? roll.shells[i] : true;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: CustomPaint(
                  size: const Size(30, 40),
                  painter: _SingleShellPainter(mouthUp: mouthUp),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Control Area: Roll button when awaiting roll, or Touch Hint when rolled!
          if (game.awaitingRoll)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: (!isComputerTurn && game.winner == null) ? _roll : null,
                style: FilledButton.styleFrom(
                  backgroundColor: cur.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.casino, size: 22),
                label: Text(
                  "${cur.name.toUpperCase()} • ROLL SHELLS",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: cur.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cur.color.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, color: cur.color, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Touch your glowing coin on the board to move',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = game.currentPlayer;
    final rollVal = game.lastRoll?.value;
    final rollLabel = rollVal != null ? (rollVal == 8 ? '8 (Ashta)' : (rollVal == 4 ? '4 (Chamma)' : '$rollVal')) : '-';

    return GameFrame(
      title: 'Ashta Chamma',
      status: statusText,
      counters: [
        statCounter('LAST ROLL', rollLabel),
        statCounter('GOAL REACHED', '${cur.pawnsHomeCount}/4'),
        statCounter('INNER RING', cur.hasKilled ? 'Unlocked' : 'Need Kill'),
      ],
      board: Column(
        children: [
          Expanded(child: boardArea()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: cowriePanel(),
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

class _SingleShellPainter extends CustomPainter {
  final bool mouthUp;
  const _SingleShellPainter({required this.mouthUp});

  @override
  void paint(Canvas canvas, Size size) {
    drawCowrieShell(canvas, Offset(size.width / 2, size.height / 2), size.width * 0.9, mouthUp);
  }

  @override
  bool shouldRepaint(covariant _SingleShellPainter oldDelegate) => oldDelegate.mouthUp != mouthUp;
}
