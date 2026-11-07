import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameSetupSheet extends StatefulWidget {
  final String title;
  final String nativeTitle;
  final Color themeColor;
  final Widget previewArt;
  final bool hasPlayerChoice;
  final List<String> playerOptions;
  final String playerChoiceTitle;
  final void Function({
    required bool vsComputer,
    required int difficultyIndex,
    required int selectedOptionIndex,
  }) onStart;

  const GameSetupSheet({
    super.key,
    required this.title,
    required this.nativeTitle,
    required this.themeColor,
    required this.previewArt,
    this.hasPlayerChoice = true,
    this.playerOptions = const ['Play as Tigers', 'Play as Goats'],
    this.playerChoiceTitle = 'CHOOSE YOUR SIDE',
    required this.onStart,
  });

  @override
  State<GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends State<GameSetupSheet> {
  bool vsComputer = true;
  int difficultyIndex = 1; // 0=Easy, 1=Medium, 2=Hard
  int selectedOptionIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Art
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.themeColor, width: 2),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: widget.previewArt,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.nativeTitle,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mode Toggle
            _sectionLabel('GAME MODE'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _modeButton(
                    icon: Icons.smart_toy_outlined,
                    label: 'vs Computer',
                    selected: vsComputer,
                    onTap: () => setState(() => vsComputer = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modeButton(
                    icon: Icons.people_outline,
                    label: 'Pass & Play',
                    selected: !vsComputer,
                    onTap: () => setState(() => vsComputer = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Difficulty (only if vsComputer)
            if (vsComputer) ...[
              _sectionLabel('DIFFICULTY'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _diffButton('Easy', Icons.sentiment_satisfied_alt, 0),
                  const SizedBox(width: 8),
                  _diffButton('Medium', Icons.sentiment_neutral, 1),
                  const SizedBox(width: 8),
                  _diffButton('Hard', Icons.whatshot, 2),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // Player Choice / Side Options
            if (widget.hasPlayerChoice) ...[
              _sectionLabel(widget.playerChoiceTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < widget.playerOptions.length; i++)
                    ChoiceChip(
                      label: Text(widget.playerOptions[i]),
                      selected: selectedOptionIndex == i,
                      selectedColor: widget.themeColor,
                      backgroundColor: AppTheme.bgCard,
                      labelStyle: TextStyle(
                        color: selectedOptionIndex == i ? Colors.white : AppTheme.textLight,
                        fontWeight: selectedOptionIndex == i ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedOptionIndex == i ? widget.themeColor : const Color(0x33D4AF37),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => selectedOptionIndex = i);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Start Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                icon: const Icon(Icons.play_circle_filled, size: 24),
                label: const Text(
                  'START GAME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStart(
                    vsComputer: vsComputer,
                    difficultyIndex: difficultyIndex,
                    selectedOptionIndex: selectedOptionIndex,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.gold,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? widget.themeColor.withOpacity(0.25) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? widget.themeColor : const Color(0x33D4AF37),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? widget.themeColor : AppTheme.textMuted, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textLight,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diffButton(String label, IconData icon, int index) {
    final selected = difficultyIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => difficultyIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? widget.themeColor.withOpacity(0.2) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? widget.themeColor : const Color(0x33D4AF37),
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? widget.themeColor : AppTheme.textMuted, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
