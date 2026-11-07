import 'package:flutter/material.dart';
import 'game_definition.dart';
import '../theme/app_theme.dart';
import '../ashta_chamma.dart';
import '../games/navakankari.dart';
import '../games/daadi.dart';
import '../games/paramapadham.dart';
import '../games/pallanguzhi.dart';
import '../games/pachisi.dart';
import '../main.dart';

class GameRegistry {
  static List<GameDefinition> getGames(BuildContext context) {
    return [
      // 1. Puli Meka (Tigers & Goats)
      GameDefinition(
        id: 'puli_meka',
        title: 'Puli Meka',
        nativeTitle: 'పులి మేక (Tigers & Goats)',
        subtitle: '3 Tigers hunt vs 15 Goats trap on a 23-point grid',
        description: 'An ancient South Indian asymmetrical battle of wits. Tigers leap to capture, while goats swarm to paralyze.',
        category: GameCategory.strategy,
        playersCountText: '2 Players',
        avgDuration: '10–15 Min',
        themeColor: AppTheme.tigerOrange,
        previewArt: const CustomPaint(painter: ArtPainter(Art.logo)),
        screenBuilder: (ctx) => GameScreen(
          config: GameConfig(
            vsComputer: true,
            humanSide: Side.goat,
            board: puliMekaBoard,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: 'Overview & Roles',
            icon: Icons.shield,
            bulletPoints: [
              'One player controls 3 fierce Tigers; the other commands a herd of 15 Goats.',
              'The board is a sacred 23-point triangular grid.',
              'Goats start outside the board and are placed one by one. Tigers start on the board.',
            ],
          ),
          RuleSection(
            title: 'Movement & Captures',
            icon: Icons.touch_app,
            bulletPoints: [
              'Phase 1: Goats place one piece per turn until all 15 are on the board.',
              'Phase 2: Goats slide one step along lines to adjacent empty vertices.',
              'Tigers slide one step or jump in a straight line over an adjacent goat to capture it.',
              'Tigers cannot jump over other tigers, and only one goat is captured per jump.',
            ],
          ),
          RuleSection(
            title: 'Winning Conditions',
            icon: Icons.emoji_events,
            bulletPoints: [
              'Goats win by surrounding all 3 tigers so none of them have any legal moves.',
              'Tigers win by capturing goats until goats can no longer trap them.',
            ],
          ),
        ],
      ),

      // 2. Ashta Chamma (Chowka Bhara)
      GameDefinition(
        id: 'ashta_chamma',
        title: 'Ashta Chamma',
        nativeTitle: 'అష్టా చమ్మా (Chowka Bhara)',
        subtitle: '4 Cowrie shells race around a 7x7 cloth board',
        description: 'Traditional Indian race game. Roll 4 cowrie shells, navigate the 9 safe houses, capture opponents, and reach Heaven.',
        category: GameCategory.race,
        playersCountText: '2–4 Players',
        avgDuration: '15–20 Min',
        themeColor: AppTheme.terracotta,
        previewArt: const CustomPaint(painter: ArtPainter(Art.shells)),
        screenBuilder: (ctx) => const AshtaChammaScreen(
          config: AshtaConfig(
            vsComputer: true,
            playerCount: 2,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: 'Setup & Cowrie Shells',
            icon: Icons.casino,
            bulletPoints: [
              'Played on a 7x7 cloth grid with 9 crossed safe zones (the 4 outer homes, 4 inner corners, and center goal).',
              '4 cowrie shells dictate movement: 1, 2, 3, 4 (Chamma), or 8 (Ashta).',
              'Rolling 4, 8, or executing a capture awards an immediate extra roll.',
            ],
          ),
          RuleSection(
            title: 'Movement & Safe Houses',
            icon: Icons.security,
            bulletPoints: [
              'Pawns move anti-clockwise around the outer perimeter of 24 squares, then spiral inward.',
              'Squares marked with an "X" are safe zones where pawns can never be captured.',
              'Multiple pawns from any player can safely share a cross square.',
            ],
          ),
          RuleSection(
            title: 'Captures & Inner Ring Gate',
            icon: Icons.gavel,
            bulletPoints: [
              'Landing on an opponent pawn on an uncrossed square captures it and sends it back to its starting home.',
              'Capturing grants an immediate extra roll.',
              'Crucial: You must make at least one capture to unlock entry into the inner rings.',
              'First player to navigate all 4 pawns into the center goal (3, 3) wins!',
            ],
          ),
        ],
      ),

      // 3. Pachisi / Chaupar (Royal Game of India)
      GameDefinition(
        id: 'pachisi',
        title: 'Pachisi / Chaupar',
        nativeTitle: 'పచీస్ (Royal Game of India)',
        subtitle: 'The legendary 4-player cross-and-circle heritage board',
        description: 'The ancient royal board game of India. Roll cowrie shells, navigate the cruciform arms, capture opponents, and guide all pawns to the central Charkoni.',
        category: GameCategory.race,
        playersCountText: '2–4 Players',
        avgDuration: '20–25 Min',
        themeColor: AppTheme.gold,
        previewArt: const Icon(Icons.add_box, color: AppTheme.gold, size: 36),
        screenBuilder: (ctx) => const PachisiScreen(
          config: PachisiConfig(
            vsComputer: true,
            playerCount: 2,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: 'The Cruciform Board',
            icon: Icons.grid_view,
            bulletPoints: [
              '4 arms radiating from the central Charkoni (Heaven). Each arm has 3 columns of 8 squares.',
              'Pawns start in Charkoni, travel down their arm, circle all 4 arms anti-clockwise, and return up their center home lane.',
            ],
          ),
          RuleSection(
            title: 'Cowrie Throws & Castles',
            icon: Icons.casino,
            bulletPoints: [
              'Roll 4 cowrie shells to move 1, 2, 3, 4, or 8 spaces.',
              'Squares marked with an "X" are safe castles where pawns cannot be captured.',
              'Landing on an opponent on an open square captures them back to Charkoni and awards a bonus roll.',
            ],
          ),
          RuleSection(
            title: 'Winning the Royal Match',
            icon: Icons.emoji_events,
            bulletPoints: [
              'You must score at least one capture before entering your final center home lane.',
              'First player to guide all 4 pawns into the central Charkoni wins!',
            ],
          ),
        ],
      ),

      // 4. Navakankari (Nine Men's Morris / Char Bhar)
      GameDefinition(
        id: 'navakankari',
        title: 'Navakankari',
        nativeTitle: "నవకంకరి (Nine Men's Morris / Char Bhar)",
        subtitle: 'Form 3-in-a-line Mills to capture opponent coins',
        description: 'Ancient alignment war across 3 concentric squares. Drop 9 coins, slide along lines, and capture opponents by completing mills.',
        category: GameCategory.alignment,
        playersCountText: '2 Players',
        avgDuration: '8–12 Min',
        themeColor: AppTheme.jade,
        previewArt: const Icon(Icons.grid_4x4, color: AppTheme.jade, size: 36),
        screenBuilder: (ctx) => const NavakankariScreen(
          config: NavakankariConfig(
            vsComputer: true,
            humanPlayer: 1,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: 'Phase 1: Placing Coins',
            icon: Icons.touch_app,
            bulletPoints: [
              'Both players take turns placing 1 of their 9 coins on any empty intersection.',
              'Forming a "Mill" (3 of your coins in a straight line) lets you capture 1 opponent coin.',
            ],
          ),
          RuleSection(
            title: 'Phase 2: Sliding Coins',
            icon: Icons.swap_horiz,
            bulletPoints: [
              'After all 9 coins are placed, slide 1 coin per turn to an adjacent connected point.',
              'Forming a Mill allows you to capture another opponent coin.',
            ],
          ),
          RuleSection(
            title: 'Phase 3: Flying & Winning',
            icon: Icons.flight_takeoff,
            bulletPoints: [
              'When reduced to 3 coins, you can "Fly" to ANY empty point on the board!',
              'You win by reducing the opponent to 2 coins or by blocking all their moves.',
            ],
          ),
        ],
      ),

      // 5. Daadi (Twelve Men's Morris / 12 Pawns)
      GameDefinition(
        id: 'daadi',
        title: 'Daadi',
        nativeTitle: "దాడి (Twelve Men's Morris / 12 Pawns)",
        subtitle: '12 Pawns each with orthogonal AND diagonal mill lines',
        description: 'The intense 12-pawn evolution of Navakankari featuring diagonal mill lines connecting all 4 corners.',
        category: GameCategory.alignment,
        playersCountText: '2 Players',
        avgDuration: '10–15 Min',
        themeColor: const Color(0xFFF97316),
        previewArt: const Icon(Icons.hub, color: Color(0xFFF97316), size: 36),
        screenBuilder: (ctx) => const DaadiScreen(
          config: DaadiConfig(
            vsComputer: true,
            humanPlayer: 1,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: '12 Pawns & Corner Diagonals',
            icon: Icons.polyline,
            bulletPoints: [
              'Each player commands 12 coins (instead of 9).',
              'The 4 corners have diagonal connector lines, creating 20 total possible mill lines!',
            ],
          ),
          RuleSection(
            title: 'Forming Daadi (Mills)',
            icon: Icons.gavel,
            bulletPoints: [
              'Placing or sliding 3 coins in a line (orthogonally or diagonally) forms a Daadi.',
              'Capture and remove an opponent coin that is not currently part of an active Daadi.',
            ],
          ),
          RuleSection(
            title: 'Victory',
            icon: Icons.emoji_events,
            bulletPoints: [
              'Fly anywhere when down to 3 coins.',
              'Win by reducing opponent to 2 coins or completely blocking them.',
            ],
          ),
        ],
      ),

      // 6. Paramapadham (Vaikuntapali / Ancient Snakes & Ladders)
      GameDefinition(
        id: 'paramapadham',
        title: 'Paramapadham',
        nativeTitle: 'పరమపదం (Vaikuntapali / Snakes & Ladders)',
        subtitle: '100-square spiritual race with Virtue Ladders & Vice Snakes',
        description: 'The ancient Indian game of karma and destiny. Climb ladders of virtues, beware the venomous snakes of vices, and reach Moksha at square 100.',
        category: GameCategory.race,
        playersCountText: '2–4 Players',
        avgDuration: '10–15 Min',
        themeColor: const Color(0xFFE53935),
        previewArt: const Icon(Icons.stairs, color: Color(0xFFE53935), size: 36),
        screenBuilder: (ctx) => const ParamapadhamScreen(
          config: ParamapadhamConfig(
            vsComputer: true,
            playerCount: 2,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: 'The 100 Squares of Karma',
            icon: Icons.auto_awesome,
            bulletPoints: [
              'The board consists of 100 squares arranged in a winding serpentine path from 1 (Earth) to 100 (Vaikunta/Moksha).',
              'Players take turns rolling a 6-sided die to advance their pawn.',
            ],
          ),
          RuleSection(
            title: 'Virtue Ladders & Vice Snakes',
            icon: Icons.trending_up,
            bulletPoints: [
              'Landing at the base of a Ladder elevates your soul swiftly to the top square.',
              'Landing on the head of a Snake slides you down to its tail.',
              'Rolling a 6 awards an immediate bonus roll.',
            ],
          ),
          RuleSection(
            title: 'Reaching Moksha',
            icon: Icons.emoji_events,
            bulletPoints: [
              'Exact roll is required to reach square 100.',
              'First player to reach square 100 achieves Moksha and wins!',
            ],
          ),
        ],
      ),

      // 7. Pallanguzhi (Ali Guli Mane / Mancala)
      GameDefinition(
        id: 'pallanguzhi',
        title: 'Pallanguzhi',
        nativeTitle: 'పల్లంగుళి (Ali Guli Mane / Mancala)',
        subtitle: '14 Carved wooden pits with tamarind seed sowing',
        description: 'Traditional Southern Indian sowing strategy. Pick up seeds, sow them counter-clockwise, and capture opponent seeds through empty pit tactics.',
        category: GameCategory.mancala,
        playersCountText: '2 Players',
        avgDuration: '10–12 Min',
        themeColor: const Color(0xFFD4AF37),
        previewArt: const Icon(Icons.grain, color: Color(0xFFD4AF37), size: 36),
        screenBuilder: (ctx) => const PallanguzhiScreen(
          config: PallanguzhiConfig(
            vsComputer: true,
            humanPlayer: 1,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: '14 Pits & 70 Seeds',
            icon: Icons.circle,
            bulletPoints: [
              'Two rows of 7 pits (14 pits total), each starting with 5 seeds (70 seeds total).',
              'Player 1 controls the South row (pits 0..6); Player 2 controls the North row (pits 7..13).',
            ],
          ),
          RuleSection(
            title: 'Continuous Sowing',
            icon: Icons.swap_calls,
            bulletPoints: [
              'Touch any of your pits to take all its seeds and sow them 1-by-1 counter-clockwise.',
              'When hand is empty: if the next pit has seeds, pick them up and continue sowing!',
            ],
          ),
          RuleSection(
            title: 'Capturing Seeds',
            icon: Icons.archive,
            bulletPoints: [
              'If your hand empties and the next pit is EMPTY, you harvest all seeds from the pit immediately FOLLOWING it into your store!',
              'When all seeds are harvested, the player with the most seeds wins!',
            ],
          ),
        ],
      ),

      // 8. Three Pawns (Tapatan / Three Men's Morris)
      GameDefinition(
        id: 'three_pawns',
        title: 'Three Pawns',
        nativeTitle: 'తీన్ గోటీ (Tapatan / Morris)',
        subtitle: '3 Pawns each on a 3x3 grid with diagonals',
        description: 'Fast-paced alignment strategy. Drop 3 pawns, slide along lines, and align 3 in a straight line to conquer.',
        category: GameCategory.alignment,
        playersCountText: '2 Players',
        avgDuration: '3–5 Min',
        themeColor: AppTheme.lapis,
        previewArt: const CustomPaint(painter: ArtPainter(Art.pawns)),
        screenBuilder: (ctx) => ThreePawnsScreen(
          config: ThreeConfig(
            vsComputer: true,
            humanPlayer: 1,
            difficulty: Difficulty.medium,
          ),
        ),
        rules: const [
          RuleSection(
            title: 'Setup & Rules',
            icon: Icons.grid_3x3,
            bulletPoints: [
              '3x3 grid with horizontal, vertical, and diagonal connection lines.',
              'Phase 1: Players take turns placing their 3 pawns on any empty intersection.',
              'Phase 2: Players slide one pawn one step along a connected line to an empty point.',
            ],
          ),
          RuleSection(
            title: 'Victory & Draws',
            icon: Icons.emoji_events,
            bulletPoints: [
              'The first player to align 3 pawns in a straight line wins.',
              'A completely blocked player with no legal moves loses.',
              'Repeating the same board position 3 times results in a draw.',
            ],
          ),
        ],
      ),
    ];
  }
}
