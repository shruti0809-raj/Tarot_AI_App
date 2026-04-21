import 'package:flutter/material.dart';
import 'base_deck_reveal_screen.dart';

class DeckRevealFullMoon extends StatelessWidget {
  final Map<String, List<String>> selectedCardsByDeck;

  const DeckRevealFullMoon({super.key, required this.selectedCardsByDeck});

  @override
  Widget build(BuildContext context) {
    return BaseDeckRevealScreen(
      title: 'Full Moon Reading',
      selectedCardsByDeck: selectedCardsByDeck,
      deckOrder: const ['tarot', 'oracle', 'affirmations', 'charms'],
    );
  }
}
