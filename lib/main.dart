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
      title: 'Puli Meka',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
      home: const MenuScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS YOU CAN CHANGE
// ---------------------------------------------------------------------------

// How many moves ahead the computer thinks.
// 2 = easy, 3 = medium, 4 = hard, 5 = very hard (may feel slow on old phones).
const int aiDepth = 4;

// true = the app uses the whole screen (no status bar or button bar).
const bool fullScreenApp = true;

// ---------------------------------------------------------------------------
// BASIC TYPES
// ---------------------------------------------------------------------------

const int kEmpty = 0;
const int kTiger = 1;
const int kGoat = 2;

enum Side { tiger, goat }

class Jump {
  final int over;
  final int to;
  const Jump(this.over, this.to);
}

class Move {
  final int from; // -1 means "place a new goat on the board"
  final int to;
  final int captured; // -1 when nothing is captured
  const Move(this.from, this.to, [this.captured = -1]);
}

class GameConfig {
  final bool vsComputer;
  final Side humanSide;
  final BoardDef board;
  final Level? level; // set when playing in Levels mode
  GameConfig({
    required this.vsComputer,
    required this.humanSide,
    required this.board,
    this.level,
  });
}

// ---------------------------------------------------------------------------
// LEVELS
// In Levels mode you play the Goats against the tigers. Each level makes the
// tigers smarter and lets them win with fewer captures.
// You can change any number in the table to make a level easier or harder.
// ---------------------------------------------------------------------------

class Level {
  final int number;
  final int depth; // how many moves ahead the tigers think
  final double mistakeChance; // chance (0 to 1) that the tigers play a random move
  final int goatsToWin; // how many goats the tigers must capture to win
  const Level(this.number, this.depth, this.mistakeChance, this.goatsToWin);
}

const List<Level> levels = [
  Level(1, 1, 0.70, 15),
  Level(2, 1, 0.55, 15),
  Level(3, 1, 0.40, 15),
  Level(4, 2, 0.45, 15),
  Level(5, 2, 0.30, 14),
  Level(6, 2, 0.15, 14),
  Level(7, 2, 0.00, 13),
  Level(8, 3, 0.30, 13),
  Level(9, 3, 0.15, 12),
  Level(10, 3, 0.00, 12),
  Level(11, 3, 0.00, 11),
  Level(12, 4, 0.25, 11),
  Level(13, 4, 0.10, 10),
  Level(14, 4, 0.00, 10),
  Level(15, 4, 0.00, 9),
  Level(16, 4, 0.00, 8),
  Level(17, 4, 0.00, 7),
  Level(18, 4, 0.00, 6),
  Level(19, 4, 0.00, 5),
  Level(20, 4, 0.00, 4),
];

GameConfig levelConfig(Level level) => GameConfig(
      vsComputer: true,
      humanSide: Side.goat,
      board: puliMekaBoard,
      level: level,
    );

// Remembers on the phone which level you have reached.
class Progress {
  static const String _key = 'unlocked_level';

  static Future<int> unlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 1;
  }

  static Future<void> unlock(int level) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 1;
    if (level > current) await prefs.setInt(_key, level);
  }
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

enum Art { tiger, goat, logo }

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

  factory BoardLayout(BoardDef b, Size size) {
    // First pass finds the piece size, second pass leaves room for pieces
    // that sit on the edge of the board.
    final first = _compute(b, size, 0.05 * min(size.width, size.height));
    return _compute(b, size, first.pieceRadius * 1.25 + 4);
  }

  static BoardLayout _compute(BoardDef b, Size size, double margin) {
    final availW = max(1.0, (size.width - 2 * margin) * boardFill);
    final availH = max(1.0, (size.height - 2 * margin) * boardFill);
    double sx = availW / b.width;
    double sy = availH / b.height;

    // Do not stretch the board too much on very wide or very tall screens.
    if (sy > sx * maxStretch) sy = sx * maxStretch;
    if (sx > sy * maxStretch) sx = sy * maxStretch;

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
    final radius = min(minDist * 0.45, 46.0);
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
      if (animating && i == mv.move.to) continue;
      _drawPiece(canvas, at(i), r, value, lineWidth, selected: i == selected);
    }

    if (animating) {
      final move = mv.move;
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
// MENU SCREEN
// ---------------------------------------------------------------------------

class OptionCard extends StatelessWidget {
  final Widget child;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.child,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 130,
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
  bool vsComputer = true;
  bool career = false; // true = Levels mode
  Side humanSide = Side.goat;

  @override
  void initState() {
    super.initState();
    // The first time the app opens, show the rules.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHelpFirstTime());
  }

  Future<void> _showHelpFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('seen_help') ?? false) return;
      await prefs.setBool('seen_help', true);
      if (mounted) openHowToPlay();
    } catch (_) {}
  }

  void openHowToPlay() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
    );
  }

  void openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF4A3622),
      builder: (_) => const SettingsSheet(),
    );
  }

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

  void startGame() {
    if (career) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LevelsScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          config: GameConfig(
            vsComputer: vsComputer,
            humanSide: humanSide,
            board: puliMekaBoard,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The logo gets smaller on short screens (for example a phone on its side).
    final double logoSize =
        (MediaQuery.sizeOf(context).height * 0.18).clamp(80.0, 170.0).toDouble();
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
                  child: const CustomPaint(painter: ArtPainter(Art.logo)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PULI MEKA',
                  style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
                const Text(
                  'Tigers and Goats',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                heading('SELECT TYPE'),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    OptionCard(
                      label: 'vs Computer',
                      selected: !career && vsComputer,
                      onTap: () => setState(() {
                        career = false;
                        vsComputer = true;
                      }),
                      child: const Icon(Icons.computer,
                          size: 44, color: Colors.white),
                    ),
                    OptionCard(
                      label: '2 Players',
                      selected: !career && !vsComputer,
                      onTap: () => setState(() {
                        career = false;
                        vsComputer = false;
                      }),
                      child: const Icon(Icons.people,
                          size: 44, color: Colors.white),
                    ),
                    OptionCard(
                      label: 'Levels',
                      selected: career,
                      onTap: () => setState(() => career = true),
                      child: const Icon(Icons.emoji_events,
                          size: 44, color: Colors.white),
                    ),
                  ],
                ),
                if (!career) ...[
                heading('CHOOSE BOARD'),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    OptionCard(
                      label: 'Puli Meka',
                      selected: true,
                      onTap: () {},
                      child: const Icon(Icons.change_history,
                          size: 44, color: Colors.white),
                    ),
                    OptionCard(
                      label: 'Bagh-Chal\n(coming soon)',
                      selected: false,
                      enabled: false,
                      onTap: () {},
                      child: const Icon(Icons.grid_4x4,
                          size: 44, color: Colors.white),
                    ),
                  ],
                ),
                ],
                if (!career && vsComputer) ...[
                  heading('PICK YOUR SIDE'),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: [
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
                    ],
                  ),
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
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: openHowToPlay,
                      icon: const Icon(Icons.help_outline, color: Colors.white70),
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
  const HowToPlayScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3B2A1A),
      appBar: AppBar(title: const Text('How to play')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                section(
                  'The game',
                  [
                    'Puli Meka is a very old game from South India. One side plays 3 tigers, the other plays 15 goats.',
                    'The tigers start on the board. The goats start outside it and are placed one by one.',
                    'Goats always move first.',
                  ],
                  leading: const SizedBox(
                    width: 46,
                    height: 46,
                    child: CustomPaint(painter: ArtPainter(Art.logo)),
                  ),
                ),
                section(
                  'How to move',
                  [
                    'Tap one of your pieces. Green rings show where it can go.',
                    'Tap a green ring to move there.',
                    'Pieces move along the lines, one step at a time, to a connected empty point.',
                    'When placing a goat, just tap any empty point.',
                  ],
                  leading: const Icon(Icons.touch_app,
                      color: Colors.white70, size: 40),
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
                    'You win by capturing enough goats. The number needed is shown under GOATS CAPTURED.',
                  ],
                  leading: art(Art.tiger),
                ),
                section(
                  'Tips',
                  [
                    'Goats: a goat is safe when the point behind it is taken or is off the board. Keep your goats together and use the edges.',
                    'Goats: do not rush. Tigers cannot capture what they cannot reach.',
                    'Tigers: stay apart, look for two goats you can threaten at once, and keep away from corners.',
                    'Levels: you play the goats. Each level the tigers get smarter and need fewer captures.',
                  ],
                  leading: const Icon(Icons.lightbulb_outline,
                      color: Color(0xFFFFD54F), size: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LEVELS SCREEN
// ---------------------------------------------------------------------------

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  int unlocked = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await Progress.unlockedLevel();
    if (mounted) setState(() => unlocked = n);
  }

  Future<void> _open(Level level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(config: levelConfig(level))),
    );
    _load(); // refresh the lock icons when you come back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3B2A1A),
      appBar: AppBar(title: const Text('Levels')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'You play the Goats. Win a level to unlock the next one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: levels.length,
                itemBuilder: (context, i) {
                  final level = levels[i];
                  final locked = level.number > unlocked;
                  final done = level.number < unlocked;
                  final current = level.number == unlocked;
                  return GestureDetector(
                    onTap: locked ? null : () => _open(level),
                    child: Container(
                      decoration: BoxDecoration(
                        color: locked
                            ? const Color(0xFF5B4A3A)
                            : const Color(0xFF2A9D8F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: current
                              ? const Color(0xFFFFE082)
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: locked
                            ? const Icon(Icons.lock,
                                color: Colors.white54, size: 30)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${level.number}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (done)
                                    const Icon(Icons.star,
                                        color: Color(0xFFFFD54F), size: 18),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GAME SCREEN
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
    game = PuliGame(config.board, goatsToWin: config.level?.goatsToWin);
    _maybeComputerMove(); // the computer plays first if you chose Tigers
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _levelSaved = false;

  void restart() {
    _gen++;
    _thinking = false;
    _animating = false;
    _controller.stop();
    _levelSaved = false;
    setState(() {
      _moveAnim = null;
      game = PuliGame(config.board, goatsToWin: config.level?.goatsToWin);
    });
    _maybeComputerMove();
  }

  // When you win a level, unlock the next one.
  void _checkLevelComplete() {
    final level = config.level;
    if (level == null || _levelSaved) return;
    if (game.winner == config.humanSide) {
      _levelSaved = true;
      Progress.unlock(level.number + 1);
    }
  }

  // The level after this one, once you have won this one.
  Level? get nextLevel {
    final level = config.level;
    if (level == null || game.winner != config.humanSide) return null;
    if (level.number >= levels.length) return null;
    return levels[level.number]; // list starts at 0, level numbers at 1
  }

  void goToNextLevel(Level next) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(config: levelConfig(next))),
    );
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
        depth: config.level?.depth ?? aiDepth,
        mistakeChance: config.level?.mistakeChance ?? 0,
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
    _checkLevelComplete();

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
      final level = config.level;
      if (level != null) {
        return w == config.humanSide
            ? 'Level ${level.number} complete!'
            : 'The tigers win. Try again!';
      }
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

  Widget counter(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  List<Widget> get counters => [
        counter('TIGERS CORNERED', '${game.tigersCornered}/${game.tigerCount}'),
        counter('GOATS CAPTURED', '${game.goatsCaptured}/${game.goatsToWin}'),
        counter('GOATS OUTSIDE',
            '${game.goatsToPlace}/${config.board.totalGoats}'),
      ];

  // Slim bar at the top: back, title, restart.
  Widget topBar() {
    final level = config.level;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              level != null ? 'Level ${level.number}' : config.board.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.soundOn,
            builder: (context, on, _) => IconButton(
              icon: Icon(on ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white),
              tooltip: on ? 'Sound on' : 'Sound off',
              onPressed: () => AppSettings.setSound(!on),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Restart',
            onPressed: restart,
          ),
        ],
      ),
    );
  }

  // Fixed height and one line: the board must never change size while you
  // play, otherwise it looks like the screen is shaking.
  Widget statusBanner() {
    return SizedBox(
      height: 44,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              statusText,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // "Next level" / "Play again" buttons, shown when the game is over.
  Widget endButtons() {
    if (game.winner == null || _animating) return const SizedBox.shrink();
    final next = nextLevel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (next != null)
            FilledButton(
              onPressed: () => goToNextLevel(next),
              child: const Text('Next level'),
            ),
          FilledButton(
            onPressed: restart,
            child: Text(config.level != null && game.winner != config.humanSide
                ? 'Try again'
                : 'Play again'),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFF3B2A1A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight * 1.2;

            if (landscape) {
              // Phone on its side or a wide tablet: board on the left,
              // information on the right.
              final panelWidth = min(280.0, constraints.maxWidth * 0.34);
              return Row(
                children: [
                  Expanded(child: boardArea()),
                  SizedBox(
                    width: panelWidth,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            topBar(),
                            statusBanner(),
                            endButtons(),
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

            // Portrait: the board takes all the space left over.
            return Column(
              children: [
                topBar(),
                statusBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      boardArea(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: endButtons(),
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