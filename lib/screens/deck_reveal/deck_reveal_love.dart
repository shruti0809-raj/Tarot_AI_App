import 'package:flutter/material.dart';
import 'base_deck_reveal_screen.dart';

class DeckRevealLove extends StatelessWidget {
  final Map<String, List<String>> selectedCardsByDeck;

  const DeckRevealLove({super.key, required this.selectedCardsByDeck});

  @override
  Widget build(BuildContext context) {
    return BaseDeckRevealScreen(
      title: 'Love Reading',
      selectedCardsByDeck: selectedCardsByDeck,
      deckOrder: const ['tarot', 'oracle', 'messages', 'charms'],
    );
  }
}
