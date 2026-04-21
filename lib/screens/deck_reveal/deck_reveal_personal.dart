import 'package:flutter/material.dart';
import 'base_deck_reveal_screen.dart';

class DeckRevealPersonal extends StatelessWidget {
  final String question;
  final Map<String, List<String>> selectedCardsByDeck;

  const DeckRevealPersonal({
    super.key,
    required this.question,
    required this.selectedCardsByDeck,
  });

  @override
  Widget build(BuildContext context) {
    return BaseDeckRevealScreen(
      title: 'Personal Question',                 // ensures canonical readingType === 'personal'
      userQuestion: question,                     // pass the actual question forward
      selectedCardsByDeck: selectedCardsByDeck,
      deckOrder: const ['tarot', 'oracle', 'messages', 'affirmations'],
    );
  }
}
