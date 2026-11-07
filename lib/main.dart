import 'theme/app_theme.dart';
import 'models/game_definition.dart';
import 'models/game_registry.dart';
import 'screens/hub_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/game_setup_sheet.dart';
import 'ashta_chamma.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, AssetSource, PlayerMode, ReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hide the phone's status bar and buttons while the game is open.
  // (Swipe from the top or bottom edge to show them again.)
  if (fullScreenApp) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  await AppSettings.load();
  await Sound.init();
  runApp(const PuliMekaApp());
}

class PuliMekaApp extends StatelessWidget {
  const PuliMekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heritage Board Games',
      theme: AppTheme.themeData,
      home: Builder(
        builder: (context) => HubScreen(
          games: GameRegistry.getGames(context),
          onOpenSettings: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppTheme.bgSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const SettingsSheet(),
            );
          },
          soundNotifier: AppSettings.soundOn,
          vibrationNotifier: AppSettings.vibrationOn,
          onToggleSound: AppSettings.setSound,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS YOU CAN CHANGE
// ---------------------------------------------------------------------------

// true = the app uses the whole screen (no status bar or button bar).
const bool fullScreenApp = true;

// Three Pawns: what happens when a player cannot move at all?
// true = that player loses, false = the game is a draw.
const bool blockedPlayerLoses = true;

// ---------------------------------------------------------------------------
// BASIC TYPES
// ---------------------------------------------------------------------------

const int kEmpty = 0;
const int kTiger = 1;
const int kGoat = 2;

enum Side { tiger, goat }

// The games in the app.
enum GameKind { puli, threePawns, ashtaChamma }

// Easy, Medium and Hard for the computer opponent.
// "Depth" is how many moves ahead the computer thinks, and "mistake" is the
// chance that it plays a random move instead of its best one.
// Change these numbers to make a difficulty easier or harder.
enum Difficulty {
  //     name      Puli Meka          Three Pawns
  easy('Easy', 1, 0.50, 2, 0.40),
  medium('Medium', 3, 0.10, 4, 0.10),
  hard('Hard', 4, 0.00, 7, 0.00);

  const Difficulty(this.label, this.puliDepth, this.puliMistake,
      this.threeDepth, this.threeMistake);

  final String label;
  final int puliDepth;
  final double puliMistake;
  final int threeDepth;
  final double threeMistake;
}

class Jump {
  final int over;
  final int to;
  const Jump(this.over, this.to);
}

class Move {
  final int from; // -1 means "place a new piece on the board"
  final int to;
  final int captured; // -1 when nothing is captured
  const Move(this.from, this.to, [this.captured = -1]);
}

// Settings for one game of Puli Meka.
class GameConfig {
  final bool vsComputer;
  final Side humanSide;
  final BoardDef board;
  final Difficulty difficulty;
  GameConfig({
    required this.vsComputer,
    required this.humanSide,
    required this.board,
    required this.difficulty,
  });
}

// Settings for one game of Three Pawns.
class ThreeConfig {
  final bool vsComputer;
  final int humanPlayer; // 1 = plays first (orange), 2 = plays second (blue)
  final Difficulty difficulty;
  ThreeConfig({
    required this.vsComputer,
    required this.humanPlayer,
    required this.difficulty,
  });
}

// ---------------------------------------------------------------------------
// SETTINGS, SOUND AND VIBRATION
// ---------------------------------------------------------------------------

// Remembers the sound and vibration switches on the phone.
class AppSettings {
  static final ValueNotifier<bool> soundOn = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> vibrationOn = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      soundOn.value = prefs.getBool('sound_on') ?? true;
      vibrationOn.value = prefs.getBool('vibration_on') ?? true;
    } catch (_) {}
  }

  static Future<void> setSound(bool value) async {
    soundOn.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_on', value);
    } catch (_) {}
  }

  static Future<void> setVibration(bool value) async {
    vibrationOn.value = value;
    if (value) HapticFeedback.mediumImpact();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vibration_on', value);
    } catch (_) {}
  }
}

enum Sfx { place, move, select, capture, win, lose }

// Plays the sound files from assets/sounds. If a file is missing the game
// simply stays silent instead of crashing.
class Sound {
  static const Map<Sfx, String> _files = {
    Sfx.place: 'sounds/place.wav',
    Sfx.move: 'sounds/move.wav',
    Sfx.select: 'sounds/select.wav',
    Sfx.capture: 'sounds/capture.wav',
    Sfx.win: 'sounds/win.wav',
    Sfx.lose: 'sounds/lose.wav',
  };
  static final Map<Sfx, AudioPlayer> _players = {};

  static Future<void> init() async {
    for (final entry in _files.entries) {
      try {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        _players[entry.key] = player;
      } catch (_) {}
    }
  }

  static Future<void> play(Sfx sfx) async {
    if (!AppSettings.soundOn.value) return;
    final player = _players[sfx];
    final file = _files[sfx];
    if (player == null || file == null) return;
    try {
      await player.stop();
      await player.play(AssetSource(file));
    } catch (_) {}
  }
}

class Haptics {
  static void tick() {
    if (AppSettings.vibrationOn.value) HapticFeedback.selectionClick();
  }

  static void light() {
    if (AppSettings.vibrationOn.value) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (AppSettings.vibrationOn.value) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (AppSettings.vibrationOn.value) HapticFeedback.heavyImpact();
  }
}

// ---------------------------------------------------------------------------
// BOARD DEFINITION
// A board is just data: points, lines, where the tigers start, goat count.
// (Adding the second board later only means adding another BoardDef.)
// ---------------------------------------------------------------------------

class BoardDef {
  final String name;
  final List<Offset> points; // used for drawing only
  final List<List<int>> lines; // every straight line, point by point
  final List<int> startTigers;
  final int totalGoats;
  final int goatsToWin; // tigers win when this many goats are captured
  final List<List<int>> neighbors;
  final List<List<Jump>> jumps;

  BoardDef({
    required this.name,
    required this.points,
    required this.lines,
    required this.startTigers,
    required this.totalGoats,
    required this.goatsToWin,
  })  : neighbors = _buildNeighbors(points, lines),
        jumps = _buildJumps(points, lines);

  late final double minX =
      points.map((p) => p.dx).reduce((a, b) => min(a, b));
  late final double minY =
      points.map((p) => p.dy).reduce((a, b) => min(a, b));
  late final double width =
      points.map((p) => p.dx).reduce((a, b) => max(a, b)) - minX;
  late final double height =
      points.map((p) => p.dy).reduce((a, b) => max(a, b)) - minY;

  static List<List<int>> _buildNeighbors(
      List<Offset> points, List<List<int>> lines) {
    final result = List.generate(points.length, (_) => <int>[]);
    for (final line in lines) {
      for (int i = 0; i < line.length - 1; i++) {
        result[line[i]].add(line[i + 1]);
        result[line[i + 1]].add(line[i]);
      }
    }
    return result;
  }

  static List<List<Jump>> _buildJumps(
      List<Offset> points, List<List<int>> lines) {
    final result = List.generate(points.length, (_) => <Jump>[]);
    for (final line in lines) {
      for (int i = 0; i < line.length - 2; i++) {
        result[line[i]].add(Jump(line[i + 1], line[i + 2]));
        result[line[i + 2]].add(Jump(line[i + 1], line[i]));
      }
    }
    return result;
  }
}

// The 23-point Puli Meka board.
final BoardDef puliMekaBoard = BoardDef(
  name: 'Puli Meka',
  points: const [
    Offset(545, 180), // 0  apex
    Offset(264, 395), // 1  row 1
    Offset(432, 395), // 2
    Offset(514, 395), // 3
    Offset(575, 395), // 4
    Offset(651, 395), // 5
    Offset(829, 395), // 6
    Offset(264, 497), // 7  row 2
    Offset(381, 497), // 8
    Offset(499, 497), // 9
    Offset(585, 497), // 10
    Offset(702, 497), // 11
    Offset(829, 497), // 12
    Offset(264, 594), // 13 row 3
    Offset(330, 594), // 14
    Offset(483, 594), // 15
    Offset(600, 594), // 16
    Offset(753, 594), // 17
    Offset(829, 594), // 18
    Offset(274, 711), // 19 row 4
    Offset(468, 711), // 20
    Offset(615, 711), // 21
    Offset(815, 711), // 22
  ],
  lines: const [
    [0, 2, 8, 14, 19], // left outer line from the apex
    [0, 3, 9, 15, 20], // left inner line
    [0, 4, 10, 16, 21], // right inner line
    [0, 5, 11, 17, 22], // right outer line
    [1, 2, 3, 4, 5, 6], // row 1
    [7, 8, 9, 10, 11, 12], // row 2
    [13, 14, 15, 16, 17, 18], // row 3
    [19, 20, 21, 22], // row 4 (bottom)
    [1, 7, 13], // left side
    [6, 12, 18], // right side
  ],
  startTigers: const [0, 3, 4],
  totalGoats: 15,
  goatsToWin: 15,
);

// ---------------------------------------------------------------------------
// GAME RULES (no drawing code in here)
// ---------------------------------------------------------------------------

class PuliGame {
  final BoardDef board;
  final List<int> cells;
  final int goatsToWin;
  int goatsToPlace;
  int goatsCaptured;
  Side turn;
  Side? winner;
  int? selected; // only used by the screen

  PuliGame(this.board, {int? goatsToWin})
      : cells = List.filled(board.points.length, kEmpty),
        goatsToWin = goatsToWin ?? board.goatsToWin,
        goatsToPlace = board.totalGoats,
        goatsCaptured = 0,
        turn = Side.goat {
    for (final t in board.startTigers) {
      cells[t] = kTiger;
    }
  }

  PuliGame.copy(PuliGame o)
      : board = o.board,
        cells = List.of(o.cells),
        goatsToWin = o.goatsToWin,
        goatsToPlace = o.goatsToPlace,
        goatsCaptured = o.goatsCaptured,
        turn = o.turn,
        winner = o.winner;

  int get tigerCount => board.startTigers.length;
  bool get placing => goatsToPlace > 0;

  int tigerMoveCount(int i) {
    int count = 0;
    for (final n in board.neighbors[i]) {
      if (cells[n] == kEmpty) count++;
    }
    for (final j in board.jumps[i]) {
      if (cells[j.over] == kGoat && cells[j.to] == kEmpty) count++;
    }
    return count;
  }

  int get tigersCornered {
    int count = 0;
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == kTiger && tigerMoveCount(i) == 0) count++;
    }
    return count;
  }

  bool get goatsHaveAMove {
    if (placing) return true;
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != kGoat) continue;
      for (final n in board.neighbors[i]) {
        if (cells[n] == kEmpty) return true;
      }
    }
    return false;
  }

  // Every move the side to play is allowed to make.
  List<Move> legalMoves() {
    final moves = <Move>[];
    if (turn == Side.goat) {
      if (placing) {
        for (int i = 0; i < cells.length; i++) {
          if (cells[i] == kEmpty) moves.add(Move(-1, i));
        }
      } else {
        for (int i = 0; i < cells.length; i++) {
          if (cells[i] != kGoat) continue;
          for (final n in board.neighbors[i]) {
            if (cells[n] == kEmpty) moves.add(Move(i, n));
          }
        }
      }
    } else {
      for (int i = 0; i < cells.length; i++) {
        if (cells[i] != kTiger) continue;
        for (final n in board.neighbors[i]) {
          if (cells[n] == kEmpty) moves.add(Move(i, n));
        }
        for (final j in board.jumps[i]) {
          if (cells[j.over] == kGoat && cells[j.to] == kEmpty) {
            moves.add(Move(i, j.to, j.over));
          }
        }
      }
    }
    return moves;
  }

  // Points the piece on [from] can move to (used to show green rings).
  List<int> targetsFor(int from) {
    return [
      for (final m in legalMoves())
        if (m.from == from) m.to
    ];
  }

  void apply(Move m) {
    if (turn == Side.goat) {
      if (m.from == -1) {
        cells[m.to] = kGoat;
        goatsToPlace--;
      } else {
        cells[m.from] = kEmpty;
        cells[m.to] = kGoat;
      }
    } else {
      cells[m.from] = kEmpty;
      cells[m.to] = kTiger;
      if (m.captured != -1) {
        cells[m.captured] = kEmpty;
        goatsCaptured++;
      }
    }
    selected = null;
    turn = (turn == Side.goat) ? Side.tiger : Side.goat;
    _checkWinner();
  }

  void _checkWinner() {
    if (goatsCaptured >= goatsToWin) {
      winner = Side.tiger;
    } else if (turn == Side.tiger && tigersCornered == tigerCount) {
      winner = Side.goat;
    } else if (turn == Side.goat && !goatsHaveAMove) {
      winner = Side.tiger;
    }
  }

  // A human tapped a point. Returns the move to play, or null when the tap
  // only selected a piece (or did nothing). The screen plays the move, so it
  // can animate it.
  Move? tap(int index) {
    if (winner != null) return null;
    if (turn == Side.goat && placing) {
      return cells[index] == kEmpty ? Move(-1, index) : null;
    }
    final mine = (turn == Side.goat) ? kGoat : kTiger;
    if (cells[index] == mine) {
      selected = index;
      return null;
    }
    final from = selected;
    if (from == null) return null;
    for (final m in legalMoves()) {
      if (m.from == from && m.to == index) return m;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// COMPUTER PLAYER
// Looks a few moves ahead ("minimax with alpha-beta") and picks the move
// that leads to the best position for its side.
// ---------------------------------------------------------------------------

class ComputerPlayer {
  final int depth;
  final double mistakeChance;
  final Random _random = Random();

  ComputerPlayer({required this.depth, this.mistakeChance = 0});

  Move? chooseMove(PuliGame game) {
    final moves = game.legalMoves();
    if (moves.isEmpty) return null;
    moves.shuffle(_random); // so the computer does not always play the same
    // On easy levels the computer sometimes just plays a random move.
    if (mistakeChance > 0 && _random.nextDouble() < mistakeChance) {
      return moves.first;
    }

    final bool goatsMove = game.turn == Side.goat;
    Move best = moves.first;
    double bestScore = goatsMove ? double.negativeInfinity : double.infinity;

    for (final m in moves) {
      final next = PuliGame.copy(game)..apply(m);
      final score = _search(
          next, depth - 1, double.negativeInfinity, double.infinity);
      if (goatsMove ? score > bestScore : score < bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best;
  }

  // Positive numbers are good for the goats, negative for the tigers.
  double _search(PuliGame g, int d, double alpha, double beta) {
    final w = g.winner;
    if (w != null) {
      return w == Side.goat ? 10000.0 + d : -10000.0 - d;
    }
    if (d == 0) return _evaluate(g);
    final moves = g.legalMoves();
    if (moves.isEmpty) return _evaluate(g);

    if (g.turn == Side.goat) {
      double best = double.negativeInfinity;
      for (final m in moves) {
        final v = _search(PuliGame.copy(g)..apply(m), d - 1, alpha, beta);
        best = max(best, v);
        alpha = max(alpha, best);
        if (alpha >= beta) break;
      }
      return best;
    } else {
      double best = double.infinity;
      for (final m in moves) {
        final v = _search(PuliGame.copy(g)..apply(m), d - 1, alpha, beta);
        best = min(best, v);
        beta = min(beta, best);
        if (alpha >= beta) break;
      }
      return best;
    }
  }

  double _evaluate(PuliGame g) {
    double score = 0;
    score -= g.goatsCaptured * 150; // every captured goat is bad for goats
    score += g.tigersCornered * 90; // every trapped tiger is good for goats
    int mobility = 0;
    for (int i = 0; i < g.cells.length; i++) {
      if (g.cells[i] == kTiger) mobility += g.tigerMoveCount(i);
    }
    score -= mobility * 6; // tigers with many options are dangerous
    return score;
  }
}

// ---------------------------------------------------------------------------
// TIGER AND GOAT ARTWORK
// Drawn with code, so no image files are needed. Each function draws a face
// that fits inside a circle of radius 1 around the point (0, 0). Call them
// after translate() and scale(), as ArtPainter below does.
// ---------------------------------------------------------------------------

const Color _ink = Color(0xFF2A1A0E);
const Color _tigerOrange = Color(0xFFF28C28);
const Color _goatTan = Color(0xFFE3C99A);
const Color _goatLight = Color(0xFFF7EBD2);
const Color _hornColor = Color(0xFFF1E6C8);

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double width) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

Offset _cubic(Offset a, Offset b, Offset c, Offset d, double t) {
  final u = 1 - t;
  return a * (u * u * u) +
      b * (3 * u * u * t) +
      c * (3 * u * t * t) +
      d * (t * t * t);
}

void drawTigerFace(Canvas canvas) {
  const cream = Color(0xFFFFF4E0);

  // ears
  for (final s in [-1.0, 1.0]) {
    canvas.drawCircle(Offset(0.62 * s, -0.68), 0.34, _fill(_tigerOrange));
    canvas.drawCircle(Offset(0.62 * s, -0.68), 0.34, _stroke(_ink, 0.05));
    canvas.drawCircle(
        Offset(0.62 * s, -0.66), 0.17, _fill(const Color(0xFFE8A0A0)));
  }

  // face
  canvas.drawCircle(const Offset(0, 0.06), 0.88, _fill(_tigerOrange));

  // stripes
  canvas.drawLine(const Offset(0, -0.8), const Offset(0, -0.5), _stroke(_ink, 0.10));
  for (final s in [-1.0, 1.0]) {
    final stripe = _stroke(_ink, 0.08);
    canvas.drawLine(Offset(0.30 * s, -0.74), Offset(0.22 * s, -0.50), stripe);
    canvas.drawLine(Offset(0.86 * s, 0.00), Offset(0.58 * s, 0.06), stripe);
    canvas.drawLine(Offset(0.84 * s, 0.28), Offset(0.58 * s, 0.26), stripe);
  }

  // muzzle
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.42), width: 0.84, height: 0.60),
      _fill(cream));

  // eyes
  for (final s in [-1.0, 1.0]) {
    final eye = Offset(0.33 * s, -0.08);
    final eyeRect = Rect.fromCenter(center: eye, width: 0.30, height: 0.20);
    canvas.drawOval(eyeRect, _fill(const Color(0xFFFFE45C)));
    canvas.drawOval(eyeRect, _stroke(_ink, 0.03));
    canvas.drawOval(
        Rect.fromCenter(center: eye, width: 0.06, height: 0.17), _fill(_ink));
  }

  // nose and mouth
  final nose = Path()
    ..moveTo(-0.13, 0.27)
    ..lineTo(0.13, 0.27)
    ..lineTo(0, 0.40)
    ..close();
  canvas.drawPath(nose, _fill(const Color(0xFF8A3B3B)));
  canvas.drawLine(const Offset(0, 0.40), const Offset(0, 0.50), _stroke(_ink, 0.04));
  for (final s in [-1.0, 1.0]) {
    final mouth = Path()
      ..moveTo(0, 0.50)
      ..quadraticBezierTo(0.05 * s, 0.68, 0.22 * s, 0.58);
    canvas.drawPath(mouth, _stroke(_ink, 0.04));
  }

  // outline
  canvas.drawCircle(const Offset(0, 0.06), 0.88, _stroke(_ink, 0.05));
}

void _drawHorn(Canvas canvas, double s) {
  final a = Offset(0.30 * s, -0.72);
  final b = Offset(0.34 * s, -1.00);
  final c = Offset(0.62 * s, -1.12);
  final d = Offset(0.92 * s, -0.86);
  const steps = 60;

  // dark outline first, then the ivory horn on top (thick at the base,
  // thin at the tip)
  for (final outline in [true, false]) {
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final radius = 0.13 - 0.10 * t + (outline ? 0.03 : 0.0);
      canvas.drawCircle(_cubic(a, b, c, d, t), radius,
          _fill(outline ? _ink : _hornColor));
    }
  }

  // ridges across the horn
  for (final t in [0.3, 0.5, 0.7]) {
    final p = _cubic(a, b, c, d, t);
    final q = _cubic(a, b, c, d, t + 0.02);
    final dir = q - p;
    final normal = Offset(-dir.dy, dir.dx) / dir.distance;
    final w = 0.13 - 0.10 * t;
    canvas.drawLine(p - normal * w, p + normal * w,
        _stroke(const Color(0xFFC9B88F), 0.025));
  }
}

void drawGoatFace(Canvas canvas) {
  for (final s in [-1.0, 1.0]) {
    _drawHorn(canvas, s);

    // ear
    canvas.save();
    canvas.translate(0.84 * s, -0.02);
    canvas.rotate(0.35 * s);
    final ear = Rect.fromCenter(center: Offset.zero, width: 0.56, height: 0.26);
    canvas.drawOval(ear, _fill(_goatTan));
    canvas.drawOval(ear, _stroke(_ink, 0.04));
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 0.34, height: 0.12),
        _fill(const Color(0xFFE8A99A)));
    canvas.restore();
  }

  // beard first, so the chin covers its top and only the tuft shows
  final beard = Path()
    ..moveTo(-0.20, 0.80)
    ..lineTo(0.20, 0.80)
    ..lineTo(0, 1.20)
    ..close();
  canvas.drawPath(beard, _fill(_goatLight));
  canvas.drawPath(beard, _stroke(_ink, 0.035));

  // face and muzzle
  final face = Rect.fromCenter(center: const Offset(0, 0.08), width: 1.6, height: 1.8);
  canvas.drawOval(face, _fill(_goatTan));
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.55), width: 0.76, height: 0.58),
      _fill(_goatLight));

  // eyes (goats have sideways pupils) and nostrils
  for (final s in [-1.0, 1.0]) {
    final eye = Offset(0.32 * s, -0.10);
    final eyeRect = Rect.fromCenter(center: eye, width: 0.30, height: 0.20);
    canvas.drawOval(eyeRect, _fill(const Color(0xFFF2C14E)));
    canvas.drawOval(eyeRect, _stroke(_ink, 0.03));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: eye, width: 0.18, height: 0.05),
            const Radius.circular(0.02)),
        _fill(_ink));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(0.10 * s, 0.50), width: 0.10, height: 0.07),
        _fill(_ink));
  }

  // mouth
  final mouth = Path()
    ..moveTo(-0.14, 0.70)
    ..quadraticBezierTo(0, 0.78, 0.14, 0.70);
  canvas.drawPath(mouth, _stroke(_ink, 0.04));

  // outline
  canvas.drawOval(face, _stroke(_ink, 0.05));
}

// The logo: left half tiger, right half goat.
void drawSplitLogo(Canvas canvas) {
  canvas.save();
  canvas.clipRect(const Rect.fromLTRB(-2, -2, 0, 2));
  drawTigerFace(canvas);
  canvas.restore();

  canvas.save();
  canvas.clipRect(const Rect.fromLTRB(0, -2, 2, 2));
  drawGoatFace(canvas);
  canvas.restore();

  canvas.drawLine(const Offset(0, -0.80), const Offset(0, 0.94), _stroke(_ink, 0.03));
}

const Color kPlayer1Color = Color(0xFFF28C28); // orange
const Color kPlayer2Color = Color(0xFF4AA8E0); // blue

// A pawn, for the Three Pawns game.
void drawPawn(Canvas canvas, Color color) {
  final dark = Color.lerp(color, const Color(0xFF000000), 0.35)!;

  // shadow on the ground
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.84), width: 1.6, height: 0.4),
      _fill(const Color(0x33000000)));

  // base
  final baseRect =
      Rect.fromCenter(center: const Offset(0, 0.62), width: 1.5, height: 0.5);
  canvas.drawOval(baseRect, _fill(dark));
  canvas.drawOval(baseRect, _stroke(_ink, 0.05));

  // body
  final body = Path()
    ..moveTo(-0.55, 0.62)
    ..quadraticBezierTo(-0.15, 0.25, -0.22, -0.05)
    ..lineTo(0.22, -0.05)
    ..quadraticBezierTo(0.15, 0.25, 0.55, 0.62)
    ..close();
  canvas.drawPath(body, _fill(color));
  canvas.drawPath(body, _stroke(_ink, 0.05));

  // collar and head
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -0.05), width: 0.7, height: 0.22),
      _fill(dark));
  canvas.drawCircle(const Offset(0, -0.40), 0.38, _fill(color));
  canvas.drawCircle(const Offset(0, -0.40), 0.38, _stroke(_ink, 0.05));

  // shine
  canvas.drawOval(
      Rect.fromCenter(center: const Offset(-0.12, -0.52), width: 0.2, height: 0.14),
      _fill(const Color(0x88FFFFFF)));
}

enum Art { tiger, goat, logo, pawns, pawnA, pawnB, shells }

// Lets you put the artwork anywhere in the app as a normal widget:
//   const SizedBox(width: 56, height: 56, child: CustomPaint(painter: ArtPainter(Art.tiger)))
class ArtPainter extends CustomPainter {
  final Art art;
  const ArtPainter(this.art);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(min(size.width, size.height) / 2 * 0.85);
    switch (art) {
      case Art.tiger:
        drawTigerFace(canvas);
      case Art.goat:
        drawGoatFace(canvas);
      case Art.logo:
        drawSplitLogo(canvas);
      case Art.pawnA:
        drawPawn(canvas, kPlayer1Color);
      case Art.pawnB:
        drawPawn(canvas, kPlayer2Color);
      case Art.pawns:
        canvas.save();
        canvas.translate(-0.5, 0.05);
        canvas.scale(0.78);
        drawPawn(canvas, kPlayer1Color);
        canvas.restore();
        canvas.save();
        canvas.translate(0.5, 0.05);
        canvas.scale(0.78);
        drawPawn(canvas, kPlayer2Color);
        canvas.restore();
      case Art.shells:
        canvas.save();
        canvas.translate(-0.4, 0);
        drawCowrieShell(canvas, Offset.zero, 0.52, true);
        canvas.restore();
        canvas.save();
        canvas.translate(0.4, 0);
        drawCowrieShell(canvas, Offset.zero, 0.52, false);
        canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArtPainter oldDelegate) => oldDelegate.art != art;
}

// ---------------------------------------------------------------------------
// BOARD LAYOUT: fits the board to ANY screen size
// The board is stretched to fill the space it is given (a little more
// vertically than horizontally on tall phones), and the pieces are sized
// from the closest pair of points so they never overlap.
// ---------------------------------------------------------------------------

// How much of the free space the board uses (1.0 = all of it).
// Make it smaller, for example 0.8, if the board still feels too big.
const double boardFill = 0.9;

// How much taller than wide the board may be stretched (1.0 = original shape).
const double maxStretch = 1.25;

class BoardLayout {
  final double sx; // horizontal scale
  final double sy; // vertical scale
  final double ox; // horizontal offset
  final double oy; // vertical offset
  final double pieceRadius;

  const BoardLayout._(this.sx, this.sy, this.ox, this.oy, this.pieceRadius);

  factory BoardLayout(BoardDef b, Size size,
      {double stretch = maxStretch,
      double radiusFactor = 0.45,
      double maxRadius = 46.0}) {
    // First pass finds the piece size, second pass leaves room for pieces
    // that sit on the edge of the board.
    final first = _compute(b, size, 0.05 * min(size.width, size.height),
        stretch, radiusFactor, maxRadius);
    return _compute(b, size, first.pieceRadius * 1.25 + 4, stretch,
        radiusFactor, maxRadius);
  }

  static BoardLayout _compute(BoardDef b, Size size, double margin,
      double stretch, double radiusFactor, double maxRadius) {
    final availW = max(1.0, (size.width - 2 * margin) * boardFill);
    final availH = max(1.0, (size.height - 2 * margin) * boardFill);
    double sx = availW / b.width;
    double sy = availH / b.height;

    // Do not stretch the board too much on very wide or very tall screens.
    if (sy > sx * stretch) sy = sx * stretch;
    if (sx > sy * stretch) sx = sy * stretch;

    final ox = (size.width - b.width * sx) / 2 - b.minX * sx;
    final oy = (size.height - b.height * sy) / 2 - b.minY * sy;

    // Piece size from the closest pair of connected points.
    double minDist = double.infinity;
    for (final line in b.lines) {
      for (int i = 0; i < line.length - 1; i++) {
        final p = b.points[line[i]];
        final q = b.points[line[i + 1]];
        final d = Offset((p.dx - q.dx) * sx, (p.dy - q.dy) * sy).distance;
        if (d < minDist) minDist = d;
      }
    }
    final radius = min(minDist * radiusFactor, maxRadius);
    return BoardLayout._(sx, sy, ox, oy, radius);
  }

  // Converts a board coordinate to a position on the screen.
  Offset toScreen(Offset p) => Offset(p.dx * sx + ox, p.dy * sy + oy);
}

// Finds which board point (if any) was tapped.
int? pointAt(BoardDef b, BoardLayout layout, Offset tap) {
  int? best;
  double bestDistance = max(26.0, layout.pieceRadius * 1.5);
  for (int i = 0; i < b.points.length; i++) {
    final d = (layout.toScreen(b.points[i]) - tap).distance;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

// Describes the move that is being animated right now.
class MoveAnim {
  final Move move;
  final Side mover;
  const MoveAnim(this.move, this.mover);
}

class BoardPainter extends CustomPainter {
  final PuliGame game;
  final MoveAnim? moveAnim;
  final Animation<double>? animation;

  BoardPainter(this.game, {this.moveAnim, this.animation})
      : super(repaint: animation);

  void _drawPiece(Canvas canvas, Offset c, double r, int value,
      double lineWidth,
      {bool selected = false, double scale = 1.0}) {
    final rr = r * scale;
    // dark base so the face stands out from the board
    canvas.drawCircle(c, rr * 1.05, Paint()..color = const Color(0x8C000000));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(rr * 0.85);
    if (value == kTiger) {
      drawTigerFace(canvas);
    } else {
      drawGoatFace(canvas);
    }
    canvas.restore();
    // ring: green when selected
    canvas.drawCircle(
      c,
      rr * 1.05,
      Paint()
        ..color =
            selected ? const Color(0xFF55E07A) : const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? lineWidth : 1.5,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final b = game.board;
    final layout = BoardLayout(b, size);
    final r = layout.pieceRadius;
    final lineWidth = max(3.0, r * 0.2);
    Offset at(int i) => layout.toScreen(b.points[i]);

    // Animation progress (0 to 1). 1 means nothing is moving.
    final mv = moveAnim;
    final double t = (mv == null || animation == null) ? 1.0 : animation!.value;
    final bool animating = mv != null && t < 1.0;

    // Lines
    final linePaint = Paint()
      ..color = const Color(0xFFE8DDB5)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final line in b.lines) {
      final path = Path();
      for (int k = 0; k < line.length; k++) {
        final p = at(line[k]);
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    // Empty points
    final dotPaint = Paint()..color = const Color(0xFFE0B010);
    for (int i = 0; i < b.points.length; i++) {
      if (game.cells[i] == kEmpty) {
        canvas.drawCircle(at(i), r * 0.5, dotPaint);
      }
    }

    // Green rings: where the selected piece can go
    final selected = game.selected;
    if (selected != null && game.winner == null && !animating) {
      final ringPaint = Paint()
        ..color = const Color(0xFF55E07A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth;
      for (final target in game.targetsFor(selected)) {
        canvas.drawCircle(at(target), r * 0.9, ringPaint);
      }
    }

    // Pieces standing still (the piece that is moving is drawn separately)
    for (int i = 0; i < b.points.length; i++) {
      final value = game.cells[i];
      if (value == kEmpty) continue;
      if (animating && i == mv!.move.to) continue;
      _drawPiece(canvas, at(i), r, value, lineWidth, selected: i == selected);
    }

    if (animating) {
      final move = mv!.move;
      final int value = mv.mover == Side.tiger ? kTiger : kGoat;
      final to = at(move.to);

      // A captured goat shrinks and fades away
      if (move.captured != -1) {
        final double fade = ((t - 0.35) / 0.5).clamp(0.0, 1.0).toDouble();
        final double alpha = 1.0 - Curves.easeIn.transform(fade);
        if (alpha > 0.01) {
          canvas.saveLayer(
              null, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
          _drawPiece(canvas, at(move.captured), r, kGoat, lineWidth,
              scale: 0.7 + 0.3 * alpha);
          canvas.restore();
        }
      }

      if (move.from == -1) {
        // A new goat drops onto the board with a little bounce
        final double pop = Curves.easeOutBack.transform(t);
        final double drop = (1 - Curves.easeOut.transform(t)) * r * 1.6;
        _drawPiece(canvas, to - Offset(0, drop), r, value, lineWidth,
            scale: max(0.05, pop));
      } else {
        // A piece slides, hopping a little. A capture is a bigger jump.
        final from = at(move.from);
        final double e = Curves.easeInOut.transform(t);
        final bool jump = move.captured != -1;
        final double lift = sin(pi * e) * r * (jump ? 1.5 : 0.45);
        final pos = Offset.lerp(from, to, e)!;
        // shadow on the ground
        canvas.drawOval(
          Rect.fromCenter(
              center: pos + Offset(0, r * 0.75), width: r * 1.5, height: r * 0.5),
          Paint()..color = const Color(0x44000000),
        );
        _drawPiece(canvas, pos - Offset(0, lift), r, value, lineWidth,
            scale: 1 + (jump ? 0.15 : 0.05) * sin(pi * e));
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// GAME FRAME: the layout shared by both games
// Portrait: top bar, status, board, counters.
// Landscape: board on the left, information on the right.
// ---------------------------------------------------------------------------

Widget statCounter(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF261910),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x33D4AF37)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
                color: Color(0xFFC7B7A6), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

// "Play again" and "Menu" buttons, shown when a game is over.
Widget endButtonsRow(BuildContext context,
    {required bool show, required VoidCallback onPlayAgain}) {
  if (!show) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton(onPressed: onPlayAgain, child: const Text('Play again')),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          child: const Text('Menu'),
        ),
      ],
    ),
  );
}

class GameFrame extends StatelessWidget {
  final String title;
  final String status;
  final List<Widget> counters;
  final Widget board;
  final Widget endButtons;
  final VoidCallback onRestart;

  const GameFrame({
    super.key,
    required this.title,
    required this.status,
    required this.counters,
    required this.board,
    required this.endButtons,
    required this.onRestart,
  });

  // Slim bar at the top: back, title, sound, restart.
  Widget topBar(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF191009),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFFD54F), size: 20),
            tooltip: 'Back to Hub',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.soundOn,
            builder: (context, on, _) => IconButton(
              icon: Icon(on ? Icons.volume_up : Icons.volume_off,
                  color: on ? const Color(0xFFFFD54F) : Colors.white54, size: 22),
              tooltip: on ? 'Sound on' : 'Sound off',
              onPressed: () => AppSettings.setSound(!on),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
            tooltip: 'Restart',
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }

  // Fixed height and one line: the board must never change size while you
  // play, otherwise it looks like the screen is shaking.
  Widget statusBanner() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1D14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55D4AF37), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            status,
            maxLines: 1,
            style: const TextStyle(
                color: Color(0xFFFDFBF7),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191009),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight * 1.2;

            if (landscape) {
              final panelWidth = min(280.0, constraints.maxWidth * 0.34);
              return Row(
                children: [
                  Expanded(child: board),
                  SizedBox(
                    width: panelWidth,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            topBar(context),
                            statusBanner(),
                            endButtons,
                            const SizedBox(height: 8),
                            for (final c in counters)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: c,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                topBar(context),
                statusBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: board),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: endButtons,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Row(
                    children: [
                      for (final c in counters) Expanded(child: c),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MENU SCREEN
// ---------------------------------------------------------------------------

class OptionCard extends StatelessWidget {
  final Widget child;
  final String label;
  final bool selected;
  final bool enabled;
  final double width;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.child,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.width = 130,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: width,
          height: 124,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A9D8F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFFFE082) : Colors.transparent,
              width: 4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  GameKind kind = GameKind.puli;
  bool vsComputer = true;
  int ashtaPlayers = 2; // Ashta Chamma: 2 or 4 players
  Difficulty difficulty = Difficulty.medium;
  Side humanSide = Side.goat; // Puli Meka: which side you play
  bool humanFirst = true; // Three Pawns: do you move first?

  Widget heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1),
      ),
    );
  }

  Widget options(List<Widget> children) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: children,
    );
  }

  IconData difficultyIcon(Difficulty d) {
    return switch (d) {
      Difficulty.easy => Icons.sentiment_satisfied_alt,
      Difficulty.medium => Icons.sentiment_neutral,
      Difficulty.hard => Icons.whatshot,
    };
  }

  void startGame() {
    final Widget screen = switch (kind) {
      GameKind.puli => GameScreen(
          config: GameConfig(
            vsComputer: vsComputer,
            humanSide: humanSide,
            board: puliMekaBoard,
            difficulty: difficulty,
          ),
        ),
      GameKind.threePawns => ThreePawnsScreen(
          config: ThreeConfig(
            vsComputer: vsComputer,
            humanPlayer: humanFirst ? 1 : 2,
            difficulty: difficulty,
          ),
        ),
      GameKind.ashtaChamma => AshtaChammaScreen(
          config: AshtaConfig(
            vsComputer: vsComputer,
            playerCount: ashtaPlayers,
            difficulty: difficulty,
          ),
        ),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void openHowToPlay() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HowToPlayScreen(kind: kind)),
    );
  }

  void openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF4A3622),
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The logo gets smaller on short screens (for example a phone on its side).
    final double logoSize =
        (MediaQuery.sizeOf(context).height * 0.18).clamp(80.0, 170.0).toDouble();
    final bool puli = kind == GameKind.puli;

    return Scaffold(
      backgroundColor: const Color(0xFF3B2A1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: CustomPaint(
                      painter: ArtPainter(kind == GameKind.puli
                          ? Art.logo
                          : (kind == GameKind.threePawns ? Art.pawns : Art.shells)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      kind == GameKind.puli
                          ? 'PULI MEKA'
                          : (kind == GameKind.threePawns ? 'THREE PAWNS' : 'ASHTA CHAMMA'),
                      style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2),
                    ),
                  ),
                  Text(
                    kind == GameKind.puli
                        ? 'Tigers and Goats'
                        : (kind == GameKind.threePawns
                            ? 'Get three in a row'
                            : 'Traditional 7x7 board with cowrie shells'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),

                  heading('SELECT GAME'),
                  options([
                    OptionCard(
                      label: 'Puli Meka',
                      selected: kind == GameKind.puli,
                      onTap: () => setState(() => kind = GameKind.puli),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: CustomPaint(painter: ArtPainter(Art.logo)),
                      ),
                    ),
                    OptionCard(
                      label: 'Three Pawns',
                      selected: kind == GameKind.threePawns,
                      onTap: () => setState(() => kind = GameKind.threePawns),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: CustomPaint(painter: ArtPainter(Art.pawns)),
                      ),
                    ),
                    OptionCard(
                      label: 'Ashta Chamma',
                      selected: kind == GameKind.ashtaChamma,
                      onTap: () => setState(() => kind = GameKind.ashtaChamma),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: CustomPaint(painter: ArtPainter(Art.shells)),
                      ),
                    ),
                  ]),

                  heading('SELECT TYPE'),
                  options([
                    OptionCard(
                      label: 'vs Computer',
                      selected: vsComputer,
                      onTap: () => setState(() => vsComputer = true),
                      child: const Icon(Icons.computer,
                          size: 44, color: Colors.white),
                    ),
                    OptionCard(
                      label: kind == GameKind.ashtaChamma ? 'Pass & Play' : '2 Players',
                      selected: !vsComputer,
                      onTap: () => setState(() => vsComputer = false),
                      child: const Icon(Icons.people,
                          size: 44, color: Colors.white),
                    ),
                  ]),
                  if (kind == GameKind.ashtaChamma) ...[
                    heading('NUMBER OF PLAYERS'),
                    options([
                      OptionCard(
                        width: 110,
                        label: '2 Players',
                        selected: ashtaPlayers == 2,
                        onTap: () => setState(() => ashtaPlayers = 2),
                        child: const Icon(Icons.person_outline, size: 40, color: Colors.white),
                      ),
                      OptionCard(
                        width: 110,
                        label: '4 Players',
                        selected: ashtaPlayers == 4,
                        onTap: () => setState(() => ashtaPlayers = 4),
                        child: const Icon(Icons.groups, size: 40, color: Colors.white),
                      ),
                    ]),
                  ],

                  if (vsComputer) ...[
                    heading('DIFFICULTY'),
                    options([
                      for (final d in Difficulty.values)
                        OptionCard(
                          width: 96,
                          label: d.label,
                          selected: difficulty == d,
                          onTap: () => setState(() => difficulty = d),
                          child: Icon(difficultyIcon(d),
                              size: 40, color: Colors.white),
                        ),
                    ]),
                    if (kind != GameKind.ashtaChamma) heading('PICK YOUR SIDE'),
                    if (kind == GameKind.puli)
                      options([
                        OptionCard(
                          label: 'Tigers',
                          selected: humanSide == Side.tiger,
                          onTap: () => setState(() => humanSide = Side.tiger),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: CustomPaint(painter: ArtPainter(Art.tiger)),
                          ),
                        ),
                        OptionCard(
                          label: 'Goats',
                          selected: humanSide == Side.goat,
                          onTap: () => setState(() => humanSide = Side.goat),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: CustomPaint(painter: ArtPainter(Art.goat)),
                          ),
                        ),
                      ])
                    else
                      options([
                        OptionCard(
                          label: 'Play first\n(orange)',
                          selected: humanFirst,
                          onTap: () => setState(() => humanFirst = true),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: CustomPaint(painter: ArtPainter(Art.pawnA)),
                          ),
                        ),
                        OptionCard(
                          label: 'Play second\n(blue)',
                          selected: !humanFirst,
                          onTap: () => setState(() => humanFirst = false),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: CustomPaint(painter: ArtPainter(Art.pawnB)),
                          ),
                        ),
                      ]),
                  ],

                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: startGame,
                    icon: const Icon(Icons.check),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('START',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // How to play and Settings stay here, at the bottom.
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: openHowToPlay,
                        icon: const Icon(Icons.help_outline,
                            color: Colors.white70),
                        label: const Text('How to play',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton.icon(
                        onPressed: openSettings,
                        icon: const Icon(Icons.settings, color: Colors.white70),
                        label: const Text('Settings',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOW TO PLAY AND SETTINGS
// ---------------------------------------------------------------------------

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppSettings.soundOn,
              builder: (context, on, _) => SwitchListTile(
                value: on,
                onChanged: AppSettings.setSound,
                title: const Text('Sound',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                secondary: Icon(on ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white70),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppSettings.vibrationOn,
              builder: (context, on, _) => SwitchListTile(
                value: on,
                onChanged: AppSettings.setVibration,
                title: const Text('Vibration',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                secondary: const Icon(Icons.vibration, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HowToPlayScreen extends StatelessWidget {
  final GameKind kind;
  const HowToPlayScreen({super.key, required this.kind});

  Widget art(Art a) => SizedBox(
        width: 46,
        height: 46,
        child: CustomPaint(painter: ArtPainter(a)),
      );

  Widget section(String title, List<String> lines, {Widget? leading}) {
    return Card(
      color: const Color(0xFF4A3622),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 10)],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '\u2022  $line',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.35),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> puliSections() {
    return [
      section(
        'The game',
        [
          'Puli Meka is a very old game from South India. One side plays 3 tigers, the other plays 15 goats.',
          'The tigers start on the board. The goats start outside it and are placed one by one.',
          'Goats always move first.',
        ],
        leading: art(Art.logo),
      ),
      section(
        'How to move',
        [
          'Tap one of your pieces. Green rings show where it can go.',
          'Tap a green ring to move there.',
          'Pieces move along the lines, one step at a time, to a connected empty point.',
          'When placing a goat, just tap any empty point.',
        ],
        leading: const Icon(Icons.touch_app, color: Colors.white70, size: 40),
      ),
      section(
        'Goats',
        [
          'First phase: each turn you place one goat on any empty point. Goats cannot move until all 15 are on the board.',
          'Second phase: each turn you move one goat to a connected empty point.',
          'You win by trapping all the tigers so that none of them can move.',
        ],
        leading: art(Art.goat),
      ),
      section(
        'Tigers',
        [
          'Each turn, move one tiger to a connected empty point.',
          'Or jump over a goat that is next to the tiger, in a straight line, and land on the empty point right behind it. The goat is captured and removed.',
          'Only one goat can be captured per turn. Tigers cannot jump over other tigers.',
          'You win by capturing 15 goats, which is all of them.',
        ],
        leading: art(Art.tiger),
      ),
      section(
        'Tips',
        [
          'Goats: a goat is safe when the point behind it is taken or is off the board. Keep your goats together and use the edges.',
          'Goats: do not rush. Tigers cannot capture what they cannot reach.',
          'Tigers: stay apart, look for two goats you can threaten at once, and keep away from corners.',
          'Playing the computer? Pick Easy, Medium or Hard on the menu.',
        ],
        leading: const Icon(Icons.lightbulb_outline,
            color: Color(0xFFFFD54F), size: 40),
      ),
    ];
  }


  List<Widget> ashtaSections() {
    return [
      section(
        'The Game',
        [
          'Ashta Chamma (also called Chowka Bhara) is an ancient Indian board game played on a 7x7 cloth grid.',
          'Each player commands 4 pawns, starting in their marked home house on the outer edge.',
          'Pawns race anti-clockwise around the perimeter and spiral inward toward the central goal.',
        ],
        leading: art(Art.shells),
      ),
      section(
        'The Cowrie Shells (Dice)',
        [
          'The game uses 4 cowrie shells to determine movement:',
          '1 mouth up: move 1 space',
          '2 mouths up: move 2 spaces',
          '3 mouths up: move 3 spaces',
          '4 mouths up (Chamma): move 4 spaces + extra roll!',
          'All mouths down (Ashta): move 8 spaces + extra roll!',
        ],
        leading: const Icon(Icons.casino, color: Colors.white70, size: 40),
      ),
      section(
        'Safe Zones (The 9 Crosses)',
        [
          'Squares marked with an "X" are safe zones (the 4 outer edge homes, 4 middle corners, and center goal).',
          'Pawns resting on a safe zone cannot be captured.',
          'Multiple pawns from any player can safely share a cross square.',
        ],
        leading: const Icon(Icons.security, color: Colors.white70, size: 40),
      ),
      section(
        'Capturing & Unlocking Inner Ring',
        [
          'Landing on an opponent pawn on any uncrossed square captures it and sends it back to its starting home.',
          'Capturing also awards an immediate extra roll!',
          'Key Rule: You must capture at least one opponent pawn before your pawns can enter the inner spiral.',
          'If you have not made a kill, your pawns must loop around the outer perimeter again.',
        ],
        leading: const Icon(Icons.gavel, color: Colors.white70, size: 40),
      ),
      section(
        'Winning the Game',
        [
          'Once inside the inner ring, navigate pawns toward the central goal box (3, 3).',
          'Exact roll is required to enter the center goal.',
          'The first player to guide all 4 pawns into the center goal wins the game!',
        ],
        leading: const Icon(Icons.emoji_events, color: Color(0xFFFFD54F), size: 40),
      ),
    ];
  }

  List<Widget> threePawnsSections() {
    return [
      section(
        'The game',
        [
          'Three Pawns is an old game that is also known as Tapatan (Philippines) and Three Men\u2019s Morris.',
          'There are two players with 3 pawns each: orange and blue. Orange moves first.',
          'Play against a friend or against the computer.',
        ],
        leading: art(Art.pawns),
      ),
      section(
        'Step 1: place your pawns',
        [
          'Take turns putting one pawn on any empty point.',
          'Keep going until all 6 pawns are on the board.',
          'If you get three in a row while placing, you win straight away.',
        ],
        leading: const Icon(Icons.touch_app, color: Colors.white70, size: 40),
      ),
      section(
        'Step 2: move your pawns',
        [
          'Now take turns moving one of your pawns, one step, along a line to a connected empty point.',
          'Tap a pawn. Green rings show where it can go. Tap a ring to move.',
          'The two diagonal lines count too.',
        ],
        leading: art(Art.pawnA),
      ),
      section(
        'How to win',
        [
          'Get your 3 pawns in a straight line: across, down or diagonally.',
          'If a player cannot move at all, that player loses.',
          'If the same position happens three times, the game is a draw.',
        ],
        leading: const Icon(Icons.emoji_events,
            color: Color(0xFFFFD54F), size: 40),
      ),
      section(
        'Tips',
        [
          'The center point is the strongest, because it touches every line.',
          'When the other player has two pawns in a line, block the third point.',
          'Try to make two threats at once, so they can only block one.',
          'Playing the computer? Pick Easy, Medium or Hard on the menu.',
        ],
        leading: const Icon(Icons.lightbulb_outline,
            color: Color(0xFFFFD54F), size: 40),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final puli = kind == GameKind.puli;
    return Scaffold(
      backgroundColor: const Color(0xFF3B2A1A),
      appBar: AppBar(title: Text(puli ? 'How to play Puli Meka' : 'How to play Three Pawns')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: puli ? puliSections() : threePawnsSections(),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PULI MEKA SCREEN
// ---------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  final GameConfig config;
  const GameScreen({super.key, required this.config});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late PuliGame game;

  // Drives the sliding animation of the pieces.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  MoveAnim? _moveAnim; // the move being animated, if any
  bool _animating = false;
  bool _thinking = false; // the computer is about to move
  int _gen = 0; // changes on restart, so old delayed actions do nothing

  GameConfig get config => widget.config;
  Side get aiSide => config.humanSide == Side.goat ? Side.tiger : Side.goat;

  bool get isComputerTurn =>
      config.vsComputer && game.winner == null && game.turn == aiSide;

  @override
  void initState() {
    super.initState();
    game = PuliGame(config.board);
    _maybeComputerMove(); // the computer plays first if you chose Tigers
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void restart() {
    _gen++;
    _thinking = false;
    _animating = false;
    _controller.stop();
    setState(() {
      _moveAnim = null;
      game = PuliGame(config.board);
    });
    _maybeComputerMove();
  }

  void _maybeComputerMove() {
    if (!isComputerTurn || _thinking || _animating) return;
    _thinking = true;
    final token = _gen;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || token != _gen) return;
      _thinking = false;
      if (!isComputerTurn || _animating) return;
      final move = ComputerPlayer(
        depth: config.difficulty.puliDepth,
        mistakeChance: config.difficulty.puliMistake,
      ).chooseMove(game);
      if (move == null) return;
      _play(move);
    });
  }

  // Plays a move: updates the game, animates the piece, plays sound and
  // vibration, then lets the computer answer.
  Future<void> _play(Move move) async {
    final token = _gen;
    final mover = game.turn;
    _animating = true;
    setState(() {
      _moveAnim = MoveAnim(move, mover);
      game.apply(move);
    });

    Sound.play(move.from == -1 ? Sfx.place : Sfx.move);
    if (move.captured != -1) {
      Haptics.medium();
      Future.delayed(const Duration(milliseconds: 170), () {
        if (mounted && token == _gen) Sound.play(Sfx.capture);
      });
    } else {
      Haptics.light();
    }

    await _controller.forward(from: 0);
    if (!mounted || token != _gen) return;
    setState(() {
      _animating = false;
      _moveAnim = null;
    });

    final w = game.winner;
    if (w != null) {
      final humanWon = !config.vsComputer || w == config.humanSide;
      Sound.play(humanWon ? Sfx.win : Sfx.lose);
      Haptics.heavy();
      return;
    }
    _maybeComputerMove();
  }

  String get statusText {
    final w = game.winner;
    if (w != null) {
      if (config.vsComputer) {
        return w == config.humanSide ? 'You win!' : 'Computer wins!';
      }
      return w == Side.tiger ? 'Tigers win!' : 'Goats win!';
    }
    if (isComputerTurn) return 'Computer is thinking…';
    final who = config.vsComputer
        ? 'Your turn'
        : (game.turn == Side.goat ? "Goats' turn" : "Tigers' turn");
    final what = game.turn == Side.goat
        ? (game.placing ? 'place a goat' : 'move a goat')
        : 'move a tiger';
    return '$who: $what';
  }

  // The board fills all the space it is given.
  Widget boardArea() {
    final board = config.board;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (_animating || isComputerTurn || game.winner != null) return;
            final i =
                pointAt(board, BoardLayout(board, size), details.localPosition);
            if (i == null) return;
            final before = game.selected;
            final move = game.tap(i);
            if (move != null) {
              _play(move);
            } else if (game.selected != before) {
              setState(() {});
              Sound.play(Sfx.select);
              Haptics.tick();
            }
          },
          child: CustomPaint(
            size: size,
            painter: BoardPainter(game,
                moveAnim: _moveAnim, animation: _controller),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: config.board.name,
      status: statusText,
      counters: [
        statCounter('TIGERS CORNERED', '${game.tigersCornered}/${game.tigerCount}'),
        statCounter('GOATS CAPTURED', '${game.goatsCaptured}/${game.goatsToWin}'),
        statCounter(
            'GOATS OUTSIDE', '${game.goatsToPlace}/${config.board.totalGoats}'),
      ],
      board: boardArea(),
      endButtons: endButtonsRow(
        context,
        show: game.winner != null && !_animating,
        onPlayAgain: restart,
      ),
      onRestart: restart,
    );
  }
}

// ---------------------------------------------------------------------------
// THREE PAWNS (also known as Tapatan or Three Men's Morris)
// 9 points, 3 pawns each. First everybody places their pawns, then you slide
// them one step along the lines. Three in a straight line wins.
// ---------------------------------------------------------------------------

// The board is a 3x3 grid of points joined by 3 rows, 3 columns and 2
// diagonals. The lines are also the 8 winning lines.
final BoardDef threePawnsBoard = BoardDef(
  name: 'Three Pawns',
  points: const [
    Offset(0, 0), Offset(150, 0), Offset(300, 0),
    Offset(0, 150), Offset(150, 150), Offset(300, 150),
    Offset(0, 300), Offset(150, 300), Offset(300, 300),
  ],
  lines: const [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6], // diagonals
  ],
  // The next three are only used by Puli Meka.
  startTigers: const [],
  totalGoats: 0,
  goatsToWin: 0,
);

BoardLayout threeLayout(Size size) => BoardLayout(
      threePawnsBoard,
      size,
      stretch: 1.0, // keep the board square
      radiusFactor: 0.26,
      maxRadius: 40.0,
    );

class ThreeGame {
  final List<int> cells; // 0 = empty, 1 = player 1 (orange), 2 = player 2 (blue)
  final List<int> placed; // how many pawns each player has put on the board
  int turn; // 1 or 2
  int? winner; // 1 or 2 when somebody has won
  bool draw;
  List<int>? winLine; // the three points of the winning line
  int? selected; // only used by the screen
  final Map<String, int> _seen; // how often each position has happened

  ThreeGame()
      : cells = List.filled(9, 0),
        placed = [0, 0],
        turn = 1,
        draw = false,
        _seen = {};

  ThreeGame.copy(ThreeGame o)
      : cells = List.of(o.cells),
        placed = List.of(o.placed),
        turn = o.turn,
        winner = o.winner,
        draw = o.draw,
        winLine = o.winLine,
        _seen = {};

  // True while the player to move still has pawns to put on the board.
  bool get placing => placed[turn - 1] < 3;

  List<Move> legalMoves() {
    final moves = <Move>[];
    if (winner != null || draw) return moves;
    if (placing) {
      for (int i = 0; i < 9; i++) {
        if (cells[i] == 0) moves.add(Move(-1, i));
      }
    } else {
      for (int i = 0; i < 9; i++) {
        if (cells[i] != turn) continue;
        for (final n in threePawnsBoard.neighbors[i]) {
          if (cells[n] == 0) moves.add(Move(i, n));
        }
      }
    }
    return moves;
  }

  // Points the pawn on [from] can slide to (used to show green rings).
  List<int> targetsFor(int from) {
    return [
      for (final n in threePawnsBoard.neighbors[from])
        if (cells[n] == 0) n
    ];
  }

  List<int>? _lineOf(int player) {
    for (final line in threePawnsBoard.lines) {
      if (cells[line[0]] == player &&
          cells[line[1]] == player &&
          cells[line[2]] == player) {
        return line;
      }
    }
    return null;
  }

  void apply(Move m) {
    final me = turn;
    if (m.from == -1) {
      cells[m.to] = me;
      placed[me - 1]++;
    } else {
      cells[m.from] = 0;
      cells[m.to] = me;
    }
    selected = null;
    turn = (me == 1) ? 2 : 1;

    // Three in a row wins, both while placing and while moving.
    final line = _lineOf(me);
    if (line != null) {
      winner = me;
      winLine = line;
      return;
    }

    // The player who has to move now is completely blocked.
    if (legalMoves().isEmpty) {
      if (blockedPlayerLoses) {
        winner = me;
      } else {
        draw = true;
      }
      return;
    }

    // The same position three times is a draw.
    final key = '${cells.join()}|$turn|${placed[0]}${placed[1]}';
    final count = (_seen[key] ?? 0) + 1;
    _seen[key] = count;
    if (count >= 3) draw = true;
  }

  // A human tapped a point. Returns the move to play, or null when the tap
  // only selected a pawn (or did nothing).
  Move? tap(int index) {
    if (winner != null || draw) return null;
    if (placing) return cells[index] == 0 ? Move(-1, index) : null;
    if (cells[index] == turn) {
      selected = index;
      return null;
    }
    final from = selected;
    if (from == null || cells[index] != 0) return null;
    if (threePawnsBoard.neighbors[from].contains(index)) {
      return Move(from, index);
    }
    return null;
  }
}

// The computer player for Three Pawns. It looks ahead several moves
// ("negamax with alpha-beta") and picks the move with the best outcome.
class ThreeAI {
  final int depth;
  final double mistakeChance;
  final Random _random = Random();

  ThreeAI({required this.depth, this.mistakeChance = 0});

  Move? chooseMove(ThreeGame game) {
    final moves = game.legalMoves();
    if (moves.isEmpty) return null;
    moves.shuffle(_random); // so it does not always play the same

    // Sometimes play a random move (this makes Easy and Medium beatable).
    if (mistakeChance > 0 && _random.nextDouble() < mistakeChance) {
      return moves.first;
    }
    // The centre is the strongest first point, so do not search for it.
    if (depth >= 6 && game.placing && game.placed[game.turn - 1] == 0) {
      if (game.cells[4] == 0) return Move(-1, 4);
    }

    Move best = moves.first;
    double bestScore = double.negativeInfinity;
    for (final m in moves) {
      final next = ThreeGame.copy(game)..apply(m);
      final score = -_negamax(
          next, depth - 1, double.negativeInfinity, double.infinity);
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best;
  }

  // Score from the point of view of the player whose turn it is in [g].
  double _negamax(ThreeGame g, int d, double alpha, double beta) {
    if (g.winner != null) {
      return g.winner == g.turn ? 1000.0 + d : -1000.0 - d;
    }
    if (g.draw) return 0;
    if (d <= 0) return _evaluate(g);
    final moves = g.legalMoves();
    if (moves.isEmpty) return _evaluate(g);

    double best = double.negativeInfinity;
    for (final m in moves) {
      final v = -_negamax(ThreeGame.copy(g)..apply(m), d - 1, -beta, -alpha);
      best = max(best, v);
      alpha = max(alpha, best);
      if (alpha >= beta) break;
    }
    return best;
  }

  // A guess of how good the position is when we stop looking further ahead:
  // lines that only one player can still use are worth points, the centre too.
  double _evaluate(ThreeGame g) {
    final me = g.turn;
    final opp = (me == 1) ? 2 : 1;
    double score = 0;
    for (final line in threePawnsBoard.lines) {
      int mine = 0;
      int theirs = 0;
      for (final p in line) {
        if (g.cells[p] == me) mine++;
        if (g.cells[p] == opp) theirs++;
      }
      if (theirs == 0) score += mine * mine;
      if (mine == 0) score -= theirs * theirs;
    }
    if (g.cells[4] == me) score += 2;
    if (g.cells[4] == opp) score -= 2;
    return score;
  }
}

// Describes the move that is being animated right now.
class ThreeAnim {
  final Move move;
  final int player;
  const ThreeAnim(this.move, this.player);
}

class ThreeBoardPainter extends CustomPainter {
  final ThreeGame game;
  final ThreeAnim? anim;
  final Animation<double>? animation;

  ThreeBoardPainter(this.game, {this.anim, this.animation})
      : super(repaint: animation);

  void _pawn(Canvas canvas, Offset c, double r, int player,
      {double scale = 1.0}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r * scale * 0.95);
    drawPawn(canvas, player == 1 ? kPlayer1Color : kPlayer2Color);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final b = threePawnsBoard;
    final layout = threeLayout(size);
    final r = layout.pieceRadius;
    final lineWidth = max(3.0, r * 0.14);
    Offset at(int i) => layout.toScreen(b.points[i]);

    final a = anim;
    final double t = (a == null || animation == null) ? 1.0 : animation!.value;
    final bool animating = a != null && t < 1.0;

    // Darker panel behind the board
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(at(0), at(8)).inflate(r * 1.3),
        Radius.circular(r * 0.8),
      ),
      Paint()..color = const Color(0x33000000),
    );

    // Lines
    final linePaint = Paint()
      ..color = const Color(0xFFE8DDB5)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final line in b.lines) {
      canvas.drawLine(at(line.first), at(line.last), linePaint);
    }

    // Points
    final dotPaint = Paint()..color = const Color(0xFFE0B010);
    for (int i = 0; i < 9; i++) {
      canvas.drawCircle(at(i), r * 0.22, dotPaint);
    }

    // The winning line glows behind the pawns
    final wl = game.winLine;
    if (wl != null && !animating) {
      canvas.drawLine(
        at(wl.first),
        at(wl.last),
        Paint()
          ..color = const Color(0xCCFFD54F)
          ..strokeWidth = r * 0.55
          ..strokeCap = StrokeCap.round,
      );
    }

    // Green rings: where the selected pawn can go
    final selected = game.selected;
    final ringPaint = Paint()
      ..color = const Color(0xFF55E07A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;
    if (selected != null && game.winner == null && !game.draw && !animating) {
      for (final target in game.targetsFor(selected)) {
        canvas.drawCircle(at(target), r * 0.8, ringPaint);
      }
    }

    // Pawns standing still (the one that is moving is drawn separately)
    for (int i = 0; i < 9; i++) {
      final player = game.cells[i];
      if (player == 0) continue;
      if (animating && i == a!.move.to) continue;
      _pawn(canvas, at(i), r, player);
      if (i == selected) canvas.drawCircle(at(i), r * 1.05, ringPaint);
    }

    if (animating) {
      final move = a!.move;
      final to = at(move.to);
      if (move.from == -1) {
        // A new pawn drops onto the board with a little bounce
        final double pop = Curves.easeOutBack.transform(t);
        final double drop = (1 - Curves.easeOut.transform(t)) * r * 1.6;
        _pawn(canvas, to - Offset(0, drop), r, a.player,
            scale: max(0.05, pop));
      } else {
        // A pawn slides, hopping a little
        final from = at(move.from);
        final double e = Curves.easeInOut.transform(t);
        final double lift = sin(pi * e) * r * 0.5;
        final pos = Offset.lerp(from, to, e)!;
        _pawn(canvas, pos - Offset(0, lift), r, a.player,
            scale: 1 + 0.06 * sin(pi * e));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ThreeBoardPainter oldDelegate) => true;
}

class ThreePawnsScreen extends StatefulWidget {
  final ThreeConfig config;
  const ThreePawnsScreen({super.key, required this.config});

  @override
  State<ThreePawnsScreen> createState() => _ThreePawnsScreenState();
}

class _ThreePawnsScreenState extends State<ThreePawnsScreen>
    with SingleTickerProviderStateMixin {
  late ThreeGame game;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  ThreeAnim? _anim;
  bool _animating = false;
  bool _thinking = false;
  int _gen = 0;

  ThreeConfig get config => widget.config;
  int get aiPlayer => config.humanPlayer == 1 ? 2 : 1;

  bool get isComputerTurn =>
      config.vsComputer &&
      game.winner == null &&
      !game.draw &&
      game.turn == aiPlayer;

  bool get gameOver => game.winner != null || game.draw;

  @override
  void initState() {
    super.initState();
    game = ThreeGame();
    _maybeComputerMove(); // the computer plays first if you chose second
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void restart() {
    _gen++;
    _thinking = false;
    _animating = false;
    _controller.stop();
    setState(() {
      _anim = null;
      game = ThreeGame();
    });
    _maybeComputerMove();
  }

  void _maybeComputerMove() {
    if (!isComputerTurn || _thinking || _animating) return;
    _thinking = true;
    final token = _gen;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || token != _gen) return;
      _thinking = false;
      if (!isComputerTurn || _animating) return;
      final move = ThreeAI(
        depth: config.difficulty.threeDepth,
        mistakeChance: config.difficulty.threeMistake,
      ).chooseMove(game);
      if (move == null) return;
      _play(move);
    });
  }

  Future<void> _play(Move move) async {
    final token = _gen;
    final player = game.turn;
    _animating = true;
    setState(() {
      _anim = ThreeAnim(move, player);
      game.apply(move);
    });

    Sound.play(move.from == -1 ? Sfx.place : Sfx.move);
    Haptics.light();

    await _controller.forward(from: 0);
    if (!mounted || token != _gen) return;
    setState(() {
      _animating = false;
      _anim = null;
    });

    final w = game.winner;
    if (w != null) {
      final humanWon = !config.vsComputer || w == config.humanPlayer;
      Sound.play(humanWon ? Sfx.win : Sfx.lose);
      Haptics.heavy();
      return;
    }
    if (game.draw) {
      Sound.play(Sfx.select);
      Haptics.medium();
      return;
    }
    _maybeComputerMove();
  }

  String get statusText {
    final w = game.winner;
    if (w != null) {
      if (config.vsComputer) {
        return w == config.humanPlayer ? 'You win!' : 'Computer wins!';
      }
      return w == 1 ? 'Orange wins!' : 'Blue wins!';
    }
    if (game.draw) return "It's a draw!";
    if (isComputerTurn) return 'Computer is thinking…';
    final who = config.vsComputer
        ? 'Your turn'
        : (game.turn == 1 ? "Orange's turn" : "Blue's turn");
    return '$who: ${game.placing ? 'place a pawn' : 'move a pawn'}';
  }

  Widget boardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (_animating || isComputerTurn || gameOver) return;
            final i = pointAt(
                threePawnsBoard, threeLayout(size), details.localPosition);
            if (i == null) return;
            final before = game.selected;
            final move = game.tap(i);
            if (move != null) {
              _play(move);
            } else if (game.selected != before) {
              setState(() {});
              Sound.play(Sfx.select);
              Haptics.tick();
            }
          },
          child: CustomPaint(
            size: size,
            painter: ThreeBoardPainter(game,
                anim: _anim, animation: _controller),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: threePawnsBoard.name,
      status: statusText,
      counters: [
        statCounter('ORANGE TO PLACE', '${3 - game.placed[0]}/3'),
        statCounter('BLUE TO PLACE', '${3 - game.placed[1]}/3'),
        statCounter('STAGE',
            (game.placed[0] < 3 || game.placed[1] < 3) ? 'Place' : 'Move'),
      ],
      board: boardArea(),
      endButtons: endButtonsRow(
        context,
        show: gameOver && !_animating,
        onPlayAgain: restart,
      ),
      onRestart: restart,
    );
  }
}