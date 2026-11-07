import 'package:flutter/material.dart';

enum GameCategory {
  all('All Games'),
  strategy('Hunt & Strategy'),
  race('Dice & Race'),
  alignment('Alignment & Mills'),
  mancala('Pits & Sowing');

  final String label;
  const GameCategory(this.label);
}

class GameDefinition {
  final String id;
  final String title;
  final String nativeTitle;
  final String subtitle;
  final String description;
  final GameCategory category;
  final String playersCountText;
  final String avgDuration;
  final Color themeColor;
  final Widget previewArt;
  final Widget Function(BuildContext context) screenBuilder;
  final List<RuleSection> rules;

  const GameDefinition({
    required this.id,
    required this.title,
    required this.nativeTitle,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.playersCountText,
    required this.avgDuration,
    required this.themeColor,
    required this.previewArt,
    required this.screenBuilder,
    required this.rules,
  });
}

class RuleSection {
  final String title;
  final IconData icon;
  final List<String> bulletPoints;

  const RuleSection({
    required this.title,
    required this.icon,
    required this.bulletPoints,
  });
}
