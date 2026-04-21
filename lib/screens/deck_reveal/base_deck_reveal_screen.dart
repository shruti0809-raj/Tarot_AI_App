import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class BaseDeckRevealScreen extends StatefulWidget {
  final String title;
  final Map<String, List<String>> selectedCardsByDeck;
  final List<String> deckOrder;

  // Optional extras (used by Personal Question / Sun Sign)
  final String? userQuestion;
  final String? zodiacSign;

  const BaseDeckRevealScreen({
    Key? key,
    required this.title,
    required this.selectedCardsByDeck,
    required this.deckOrder,
    this.userQuestion,
    this.zodiacSign,
  }) : super(key: key);

  @override
  State<BaseDeckRevealScreen> createState() => _BaseDeckRevealScreenState();
}

class _BaseDeckRevealScreenState extends State<BaseDeckRevealScreen>
    with TickerProviderStateMixin {
  final Map<String, int> revealedCounts = {};
  final Map<String, Timer> timers = {};
  final Map<String, int> _totals = {};

  // Normalized inputs
  late final Map<String, List<String>> _cards;   // lowercase keys, filenames-only
  late final List<String> _deckOrder;            // lowercase deck order

  bool _charging = true; // overlay visible while cards are revealing
  bool _charged = false; // enables CTA when all done
  late final String _sessionId;

  @override
  void initState() {
    super.initState();

    // Normalize deck order to lowercase
    _deckOrder = widget.deckOrder.map((d) => d.toLowerCase()).toList();

    // Normalize cards: lowercase deck keys, filenames-only (strip any path)
    _cards = {
      for (final e in widget.selectedCardsByDeck.entries)
        e.key.toLowerCase(): e.value.map((c) => c.split('/').last).toList(),
    };

    // Init per-deck state
    for (final deck in _deckOrder) {
      final total = _cards[deck]?.length ?? 0;
      _totals[deck] = total;
      revealedCounts[deck] = 0;
    }

    _sessionId = '${DateTime.now().millisecondsSinceEpoch}-${UniqueKey()}';
    _startRevealSequence();
  }

  void _startRevealSequence() {
    // Start a periodic timer per deck and keep references so we can cancel on dispose
    for (final deck in _deckOrder) {
      final total = _totals[deck] ?? 0;

      // If a deck has no cards, consider it done immediately
      if (total == 0) {
        revealedCounts[deck] = 0;
        _maybeFinishCharging();
        continue;
      }

      int revealed = 0;
      final t = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!mounted) return; // safety
        if (revealed < total) {
          setState(() {
            revealedCounts[deck] = (revealedCounts[deck] ?? 0) + 1;
          });
          revealed++;
        } else {
          timer.cancel();
          timers.remove(deck);
          _maybeFinishCharging();
        }
      });

      timers[deck] = t;
    }
  }

  void _maybeFinishCharging() {
    // When every deck's revealed count has reached its total, release the overlay & enable CTA
    final allDone = _deckOrder.every((deck) {
      final total = _totals[deck] ?? 0;
      final count = revealedCounts[deck] ?? 0;
      return count >= total;
    });

    if (allDone && mounted) {
      setState(() {
        _charging = false;
        _charged = true;
      });
    }
  }

  String _canonicalReadingTypeFromTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('personal')) return 'personal';
    if (t.contains('love')) return 'love';
    if (t.contains('career')) return 'career';
    if (t.contains('sun sign') || t.contains('sunsign') || t.contains('zodiac')) return 'sunsign';
    if (t.contains('angel')) return 'angel';
    if (t.contains('full moon') || t.contains('fullmoon')) return 'fullmoon';
    return 'general';
  }

  @override
  void dispose() {
    // Cancel all timers we started
    for (final t in timers.values) {
      t.cancel();
    }
    timers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final deck in _deckOrder) ...[
                  Text(
                    'Your ${deck[0].toUpperCase()}${deck.substring(1)} cards:',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: revealedCounts[deck] ?? 0,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, i) {
                      final fileName = _cards[deck]![i]; // filenames-only
                      final path = 'assets/cards/$deck/$fileName';
                      return _AnimatedCardWidget(
                        cardText: path,
                        deck: deck,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                Center(
                  child: ElevatedButton(
                    onPressed: _charged
                        ? () {
                            // We already normalized: lowercase keys, filenames-only
                            final canonicalType = _canonicalReadingTypeFromTitle(widget.title);

                            Navigator.pushNamed(
                              context,
                              '/final-reading',
                              arguments: {
                                'sessionId': _sessionId,
                                'cards': _cards,
                                'title': widget.title,
                                'readingType': canonicalType,
                                if (widget.zodiacSign != null && widget.zodiacSign!.trim().isNotEmpty)
                                  'zodiacSign': widget.zodiacSign,
                                if (widget.userQuestion != null && widget.userQuestion!.trim().isNotEmpty) ...{
                                  'userQuestion': widget.userQuestion,      // primary key
                                  'personalQuestion': widget.userQuestion,  // backward-compat
                                },
                              },
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: _charging
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Move to Final Reading'),
                  ),
                ),
              ],
            ),
          ),

          // Blocks UI only while charging
          if (_charging)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedCardWidget extends StatefulWidget {
  final String cardText;
  final String deck;

  const _AnimatedCardWidget({Key? key, required this.cardText, required this.deck})
      : super(key: key);

  @override
  State<_AnimatedCardWidget> createState() => _AnimatedCardWidgetState();
}

class _AnimatedCardWidgetState extends State<_AnimatedCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angle = _flipAnimation.value * pi;
    final backPath = widget.cardText.replaceAll(RegExp(r'/[^/]+$'), '/card_back.jpg');
    return Transform(
      transform: Matrix4.rotationY(angle),
      alignment: Alignment.center,
      child: Card(
        color: angle < 1.57 ? Colors.grey.shade900 : Colors.deepPurple.shade100,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: angle < 1.57
              ? Image.asset(
                  backPath,
                  fit: BoxFit.cover,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: Image.asset(
                      widget.cardText,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
