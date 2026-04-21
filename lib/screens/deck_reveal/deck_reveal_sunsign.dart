import 'package:flutter/material.dart';
import 'base_deck_reveal_screen.dart';

class DeckRevealSunSign extends StatelessWidget {
  final String sunSign;
  final Map<String, List<String>> selectedCardsByDeck;

  const DeckRevealSunSign({
    super.key,
    required this.sunSign,
    required this.selectedCardsByDeck,
  });

  @override
  Widget build(BuildContext context) {
    return BaseDeckRevealScreen(
      title: 'Your Sun Sign: $sunSign',
      zodiacSign: sunSign, // pass zodiac to final flow
      selectedCardsByDeck: selectedCardsByDeck,
      deckOrder: const ['tarot', 'oracle', 'affirmations'],
    );
  }
}
