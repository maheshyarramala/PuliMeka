import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../ashta_chamma.dart';

class PachisiConfig {
  final bool vsComputer;
  final int playerCount; // 2 or 4
  final Difficulty difficulty;

  const PachisiConfig({
    required this.vsComputer,
    required this.playerCount,
    required this.difficulty,
  });
}

// Grid dimensions for the cruciform cross board: 19x19 or 15x15
// A standard Chaupar / Pachisi arm is 3 squares wide by 8 squares long, with a 3x3 Charkoni in the center.
// Total board width = 8 (left arm) + 3 (center) + 8 (right arm) = 19 squares!
// Normalized coordinate grid (0..18, 0..18)

class PachisiPawn {
  int stepIndex; // 0 = at Charkoni, 1..67 = outer loop, 68..75 = home lane, 76 = reached Charkoni goal
  PachisiPawn() : stepIndex = 0;
  bool get atGoal => stepIndex >= 76;
}

class PachisiPlayer {
  final int id;
  final String name;
  final Color color;
  final List<PachisiPawn> pawns;
  final List<GridPos> path;
  bool hasCaptured;

  PachisiPlayer({
    required this.id,
    required this.name,
    required this.color,
    required int pawnCount,
  })  : pawns = List.generate(pawnCount, (_) => PachisiPawn()),
        path = _generatePachisiPath(id),
        hasCaptured = false;

  bool get isWinner => pawns.every((p) => p.atGoal);
  int get pawnsHomeCount => pawns.where((p) => p.atGoal).length;
}

// Generates the 76-step path for each player around the cruciform board
List<GridPos> _generatePachisiPath(int playerIndex) {
  // Base path starting from South arm (moving down center lane, around perimeter, and returning up home lane)
  // Cross has arms in 4 directions: South (col 8..10, row 11..18), North (col 8..10, row 0..7),
  // West (col 0..7, row 8..10), East (col 11..18, row 8..10), Center (col 8..10, row 8..10).

  final List<GridPos> perimeter = [];

  // South Arm right side down
  for (int r = 11; r <= 18; r++) perimeter.add(GridPos(r, 10));
  perimeter.add(const GridPos(18, 9)); // Bottom turn
  // South Arm left side up
  for (int r = 18; r >= 11; r--) perimeter.add(GridPos(r, 8));

  // West Arm bottom side left
  for (int c = 7; c >= 0; c--) perimeter.add(GridPos(10, c));
  perimeter.add(const GridPos(9, 0)); // Left turn
  // West Arm top side right
  for (int c = 0; c <= 7; c++) perimeter.add(GridPos(8, c));

  // North Arm left side up
  for (int r = 7; r >= 0; r--) perimeter.add(GridPos(r, 8));
  perimeter.add(const GridPos(0, 9)); // Top turn
  // North Arm right side down
  for (int r = 0; r <= 7; r++) perimeter.add(GridPos(r, 10));

  // East Arm top side right
  for (int c = 11; c <= 18; c++) perimeter.add(GridPos(8, c));
  perimeter.add(const GridPos(9, 18)); // Right turn
  // East Arm bottom side left
  for (int c = 18; c >= 11; c--) perimeter.add(GridPos(10, c));

  // Final home lane returning up South Arm center column into Charkoni
  final List<GridPos> homeLane = [];
  for (int r = 18; r >= 11; r--) homeLane.add(GridPos(r, 9));
  homeLane.add(const GridPos(10, 9)); // Enter Charkoni Goal

  GridPos rot(GridPos p, int times) {
    int r = p.r;
    int c = p.c;
    for (int i = 0; i < times; i++) {
      final oldR = r;
      r = c;
      c = 18 - oldR;
    }
    return GridPos(r, c);
  }

  final offset = playerIndex * 17; // 68 total perimeter / 4 arms = 17 per arm
  final playerPerimeter = <GridPos>[];
  for (int i = 0; i < perimeter.length; i++) {
    playerPerimeter.add(perimeter[(i + offset) % perimeter.length]);
  }

  final rotatedHomeLane = homeLane.map((p) => rot(p, playerIndex % 4)).toList();

  return [...playerPerimeter, ...rotatedHomeLane];
}

// 12 Traditional Safe Castles on the Pachisi Cross
final Set<GridPos> kPachisiCastles = {
  // South Arm Castles
  const GridPos(15, 8), const GridPos(15, 10), const GridPos(12, 9),
  // West Arm Castles
  const GridPos(8, 3), const GridPos(10, 3), const GridPos(9, 6),
  // North Arm Castles
  const GridPos(3, 8), const GridPos(3, 10), const GridPos(6, 9),
  // East Arm Castles
  const GridPos(8, 15), const GridPos(10, 15), const GridPos(9, 12),
};

class PachisiGame {
  final PachisiConfig config;
  final List<PachisiPlayer> players;
  final Random rng = Random();
  int currentTurn = 0;
  CowrieRoll? lastRoll;
  bool awaitingRoll = true;
  int? selectedPawn;
  int? winner;

  PachisiGame(this.config)
      : players = _buildPlayers(config.playerCount);

  static List<PachisiPlayer> _buildPlayers(int count) {
    if (count == 2) {
      return [
        PachisiPlayer(id: 0, name: 'Yellow', color: const Color(0xFFFBC02D), pawnCount: 4),
        PachisiPlayer(id: 2, name: 'Red', color: const Color(0xFFE53935), pawnCount: 4),
      ];
    }
    return [
      PachisiPlayer(id: 0, name: 'Yellow', color: const Color(0xFFFBC02D), pawnCount: 4),
      PachisiPlayer(id: 1, name: 'Green', color: const Color(0xFF43A047), pawnCount: 4),
      PachisiPlayer(id: 2, name: 'Red', color: const Color(0xFFE53935), pawnCount: 4),
      PachisiPlayer(id: 3, name: 'Blue', color: const Color(0xFF1E88E5), pawnCount: 4),
    ];
  }

  PachisiPlayer get currentPlayer => players[currentTurn];

  CowrieRoll roll() {
    final r = CowrieRoll.roll(rng);
    lastRoll = r;
    awaitingRoll = false;
    selectedPawn = null;

    final valid = movablePawns();
    if (valid.isEmpty) {
      if (!r.grantsExtraTurn) {
        _advanceTurn();
      } else {
        awaitingRoll = true;
      }
    } else if (valid.length == 1) {
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
      // Must capture at least 1 opponent before entering home lane (step 68+)
      if (pawn.stepIndex < 68 && target >= 68 && !p.hasCaptured) {
        target = target % 68; // Continue looping outer perimeter
      }

      if (target <= 76) {
        valid.add(i);
      }
    }
    return valid;
  }

  bool applyMove(int pawnIndex) {
    if (awaitingRoll || lastRoll == null) return false;
    final p = currentPlayer;
    final roll = lastRoll!;
    final pawn = p.pawns[pawnIndex];

    int target = pawn.stepIndex + roll.value;
    if (pawn.stepIndex < 68 && target >= 68 && !p.hasCaptured) {
      target = target % 68;
    }
    if (target > 76) return false;

    pawn.stepIndex = target;
    selectedPawn = null;

    bool captured = false;
    if (target < p.path.length) {
      final targetPos = p.path[target];
      if (!kPachisiCastles.contains(targetPos) && target < 76) {
        for (final other in players) {
          if (other == p) continue;
          for (final oppPawn in other.pawns) {
            if (!oppPawn.atGoal && oppPawn.stepIndex < other.path.length && other.path[oppPawn.stepIndex] == targetPos) {
              oppPawn.stepIndex = 0; // Captured! Sent back to Charkoni
              p.hasCaptured = true;
              captured = true;
            }
          }
        }
      }
    }

    if (p.isWinner) {
      winner = p.id;
      return captured;
    }

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

class PachisiAI {
  final Difficulty difficulty;
  final Random _rng = Random();

  PachisiAI({required this.difficulty});

  int? pickPawn(PachisiGame g) {
    final movable = g.movablePawns();
    if (movable.isEmpty) return null;
    if (movable.length == 1) return movable.first;

    if (difficulty == Difficulty.easy && _rng.nextDouble() < 0.45) {
      return movable[_rng.nextInt(movable.length)];
    }

    int bestPawn = movable.first;
    double bestScore = -999999;
    final p = g.currentPlayer;
    final rollVal = g.lastRoll!.value;

    for (final idx in movable) {
      final pawn = p.pawns[idx];
      int target = pawn.stepIndex + rollVal;
      if (pawn.stepIndex < 68 && target >= 68 && !p.hasCaptured) {
        target = target % 68;
      }
      double score = 0;

      if (target == 76) score += 1200; // Reach Charkoni Goal
      if (target < p.path.length) {
        final pos = p.path[target];
        // Capture bonus
        if (!kPachisiCastles.contains(pos)) {
          for (final other in g.players) {
            if (other == p) continue;
            for (final opp in other.pawns) {
              if (!opp.atGoal && opp.stepIndex < other.path.length && other.path[opp.stepIndex] == pos) {
                score += 800;
              }
            }
          }
        }
        if (kPachisiCastles.contains(pos)) score += 250; // Safe castle
      }
      score += target * 2.0;

      if (score > bestScore) {
        bestScore = score;
        bestPawn = idx;
      }
    }
    return bestPawn;
  }
}

class PachisiPainter extends CustomPainter {
  final PachisiGame game;
  final int? selectedPawn;

  PachisiPainter({required this.game, this.selectedPawn});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 19.0;

    // Background Fabric Cloth
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFF7EBD2));

    final linePaint = Paint()
      ..color = const Color(0xFF3B2A1A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final castleFill = Paint()..color = const Color(0xFFEAD2A8);

    // Draw Cruciform Arms & Cells
    // A cell (r, c) is on the cross if: (r in 8..10) OR (c in 8..10)
    for (int r = 0; r < 19; r++) {
      for (int c = 0; c < 19; c++) {
        final inCross = (r >= 8 && r <= 10) || (c >= 8 && c <= 10);
        if (!inCross) continue;

        final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        final pos = GridPos(r, c);
        final isCastle = kPachisiCastles.contains(pos);

        // Center Charkoni
        if (r >= 8 && r <= 10 && c >= 8 && c <= 10) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFFFD54F).withOpacity(0.4));
        } else if (isCastle) {
          canvas.drawRect(rect, castleFill);
        }

        canvas.drawRect(rect, linePaint);

        if (isCastle) {
          canvas.drawLine(rect.topLeft, rect.bottomRight, linePaint);
          canvas.drawLine(rect.topRight, rect.bottomLeft, linePaint);
        }
      }
    }

    // Highlight Movable Pawns & Selected Pawn
    final movable = (!game.awaitingRoll) ? game.movablePawns() : <int>[];

    final Map<GridPos, List<PachisiPlayer>> pawnsOnPos = {};
    for (final player in game.players) {
      for (int i = 0; i < player.pawns.length; i++) {
        final pawn = player.pawns[i];
        if (pawn.stepIndex < player.path.length) {
          final pos = player.path[pawn.stepIndex];
          pawnsOnPos.putIfAbsent(pos, () => []).add(player);
        }
      }
    }

    // Draw Pawns
    for (final entry in pawnsOnPos.entries) {
      final pos = entry.key;
      final playersHere = entry.value;
      final center = Offset((pos.c + 0.5) * cellSize, (pos.r + 0.5) * cellSize);

      for (int i = 0; i < playersHere.length; i++) {
        final player = playersHere[i];
        final shift = (playersHere.length > 1)
            ? Offset((i - (playersHere.length - 1) / 2) * (cellSize * 0.22), 0)
            : Offset.zero;
        final pCenter = center + shift;
        final radius = cellSize * 0.32;

        final isCurrent = (player == game.currentPlayer);
        final canMove = isCurrent && movable.isNotEmpty;

        if (canMove) {
          canvas.drawCircle(pCenter, radius * 1.5, Paint()..color = const Color(0xFFFFD54F)..style = PaintingStyle.stroke..strokeWidth = 2.5);
        }

        canvas.drawCircle(pCenter + const Offset(1, 1), radius, Paint()..color = const Color(0x66000000));
        canvas.drawCircle(pCenter, radius, Paint()..color = player.color);
        canvas.drawCircle(pCenter, radius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PachisiPainter oldDelegate) => true;
}

class PachisiScreen extends StatefulWidget {
  final PachisiConfig config;
  const PachisiScreen({super.key, required this.config});

  @override
  State<PachisiScreen> createState() => _PachisiScreenState();
}

class _PachisiScreenState extends State<PachisiScreen> {
  late PachisiGame game;
  bool _thinking = false;
  int _gen = 0;

  PachisiConfig get config => widget.config;

  bool get isComputerTurn =>
      config.vsComputer && game.winner == null && game.currentTurn != 0;

  @override
  void initState() {
    super.initState();
    game = PachisiGame(config);
  }

  void restart() {
    _gen++;
    _thinking = false;
    setState(() {
      game = PachisiGame(config);
    });
  }

  void _roll() {
    if (!game.awaitingRoll || game.winner != null || isComputerTurn) return;
    Haptics.medium();
    Sound.play(Sfx.select);

    setState(() {
      final roll = game.roll();
      if (roll.grantsExtraTurn) Sound.play(Sfx.win);
    });

    _maybeComputerMove();
  }

  void _tapPawn(int idx) {
    if (game.awaitingRoll || game.winner != null || isComputerTurn) return;
    if (!game.movablePawns().contains(idx)) return;

    final captured = game.applyMove(idx);
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
        final chosen = PachisiAI(difficulty: config.difficulty).pickPawn(game);
        if (chosen != null) {
          final captured = game.applyMove(chosen);
          if (captured) Sound.play(Sfx.capture); else Sound.play(Sfx.move);
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
        return w == 0 ? 'You conquered the Charkoni!' : '${winnerPlayer.name} won the race!';
      }
      return '${winnerPlayer.name} won the race!';
    }
    if (isComputerTurn) {
      final cur = game.currentPlayer;
      return '${cur.name} (Computer) is rolling…';
    }
    final cur = game.currentPlayer;
    final who = (config.vsComputer && cur.id == 0) ? 'Your turn (Yellow)' : "${cur.name}'s turn";
    if (game.awaitingRoll) return '$who: roll the cowrie shells';
    final r = game.lastRoll?.value ?? 0;
    return '$who: rolled $r • Touch your coin on the board to move';
  }

  Widget boardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight) * 0.95;
        final cellSize = boardSize / 19.0;

        return Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (game.awaitingRoll || isComputerTurn || game.winner != null) return;
                final r = (details.localPosition.dy / cellSize).floor().clamp(0, 18);
                final c = (details.localPosition.dx / cellSize).floor().clamp(0, 18);
                final tappedPos = GridPos(r, c);

                final cur = game.currentPlayer;
                final valid = game.movablePawns();

                for (final idx in valid) {
                  final pawn = cur.pawns[idx];
                  if (pawn.stepIndex < cur.path.length && cur.path[pawn.stepIndex] == tappedPos) {
                    _tapPawn(idx);
                    return;
                  }
                }
              },
              child: CustomPaint(
                size: Size(boardSize, boardSize),
                painter: PachisiPainter(game: game, selectedPawn: game.selectedPawn),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1F12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cur.color, width: 2.2),
        boxShadow: [
          BoxShadow(color: cur.color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final mouthUp = roll != null ? roll.shells[i] : true;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: CustomPaint(
                  size: const Size(26, 36),
                  painter: _PachisiShellPainter(mouthUp: mouthUp),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          if (game.awaitingRoll)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: (!isComputerTurn && game.winner == null) ? _roll : null,
                style: FilledButton.styleFrom(
                  backgroundColor: cur.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.casino, size: 20),
                label: Text(
                  "${cur.name.toUpperCase()} • ROLL SHELLS",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: cur.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Touch your glowing coin on the board to move',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = game.currentPlayer;
    final r = game.lastRoll?.value;

    return GameFrame(
      title: 'Pachisi',
      status: statusText,
      counters: [
        statCounter('LAST ROLL', r != null ? '$r' : '-'),
        statCounter('REACHED HOME', '${cur.pawnsHomeCount}/4'),
        statCounter('INNER LANE', cur.hasCaptured ? 'Unlocked' : 'Need Kill'),
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

class _PachisiShellPainter extends CustomPainter {
  final bool mouthUp;
  const _PachisiShellPainter({required this.mouthUp});

  @override
  void paint(Canvas canvas, Size size) {
    drawCowrieShell(canvas, Offset(size.width / 2, size.height / 2), size.width * 0.9, mouthUp);
  }

  @override
  bool shouldRepaint(covariant _PachisiShellPainter oldDelegate) => oldDelegate.mouthUp != mouthUp;
}
