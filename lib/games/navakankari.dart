import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class NavakankariConfig {
  final bool vsComputer;
  final int humanPlayer; // 1 = Gold, 2 = Jade
  final Difficulty difficulty;

  const NavakankariConfig({
    required this.vsComputer,
    required this.humanPlayer,
    required this.difficulty,
  });
}

// 24 Intersection Points across 3 concentric squares (normalized 0.0 to 6.0)
const List<Offset> kNavakankariPoints = [
  // Outer Square (0..7)
  Offset(0, 0), Offset(3, 0), Offset(6, 0),
  Offset(6, 3), Offset(6, 6), Offset(3, 6), Offset(0, 6), Offset(0, 3),
  // Middle Square (8..15)
  Offset(1, 1), Offset(3, 1), Offset(5, 1),
  Offset(5, 3), Offset(5, 5), Offset(3, 5), Offset(1, 5), Offset(1, 3),
  // Inner Square (16..23)
  Offset(2, 2), Offset(3, 2), Offset(4, 2),
  Offset(4, 3), Offset(4, 4), Offset(3, 4), Offset(2, 4), Offset(2, 3),
];

// The 16 possible 3-in-a-row Mills
const List<List<int>> kNavakankariMills = [
  // Outer Square
  [0, 1, 2], [2, 3, 4], [4, 5, 6], [6, 7, 0],
  // Middle Square
  [8, 9, 10], [10, 11, 12], [12, 13, 14], [14, 15, 8],
  // Inner Square
  [16, 17, 18], [18, 19, 20], [20, 21, 22], [22, 23, 16],
  // Cross Connector Midpoint Lines
  [1, 9, 17],   // Top
  [7, 15, 23],  // Left
  [3, 11, 19],  // Right
  [5, 13, 21],  // Bottom
];

// Adjacency connections
List<List<int>> _buildAdjacency() {
  final result = List.generate(24, (_) => <int>[]);
  for (final m in kNavakankariMills) {
    result[m[0]].add(m[1]);
    result[m[1]].add(m[0]);
    result[m[1]].add(m[2]);
    result[m[2]].add(m[1]);
  }
  return result.map((list) => list.toSet().toList()).toList();
}

final List<List<int>> kNavakankariNeighbors = _buildAdjacency();

class NavakankariGame {
  final NavakankariConfig config;
  final List<int> cells; // 0 = empty, 1 = Player 1 (Gold), 2 = Player 2 (Jade)
  final List<int> unplaced; // [9, 9] in Phase 1
  final List<int> onBoard; // Pieces alive on board [P1, P2]
  int turn; // 1 or 2
  bool mustRemove; // True when a mill was formed and player must remove opponent coin
  int? selected; // Currently selected coin to move
  int? winner;

  NavakankariGame(this.config)
      : cells = List.filled(24, 0),
        unplaced = [9, 9],
        onBoard = [0, 0],
        turn = 1,
        mustRemove = false,
        selected = null,
        winner = null;

  bool get isPlacingPhase => unplaced[0] > 0 || unplaced[1] > 0;
  bool isFlying(int player) => !isPlacingPhase && onBoard[player - 1] == 3;

  int get opponent => (turn == 1) ? 2 : 1;

  // Check if point forms part of an active mill for the given player
  bool isPartOfMill(int point, int player) {
    if (cells[point] != player) return false;
    for (final mill in kNavakankariMills) {
      if (mill.contains(point)) {
        if (cells[mill[0]] == player &&
            cells[mill[1]] == player &&
            cells[mill[2]] == player) {
          return true;
        }
      }
    }
    return false;
  }

  // Check if moving to/placing on [point] forms a brand new mill
  bool formsMill(int point, int player) {
    for (final mill in kNavakankariMills) {
      if (mill.contains(point)) {
        int count = 0;
        for (final p in mill) {
          if (p == point || cells[p] == player) count++;
        }
        if (count == 3) return true;
      }
    }
    return false;
  }

  List<int> validPlacements() {
    if (!isPlacingPhase || mustRemove || winner != null) return [];
    return [for (int i = 0; i < 24; i++) if (cells[i] == 0) i];
  }

  List<int> movablePieces() {
    if (isPlacingPhase || mustRemove || winner != null) return [];
    final player = turn;
    final list = <int>[];
    for (int i = 0; i < 24; i++) {
      if (cells[i] == player) {
        if (validMovesFor(i).isNotEmpty) list.add(i);
      }
    }
    return list;
  }

  List<int> validMovesFor(int from) {
    if (cells[from] != turn || mustRemove || winner != null) return [];
    if (isFlying(turn)) {
      // Phase 3: Flying to ANY empty vertex
      return [for (int i = 0; i < 24; i++) if (cells[i] == 0) i];
    }
    // Phase 2: Slide to adjacent empty neighbor
    return [
      for (final n in kNavakankariNeighbors[from])
        if (cells[n] == 0) n
    ];
  }

  List<int> removableOpponentPieces() {
    if (!mustRemove || winner != null) return [];
    final opp = opponent;
    final allOpp = <int>[];
    final nonMillOpp = <int>[];

    for (int i = 0; i < 24; i++) {
      if (cells[i] == opp) {
        allOpp.add(i);
        if (!isPartOfMill(i, opp)) {
          nonMillOpp.add(i);
        }
      }
    }
    // Standard rule: cannot remove a piece in a mill unless ALL opponent pieces are in mills!
    return nonMillOpp.isNotEmpty ? nonMillOpp : allOpp;
  }

  // Phase 1: Place a piece on empty point
  bool placePiece(int point) {
    if (cells[point] != 0 || unplaced[turn - 1] <= 0 || mustRemove) return false;

    cells[point] = turn;
    unplaced[turn - 1]--;
    onBoard[turn - 1]++;

    if (formsMill(point, turn)) {
      mustRemove = true;
      return true; // Formed mill!
    }

    _advanceTurn();
    return false;
  }

  // Phase 2 / 3: Move a piece
  bool movePiece(int from, int to) {
    if (cells[from] != turn || cells[to] != 0 || mustRemove) return false;
    if (!validMovesFor(from).contains(to)) return false;

    cells[from] = 0;
    cells[to] = turn;
    selected = null;

    if (formsMill(to, turn)) {
      mustRemove = true;
      return true; // Formed mill!
    }

    _advanceTurn();
    return false;
  }

  // Capture / Remove an opponent's piece
  bool removePiece(int point) {
    if (!mustRemove || cells[point] != opponent) return false;
    if (!removableOpponentPieces().contains(point)) return false;

    cells[point] = 0;
    onBoard[opponent - 1]--;
    mustRemove = false;
    selected = null;

    // Check Win: opponent down to 2 pieces in movement phase
    if (!isPlacingPhase && onBoard[opponent - 1] < 3) {
      winner = turn;
      return true;
    }

    _advanceTurn();
    return true;
  }

  void _advanceTurn() {
    selected = null;
    turn = opponent;

    // Check if player has no legal moves in movement phase (stalemate loss)
    if (!isPlacingPhase && movablePieces().isEmpty) {
      winner = opponent;
    }
  }
}

// ---------------------------------------------------------------------------
// NAVAKANKARI AI (Intelligent Heuristics)
// ---------------------------------------------------------------------------

class NavakankariAI {
  final Difficulty difficulty;
  final Random _rng = Random();

  NavakankariAI({required this.difficulty});

  int? pickPlacement(NavakankariGame g) {
    final valid = g.validPlacements();
    if (valid.isEmpty) return null;

    if (difficulty == Difficulty.easy && _rng.nextDouble() < 0.45) {
      return valid[_rng.nextInt(valid.length)];
    }

    // 1. Can AI complete a mill?
    for (final p in valid) {
      if (g.formsMill(p, g.turn)) return p;
    }

    // 2. Can AI block opponent's mill?
    final opp = g.opponent;
    for (final p in valid) {
      if (g.formsMill(p, opp)) return p;
    }

    // 3. Prefer intersections with 4 connections (midpoints)
    valid.sort((a, b) => kNavakankariNeighbors[b].length.compareTo(kNavakankariNeighbors[a].length));
    return valid.first;
  }

  MapEntry<int, int>? pickMove(NavakankariGame g) {
    final movables = g.movablePieces();
    if (movables.isEmpty) return null;

    final moves = <MapEntry<int, int>>[];
    for (final from in movables) {
      for (final to in g.validMovesFor(from)) {
        moves.add(MapEntry(from, to));
      }
    }
    if (moves.isEmpty) return null;

    if (difficulty == Difficulty.easy && _rng.nextDouble() < 0.45) {
      return moves[_rng.nextInt(moves.length)];
    }

    // 1. Prioritize completing a mill
    for (final m in moves) {
      if (g.formsMill(m.value, g.turn)) return m;
    }

    // 2. Prioritize blocking opponent mill
    final opp = g.opponent;
    for (final m in moves) {
      if (g.formsMill(m.value, opp)) return m;
    }

    moves.shuffle(_rng);
    return moves.first;
  }

  int? pickRemoval(NavakankariGame g) {
    final removable = g.removableOpponentPieces();
    if (removable.isEmpty) return null;

    // Prioritize pieces that could form mills on opponent's next turn
    final opp = g.opponent;
    for (final p in removable) {
      if (g.isPartOfMill(p, opp)) return p;
    }
    removable.shuffle(_rng);
    return removable.first;
  }
}

// ---------------------------------------------------------------------------
// BOARD CANVAS PAINTER (Ultra-Lightweight 100% Vector)
// ---------------------------------------------------------------------------

class NavakankariPainter extends CustomPainter {
  final NavakankariGame game;
  final int? selectedPoint;

  NavakankariPainter({required this.game, this.selectedPoint});

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.08;
    final boardSpan = size.width - 2 * pad;
    final step = boardSpan / 6.0;

    Offset toScreen(Offset gridPt) {
      return Offset(pad + gridPt.dx * step, pad + gridPt.dy * step);
    }

    // Background Parchment Cloth
    final bgPaint = Paint()..color = const Color(0xFFF7EBD2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF3B2A1A)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    // 1. Draw 3 Concentric Squares
    for (int tier = 0; tier < 3; tier++) {
      final rect = Rect.fromLTRB(
        pad + tier * step,
        pad + tier * step,
        pad + (6 - tier) * step,
        pad + (6 - tier) * step,
      );
      canvas.drawRect(rect, linePaint);
    }

    // 2. Draw 4 Midpoint Connector Lines
    canvas.drawLine(toScreen(const Offset(3, 0)), toScreen(const Offset(3, 2)), linePaint); // Top
    canvas.drawLine(toScreen(const Offset(0, 3)), toScreen(const Offset(2, 3)), linePaint); // Left
    canvas.drawLine(toScreen(const Offset(4, 3)), toScreen(const Offset(6, 3)), linePaint); // Right
    canvas.drawLine(toScreen(const Offset(3, 4)), toScreen(const Offset(3, 6)), linePaint); // Bottom

    // 3. Draw 24 Node Intersections
    final nodePaint = Paint()..color = const Color(0xFF4A3622);
    for (int i = 0; i < 24; i++) {
      canvas.drawCircle(toScreen(kNavakankariPoints[i]), step * 0.14, nodePaint);
    }

    // 4. Highlight Valid Move Target Dots if a piece is selected
    if (selectedPoint != null) {
      final targetPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.fill;
      for (final to in game.validMovesFor(selectedPoint!)) {
        canvas.drawCircle(toScreen(kNavakankariPoints[to]), step * 0.22, targetPaint);
      }
    }

    // 5. Draw Pieces
    final removable = game.mustRemove ? game.removableOpponentPieces() : <int>[];
    final movables = (!game.isPlacingPhase && !game.mustRemove) ? game.movablePieces() : <int>[];

    for (int i = 0; i < 24; i++) {
      final val = game.cells[i];
      if (val == 0) continue;

      final center = toScreen(kNavakankariPoints[i]);
      final radius = step * 0.38;

      final isGold = (val == 1);
      final coinColor = isGold ? const Color(0xFFFFD54F) : const Color(0xFF10B981);

      // Pulsing Glow on Movable Pieces
      if (movables.contains(i)) {
        canvas.drawCircle(
          center,
          radius * 1.35,
          Paint()
            ..color = coinColor.withOpacity(0.5)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          radius * 1.45,
          Paint()
            ..color = coinColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      // Red Pulsing Glow if piece is removable
      if (removable.contains(i)) {
        canvas.drawCircle(
          center,
          radius * 1.5,
          Paint()
            ..color = const Color(0xFFFF1744).withOpacity(0.6)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          radius * 1.6,
          Paint()
            ..color = const Color(0xFFFF1744)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2,
        );
      }

      // Selected Halo
      if (selectedPoint == i) {
        canvas.drawCircle(
          center,
          radius * 1.5,
          Paint()
            ..color = const Color(0xFF00E676)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
      }

      // Coin Shadow & Face
      canvas.drawCircle(center + const Offset(1, 2), radius, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(center, radius, Paint()..color = coinColor);

      // Border & Metallic Inner Ring
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(
        center,
        radius * 0.65,
        Paint()..color = Colors.white.withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NavakankariPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// NAVAKANKARI SCREEN
// ---------------------------------------------------------------------------

class NavakankariScreen extends StatefulWidget {
  final NavakankariConfig config;
  const NavakankariScreen({super.key, required this.config});

  @override
  State<NavakankariScreen> createState() => _NavakankariScreenState();
}

class _NavakankariScreenState extends State<NavakankariScreen> {
  late NavakankariGame game;
  bool _thinking = false;
  int _gen = 0;

  NavakankariConfig get config => widget.config;

  bool get isComputerTurn =>
      config.vsComputer && game.winner == null && game.turn != config.humanPlayer;

  @override
  void initState() {
    super.initState();
    game = NavakankariGame(config);
    _maybeComputerMove();
  }

  void restart() {
    _gen++;
    _thinking = false;
    setState(() {
      game = NavakankariGame(config);
    });
    _maybeComputerMove();
  }

  void _tapPoint(int index) {
    if (isComputerTurn || game.winner != null) return;

    setState(() {
      if (game.mustRemove) {
        // Removal Phase
        if (game.removePiece(index)) {
          Sound.play(Sfx.capture);
          Haptics.heavy();
        }
      } else if (game.isPlacingPhase) {
        // Placement Phase
        final millFormed = game.placePiece(index);
        if (millFormed) {
          Sound.play(Sfx.win);
          Haptics.heavy();
        } else {
          Sound.play(Sfx.place);
          Haptics.light();
        }
      } else {
        // Movement Phase
        if (game.selected == null) {
          if (game.cells[index] == game.turn && game.validMovesFor(index).isNotEmpty) {
            game.selected = index;
            Sound.play(Sfx.select);
            Haptics.tick();
          }
        } else {
          if (game.selected == index) {
            game.selected = null; // Deselect
          } else if (game.cells[index] == game.turn) {
            game.selected = index; // Switch selected piece
            Sound.play(Sfx.select);
          } else {
            final millFormed = game.movePiece(game.selected!, index);
            if (millFormed) {
              Sound.play(Sfx.win);
              Haptics.heavy();
            } else {
              Sound.play(Sfx.move);
              Haptics.light();
            }
          }
        }
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

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || token != _gen) return;

      final ai = NavakankariAI(difficulty: config.difficulty);
      setState(() {
        if (game.mustRemove) {
          final pt = ai.pickRemoval(game);
          if (pt != null) {
            game.removePiece(pt);
            Sound.play(Sfx.capture);
            Haptics.heavy();
          }
        } else if (game.isPlacingPhase) {
          final pt = ai.pickPlacement(game);
          if (pt != null) {
            final mill = game.placePiece(pt);
            if (mill) {
              Sound.play(Sfx.win);
            } else {
              Sound.play(Sfx.place);
            }
          }
        } else {
          final move = ai.pickMove(game);
          if (move != null) {
            final mill = game.movePiece(move.key, move.value);
            if (mill) {
              Sound.play(Sfx.win);
            } else {
              Sound.play(Sfx.move);
            }
          }
        }
        _thinking = false;
      });

      if (game.winner != null) {
        final humanWon = !config.vsComputer || game.winner == config.humanPlayer;
        Sound.play(humanWon ? Sfx.win : Sfx.lose);
        Haptics.heavy();
        return;
      }

      // If computer formed a mill, it must take its removal action immediately
      if (isComputerTurn && game.mustRemove) {
        _maybeComputerMove();
      }
    });
  }

  String get statusText {
    if (game.winner != null) {
      final name = (game.winner == 1) ? 'Gold' : 'Jade';
      if (config.vsComputer) {
        return (game.winner == config.humanPlayer) ? 'You win!' : '$name (Computer) wins!';
      }
      return '$name wins!';
    }
    if (isComputerTurn) {
      final name = (game.turn == 1) ? 'Gold' : 'Jade';
      return '$name (Computer) is thinking…';
    }

    final name = (game.turn == 1) ? 'Gold' : 'Jade';
    if (game.mustRemove) {
      return 'MILL FORMED! 🎯 Touch an opponent coin to capture';
    }
    if (game.isPlacingPhase) {
      final left = game.unplaced[game.turn - 1];
      return "$name's turn: place a coin ($left left)";
    }
    if (game.isFlying(game.turn)) {
      return "$name is FLYING! 🦅 Touch anywhere to fly";
    }
    return "$name's turn: touch a glowing coin to slide";
  }

  Widget boardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight) * 0.94;
        final pad = boardSize * 0.08;
        final step = (boardSize - 2 * pad) / 6.0;

        return Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final tap = details.localPosition;
                // Find closest point within touch radius
                int? closest;
                double minDist = step * 0.45;

                for (int i = 0; i < 24; i++) {
                  final pt = kNavakankariPoints[i];
                  final screenPt = Offset(pad + pt.dx * step, pad + pt.dy * step);
                  final dist = (tap - screenPt).distance;
                  if (dist < minDist) {
                    minDist = dist;
                    closest = i;
                  }
                }

                if (closest != null) {
                  _tapPoint(closest);
                }
              },
              child: CustomPaint(
                size: Size(boardSize, boardSize),
                painter: NavakankariPainter(
                  game: game,
                  selectedPoint: game.selected,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goldOnBoard = game.onBoard[0];
    final jadeOnBoard = game.onBoard[1];
    final phase = game.isPlacingPhase ? 'Place' : (game.isFlying(game.turn) ? 'Fly' : 'Slide');

    return GameFrame(
      title: 'Navakankari',
      status: statusText,
      counters: [
        statCounter('GOLD PIECES', game.isPlacingPhase ? '${game.unplaced[0]} left' : '$goldOnBoard alive'),
        statCounter('JADE PIECES', game.isPlacingPhase ? '${game.unplaced[1]} left' : '$jadeOnBoard alive'),
        statCounter('PHASE', phase),
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
