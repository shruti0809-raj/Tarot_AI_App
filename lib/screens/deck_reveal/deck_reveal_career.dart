import 'package:flutter/material.dart';
import 'base_deck_reveal_screen.dart';

class DeckRevealCareer extends StatelessWidget {
  final Map<String, List<String>> selectedCardsByDeck;

  const DeckRevealCareer({super.key, required this.selectedCardsByDeck});

  @override
  Widget build(BuildContext context) {
    return BaseDeckRevealScreen(
      title: 'Career Reading',
      selectedCardsByDeck: selectedCardsByDeck,
      deckOrder: const ['tarot', 'oracle', 'affirmations', 'charms'],
    );
  }
}
