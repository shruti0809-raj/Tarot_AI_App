import 'package:flutter/material.dart';
import 'base_deck_reveal_screen.dart';

class DeckRevealAngel extends StatelessWidget {
  final Map<String, List<String>> selectedCardsByDeck;

  const DeckRevealAngel({super.key, required this.selectedCardsByDeck});

  @override
  Widget build(BuildContext context) {
    return BaseDeckRevealScreen(
      title: 'Angel Messages',
      selectedCardsByDeck: selectedCardsByDeck,
      deckOrder: const ['oracle', 'messages', 'affirmations', 'charms'],
    );
  }
}
