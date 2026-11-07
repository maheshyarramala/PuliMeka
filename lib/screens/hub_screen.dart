import '../games/pachisi.dart';
import '../games/pallanguzhi.dart';
import '../games/paramapadham.dart';
import '../games/daadi.dart';
import '../games/navakankari.dart';
import '../ashta_chamma.dart';
import '../main.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_definition.dart';
import '../theme/app_theme.dart';
import 'rules_screen.dart';
import 'game_setup_sheet.dart';

class HubScreen extends StatefulWidget {
  final List<GameDefinition> games;
  final VoidCallback onOpenSettings;
  final ValueNotifier<bool> soundNotifier;
  final ValueNotifier<bool> vibrationNotifier;
  final void Function(bool) onToggleSound;

  const HubScreen({
    super.key,
    required this.games,
    required this.onOpenSettings,
    required this.soundNotifier,
    required this.vibrationNotifier,
    required this.onToggleSound,
  });

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  GameCategory _selectedCategory = GameCategory.all;
  String _lastPlayedId = 'puli_meka';

  @override
  void initState() {
    super.initState();
    _loadLastPlayed();
  }

  Future<void> _loadLastPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('last_played_game_id');
      if (id != null && widget.games.any((g) => g.id == id)) {
        setState(() => _lastPlayedId = id);
      }
    } catch (_) {}
  }

  Future<void> _saveLastPlayed(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_played_game_id', id);
      setState(() => _lastPlayedId = id);
    } catch (_) {}
  }

  GameDefinition get _featuredGame {
    return widget.games.firstWhere(
      (g) => g.id == _lastPlayedId,
      orElse: () => widget.games.first,
    );
  }

  List<GameDefinition> get _filteredGames {
    if (_selectedCategory == GameCategory.all) return widget.games;
    return widget.games.where((g) => g.category == _selectedCategory).toList();
  }

  void _instantPlay(GameDefinition game) {
    _saveLastPlayed(game.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => game.screenBuilder(ctx)),
    );
  }

  void _openSetupAndPlay(GameDefinition game) {
    _saveLastPlayed(game.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return GameSetupSheet(
          title: game.title,
          nativeTitle: game.nativeTitle,
          themeColor: game.themeColor,
          previewArt: game.previewArt,
          hasPlayerChoice: true,
          playerOptions: switch (game.id) {
            'puli_meka' => const ['Play as Goats', 'Play as Tigers'],
            'three_pawns' => const ['Play First (Orange)', 'Play Second (Blue)'],
            'ashta_chamma' => const ['2 Players (North vs South)', '4 Players (All Sides)'],
            'pachisi' => const ['2 Players (South vs North)', '4 Players (All 4 Arms)'],
            'paramapadham' => const ['2 Players (Red vs Gold)', '4 Players (All 4 Colors)'],
            'navakankari' => const ['Play First (Gold)', 'Play Second (Jade)'],
            'daadi' => const ['Play First (Gold)', 'Play Second (Saffron)'],
            'pallanguzhi' => const ['Play First (South Row)', 'Play Second (North Row)'],
            _ => const ['Option 1', 'Option 2'],
          },
          playerChoiceTitle: switch (game.id) {
            'puli_meka' => 'CHOOSE YOUR SIDE',
            'three_pawns' => 'PLAYING ORDER',
            'ashta_chamma' => 'NUMBER OF PLAYERS',
            'pachisi' => 'NUMBER OF PLAYERS',
            'paramapadham' => 'NUMBER OF PLAYERS',
            'navakankari' => 'CHOOSE YOUR COINS',
            'daadi' => 'CHOOSE YOUR COINS',
            'pallanguzhi' => 'CHOOSE YOUR ROW',
            _ => 'OPTIONS',
          },
          onStart: ({
            required vsComputer,
            required difficultyIndex,
            required selectedOptionIndex,
          }) {
            final diff = switch (difficultyIndex) {
              0 => Difficulty.easy,
              1 => Difficulty.medium,
              2 => Difficulty.hard,
              _ => Difficulty.medium,
            };

            Widget targetScreen;
            if (game.id == 'ashta_chamma') {
              final count = (selectedOptionIndex == 1) ? 4 : 2;
              targetScreen = AshtaChammaScreen(
                config: AshtaConfig(
                  vsComputer: vsComputer,
                  playerCount: count,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'pachisi') {
              final count = (selectedOptionIndex == 1) ? 4 : 2;
              targetScreen = PachisiScreen(
                config: PachisiConfig(
                  vsComputer: vsComputer,
                  playerCount: count,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'paramapadham') {
              final count = (selectedOptionIndex == 1) ? 4 : 2;
              targetScreen = ParamapadhamScreen(
                config: ParamapadhamConfig(
                  vsComputer: vsComputer,
                  playerCount: count,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'pallanguzhi') {
              final pNum = (selectedOptionIndex == 1) ? 2 : 1;
              targetScreen = PallanguzhiScreen(
                config: PallanguzhiConfig(
                  vsComputer: vsComputer,
                  humanPlayer: pNum,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'daadi') {
              final pNum = (selectedOptionIndex == 1) ? 2 : 1;
              targetScreen = DaadiScreen(
                config: DaadiConfig(
                  vsComputer: vsComputer,
                  humanPlayer: pNum,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'navakankari') {
              final pNum = (selectedOptionIndex == 1) ? 2 : 1;
              targetScreen = NavakankariScreen(
                config: NavakankariConfig(
                  vsComputer: vsComputer,
                  humanPlayer: pNum,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'puli_meka') {
              final side = (selectedOptionIndex == 1) ? Side.tiger : Side.goat;
              targetScreen = GameScreen(
                config: GameConfig(
                  vsComputer: vsComputer,
                  humanSide: side,
                  board: puliMekaBoard,
                  difficulty: diff,
                ),
              );
            } else if (game.id == 'three_pawns') {
              final pNum = (selectedOptionIndex == 1) ? 2 : 1;
              targetScreen = ThreePawnsScreen(
                config: ThreeConfig(
                  vsComputer: vsComputer,
                  humanPlayer: pNum,
                  difficulty: diff,
                ),
              );
            } else {
              targetScreen = game.screenBuilder(context);
            }

            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => targetScreen),
            );
          },
        );
      },
    );
  }

  void _openRules([String? initialGameId]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RulesScreen(
          games: widget.games,
          initialGameId: initialGameId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroQuickPlayCard(_featuredGame),
                    const SizedBox(height: 22),
                    _buildCategoryPills(),
                    const SizedBox(height: 16),
                    _buildSectionHeader('CHOOSE A GAME', '${_filteredGames.length} available'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _buildGamesGrid(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.bgDark,
      floating: true,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.goldDark.withOpacity(0.2),
              border: Border.all(color: AppTheme.gold, width: 1.5),
            ),
            child: const Icon(Icons.token, color: AppTheme.gold, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'HERITAGE GAMES',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  'Traditional Indian Board Games',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: widget.soundNotifier,
          builder: (context, soundOn, _) => IconButton(
            icon: Icon(
              soundOn ? Icons.volume_up : Icons.volume_off,
              color: soundOn ? AppTheme.gold : AppTheme.textMuted,
            ),
            tooltip: soundOn ? 'Sound On' : 'Sound Muted',
            onPressed: () => widget.onToggleSound(!soundOn),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline, color: AppTheme.textLight),
          tooltip: 'Rules & Guides',
          onPressed: () => _openRules(),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: AppTheme.textLight),
          tooltip: 'Settings',
          onPressed: widget.onOpenSettings,
        ),
      ],
    );
  }

  Widget _buildHeroQuickPlayCard(GameDefinition game) {
    return Container(
      decoration: AppTheme.heroCardDecoration(accent: game.themeColor),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: game.themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: game.themeColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: game.themeColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'SPEED ACCESS • 1-TAP PLAY',
                      style: TextStyle(
                        color: game.themeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.menu_book, color: AppTheme.textMuted, size: 20),
                tooltip: 'Read Rules',
                onPressed: () => _openRules(game.id),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      game.nativeTitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.bgDark.withOpacity(0.5),
                  border: Border.all(color: game.themeColor.withOpacity(0.6), width: 2),
                ),
                padding: const EdgeInsets.all(10),
                child: game.previewArt,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBadge(game.playersCountText, Icons.group),
                  const SizedBox(width: 8),
                  _buildBadge(game.avgDuration, Icons.timer),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: game.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  'PLAY NOW',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: () => _instantPlay(game),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: GameCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = GameCategory.values[index];
          final selected = cat == _selectedCategory;
          return ChoiceChip(
            label: Text(cat.label),
            selected: selected,
            onSelected: (val) {
              if (val) setState(() => _selectedCategory = cat);
            },
            selectedColor: AppTheme.gold,
            backgroundColor: AppTheme.bgCard,
            labelStyle: TextStyle(
              color: selected ? AppTheme.bgDark : AppTheme.textLight,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? AppTheme.gold : const Color(0x33D4AF37),
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String countText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.goldLight,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          countText,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGamesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final game = _filteredGames[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildGameCard(game),
            );
          },
          childCount: _filteredGames.length,
        ),
      ),
    );
  }

  Widget _buildGameCard(GameDefinition game) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openSetupAndPlay(game),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Game Art Thumbnail
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: game.themeColor.withOpacity(0.5), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: game.previewArt,
                ),
                const SizedBox(width: 16),
                // Game Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              game.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: game.themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              game.category.label,
                              style: TextStyle(
                                color: game.themeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        game.nativeTitle,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        game.description,
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildBadge(game.playersCountText, Icons.group),
                          _buildBadge(game.avgDuration, Icons.timer),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppTheme.gold,
                            ),
                            icon: const Icon(Icons.tune, size: 13),
                            label: const Text('Setup', style: TextStyle(fontSize: 11.5)),
                            onPressed: () => _openSetupAndPlay(game),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33D4AF37)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.gold),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
