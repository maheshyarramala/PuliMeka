import 'package:flutter/material.dart';
import '../models/game_definition.dart';
import '../theme/app_theme.dart';

class RulesScreen extends StatefulWidget {
  final List<GameDefinition> games;
  final String? initialGameId;

  const RulesScreen({
    super.key,
    required this.games,
    this.initialGameId,
  });

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialGameId != null) {
      final found = widget.games.indexWhere((g) => g.id == widget.initialGameId);
      if (found != -1) initialIndex = found;
    }
    _tabController = TabController(
      length: widget.games.length,
      initialIndex: initialIndex,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSurface,
        elevation: 2,
        title: const Text(
          'HERITAGE RULES & GUIDES',
          style: TextStyle(
            color: AppTheme.gold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.gold,
          indicatorWeight: 3,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            for (final g in widget.games)
              Tab(text: g.title),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final game in widget.games)
            _buildGameRulesView(game),
        ],
      ),
    );
  }

  Widget _buildGameRulesView(GameDefinition game) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Game Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.heroCardDecoration(accent: game.themeColor),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: game.previewArt,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      game.nativeTitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildBadge(game.playersCountText, Icons.group),
                        const SizedBox(width: 8),
                        _buildBadge(game.avgDuration, Icons.timer),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rules Sections
        for (final section in game.rules)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: AppTheme.cardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(section.icon, color: game.themeColor, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          color: AppTheme.goldLight,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final point in section.bulletPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: game.themeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              color: AppTheme.textLight,
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.gold),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
