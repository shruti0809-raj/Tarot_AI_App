// lib/screens/deck_spread/base_deck_spread_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import '../deck_reveal/deck_reveal_love.dart';
import '../deck_reveal/deck_reveal_career.dart';
import '../deck_reveal/deck_reveal_angel.dart';
import '../deck_reveal/deck_reveal_fullmoon.dart';
import '../deck_reveal/deck_reveal_personal.dart';
import '../deck_reveal/deck_reveal_sunsign.dart';

/// Lightweight data holder for per-deck intro copy
class DeckIntroData {
  final String purpose; // one-liner about what this deck reveals
  final List<String> questions; // 2–4 prompts to focus intention
  const DeckIntroData({required this.purpose, required this.questions});
}

/// Read-only snapshot for footer/overlay builders
class DeckProgress {
  final int deckIndex;      // 0-based
  final int deckCount;      // total decks
  final String deckName;
  final int selected;       // selected in current deck
  final int required;       // required for current deck
  const DeckProgress({
    required this.deckIndex,
    required this.deckCount,
    required this.deckName,
    required this.selected,
    required this.required,
  });
}

class BaseDeckSpreadScreen extends StatefulWidget {
  final String title;
  final Map<String, int> deckLimits; // how many to pick from each deck
  final Map<String, int> deckCounts; // available cards in each deck
  final Map<String, List<String>> prompts; // per-draw prompts (Tarot)
  final List<String> deckOrder; // order of decks to draw
  final String? customIntroText; // optional intro (e.g., question, sun sign)

  // Immersive UX knobs
  final bool showPrep; // show a preparation screen before deck 1
  final String? prepHeadline; // calming headline on prep
  final String? prepSummary; // 2–4 lines explaining flow and mindset
  final bool captureIntention; // intention/timeframe fields on prep
  final Map<String, DeckIntroData>? deckIntros; // micro-guidance cards

  // Visual/flow controls
  final bool showDeckMicroCopy; // shows the micro "dialog card" per deck
  final double deckTopGap; // gap between deck header and first card row
  final EdgeInsets gridPadding; // padding around card rows/grid
  final void Function(String deckName, int requiredCount)? onDeckStart; // callback at deck start
  final Widget Function(DeckProgress p, bool canContinue, VoidCallback onNext)?
      bottomBarBuilder; // sticky footer builder

  /// Full-screen background image (behind everything)
  final String? backgroundAsset;

  /// Optional fixed footer height (used to guarantee min scroll height)
  final double footerHeight;

  const BaseDeckSpreadScreen({
    super.key,
    required this.title,
    required this.deckLimits,
    required this.deckCounts,
    required this.prompts,
    required this.deckOrder,
    this.customIntroText,
    this.showPrep = false,
    this.prepHeadline,
    this.prepSummary,
    this.captureIntention = true,
    this.deckIntros,
    this.showDeckMicroCopy = true,
    this.deckTopGap = 16.0,
    this.gridPadding = const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    this.onDeckStart,
    this.bottomBarBuilder,
    this.backgroundAsset,
    this.footerHeight = 96.0,
  });

  @override
  State<BaseDeckSpreadScreen> createState() => _BaseDeckSpreadScreenState();
}

class _BaseDeckSpreadScreenState extends State<BaseDeckSpreadScreen> {
  late Map<String, List<String>> shuffledDecks;
  late Map<String, List<String>> selectedCards;
  late Map<String, List<Map<String, dynamic>>> selectedCardSequence;
  late Map<String, bool> _introSeen; // per-deck intro overlay seen flag

  int currentDeckIndex = 0;
  bool _inPrep = false;

  // Prep inputs (optional)
  final TextEditingController _intentionCtl = TextEditingController();
  final TextEditingController _timeframeCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inPrep = widget.showPrep; // enable prep if requested
    _initializeDecks();

    // Background precache to avoid flicker
    if (widget.backgroundAsset != null && widget.backgroundAsset!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        precacheImage(AssetImage(widget.backgroundAsset!), context);
      });
    }

    // If skipping prep and not showing micro-copy, immediately enter deck 0
    if (!_inPrep && !widget.showDeckMicroCopy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enterDeck(0, triggerCallback: true, shuffle: true);
      });
    } else {
      // Fire onDeckStart for the first deck so overlays can prep copy
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final firstDeck = widget.deckOrder.first;
        widget.onDeckStart?.call(firstDeck, widget.deckLimits[firstDeck] ?? 0);
      });
    }
  }

  @override
  void dispose() {
    _intentionCtl.dispose();
    _timeframeCtl.dispose();
    super.dispose();
  }

  void _initializeDecks() {
    shuffledDecks = {};
    selectedCards = {};
    selectedCardSequence = {};
    _introSeen = {};

    for (var deck in widget.deckCounts.keys) {
      final cards =
          List.generate(widget.deckCounts[deck]!, (i) => 'card${i + 1}.jpg')..shuffle(Random());
      shuffledDecks[deck] = cards;
      selectedCards[deck] = [];
      selectedCardSequence[deck] = [];
      _introSeen[deck] = false; // no intro shown yet
    }
  }

  void _shuffleDeck(String deck) {
    HapticFeedback.mediumImpact();
    setState(() {
      final cards =
          List.generate(widget.deckCounts[deck]!, (i) => 'card${i + 1}.jpg')..shuffle(Random());
      shuffledDecks[deck] = cards;
      selectedCards[deck] = [];
      selectedCardSequence[deck] = [];
    });
  }

  void _onCardTap(String deck, String cardName) {
    final int max = widget.deckLimits[deck] ?? 0;
    if (max <= 0) return;

    if (selectedCards[deck]!.contains(cardName)) return;
    if (selectedCards[deck]!.length < max) {
      HapticFeedback.selectionClick();
      setState(() {
        selectedCards[deck]!.add(cardName);
        selectedCardSequence[deck]!.add({
          "card": cardName,
          "order": selectedCards[deck]!.length,
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limit reached ($max/$max) for $deck'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Enter a deck index, optionally shuffling and triggering the onDeckStart callback.
  void _enterDeck(int index, {bool triggerCallback = false, bool shuffle = false}) {
    if (index < 0 || index >= widget.deckOrder.length) return;
    final deckName = widget.deckOrder[index];
    final need = widget.deckLimits[deckName] ?? 0;

    setState(() {
      currentDeckIndex = index;
      if (!widget.showDeckMicroCopy) _introSeen[deckName] = true; // skip micro card
      if (shuffle) _shuffleDeck(deckName);
    });

    if (triggerCallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDeckStart?.call(deckName, need);
      });
    }
  }

  Widget _buildDeckIntroCard(String deckName) {
    final count = widget.deckLimits[deckName] ?? 1;
    final intro = widget.deckIntros?[deckName];
    final purpose = intro?.purpose ?? 'Focus your intention for this draw.';
    final questions = intro?.questions ?? const [
      'What am I meant to notice?',
      'Where is guidance trying to lead me?',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
            SizedBox(width: 8),
          ]),
          Row(
            children: [
              Text(
                '$deckName • Draw $count',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(purpose, style: const TextStyle(color: Colors.white70, height: 1.3)),
          const SizedBox(height: 8),
          ...questions.take(3).map(
            (q) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.white60)),
                  Expanded(child: Text(q, style: const TextStyle(color: Colors.white60, height: 1.25))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _introSeen[deckName] = true);
                _shuffleDeck(deckName);
                // Notify overlay/copy
                final need = widget.deckLimits[deckName] ?? 0;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onDeckStart?.call(deckName, need);
                });
              },
              child: const Text('Shuffle & draw →', style: TextStyle(color: Colors.amber)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeck(String deckName) {
    final deck = shuffledDecks[deckName] ?? const <String>[];
    final maxCount = widget.deckLimits[deckName] ?? 0;
    final rows = (deck.length / 26).ceil();
    final currentPrompt = widget.prompts[deckName] ?? const <String>[];
    final selectedCount = (selectedCards[deckName] ?? const <String>[]).length;

    return Padding(
      padding: widget.gridPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$deckName • Pick $maxCount",
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none),
              ),
            ],
          ),
          SizedBox(height: widget.deckTopGap),

          // Tarot micro-prompt (only if explicitly allowed)
          if (widget.showDeckMicroCopy &&
              deckName == "Tarot" &&
              selectedCount < maxCount &&
              selectedCount < currentPrompt.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                currentPrompt[selectedCount],
                style: const TextStyle(color: Colors.white70, fontSize: 14, decoration: TextDecoration.none),
                textAlign: TextAlign.center,
              ),
            ),

          // Overlapped rows of card backs
          Column(
            children: List.generate(rows, (rowIndex) {
              final start = rowIndex * 26;
              final end = min(start + 26, deck.length);
              final rowCards = deck.sublist(start, end);

              return LayoutBuilder(
                builder: (context, constraints) {
                  const double cardWidth = 70;
                  const double overlap = cardWidth * 0.85;
                  final double totalWidth = (rowCards.length - 1) * (cardWidth - overlap) + cardWidth;
                  final double startOffset = max(0, (constraints.maxWidth - totalWidth) / 2);

                  return SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(rowCards.length, (i) {
                        final card = rowCards[i];
                        final isSelected = selectedCards[deckName]!.contains(card);
                        return Positioned(
                          left: startOffset + i * (cardWidth - overlap),
                          child: GestureDetector(
                            onTap: () => _onCardTap(deckName, card),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              transform: Matrix4.translationValues(0, isSelected ? -18 : 0, 0)
                                ..scale(isSelected ? 1.02 : 1.0),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.deepPurpleAccent : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.deepPurpleAccent.withOpacity(0.55),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Image.asset(
                                'assets/cards/${deckName.toLowerCase()}/card_back.jpg',
                                width: cardWidth,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              );
            }),
          ),

          const SizedBox(height: 10),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _onProceed() {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? widget.title;
    Widget screen;

    switch (currentRoute) {
      case '/love-spread':
      case '💖 Love Reading':
        screen = DeckRevealLove(selectedCardsByDeck: selectedCards);
        break;
      case '/career-spread':
      case '💼 Career Reading':
        screen = DeckRevealCareer(selectedCardsByDeck: selectedCards);
        break;
      case '/angel-spread':
      case '👼 Angel Guidance Reading':
        screen = DeckRevealAngel(selectedCardsByDeck: selectedCards);
        break;
      case '/fullmoon-spread':
      case '🌕 Full Moon / Retrograde Reading':
        screen = DeckRevealFullMoon(selectedCardsByDeck: selectedCards);
        break;
      case '/personal-spread':
      case '✨ Personal Question Reading':
        final question = (widget.customIntroText ?? '')
            .replaceAll('Your question: ', '')
            .replaceAll('"', '')
            .trim();
        screen = DeckRevealPersonal(
          question: question,
          selectedCardsByDeck: selectedCards,
        );
        break;
      case '/sunsign-spread':
      case '🌞 Daily Sun Sign Reading':
        final sign = (widget.customIntroText ?? '')
            .replaceAll('Based on your Sun Sign: ', '')
            .replaceAll(',', '')
            .trim();
        screen = DeckRevealSunSign(
          sunSign: sign,
          selectedCardsByDeck: selectedCards,
        );
        break;
      default:
        screen = const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              '⚠️ Reveal screen not found.',
              style: TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        );
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildPrepScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.customIntroText != null && widget.customIntroText!.isNotEmpty) ...[
          Text(
            widget.customIntroText!,
            style: const TextStyle(color: Colors.amberAccent, fontSize: 16, decoration: TextDecoration.none),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
        ],
        Text(
          widget.prepHeadline ?? 'Set your intention',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.prepSummary ??
              'We will draw cards across the decks below. Take a slow breath in (4) and out (6).\nThink of a clear question or feeling. When ready, begin.',
          style: const TextStyle(color: Colors.white70, height: 1.35, decoration: TextDecoration.none),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What you will draw',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...widget.deckOrder.map((deck) {
                final lim = widget.deckLimits[deck] ?? 1;
                final intro = widget.deckIntros?[deck];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.style, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$deck • $lim card${lim > 1 ? 's' : ''}',
                                style: const TextStyle(color: Colors.white)),
                            if (intro != null) ...[
                              const SizedBox(height: 2),
                              Text(intro.purpose,
                                  style: const TextStyle(color: Colors.white60)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        if (widget.captureIntention) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _intentionCtl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Your intention (optional)',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder:
                  OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
              focusedBorder:
                  OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(12)),
              fillColor: Colors.white.withOpacity(0.05),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timeframeCtl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Timeframe (e.g., next 30 days)',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder:
                  OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
              focusedBorder:
                  OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(12)),
              fillColor: Colors.white.withOpacity(0.05),
              filled: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _inPrep = false);
            if (!widget.showDeckMicroCopy) {
              _enterDeck(0, triggerCallback: true, shuffle: true);
            } else {
              final firstDeck = widget.deckOrder.first;
              setState(() => _introSeen[firstDeck] = false);
            }
          },
          child: const Text("I'm ready →", style: TextStyle(fontSize: 16, color: Colors.amber)),
        ),
      ],
    );
  }

  DeckProgress _progressFor(String deckName) {
    return DeckProgress(
      deckIndex: currentDeckIndex,
      deckCount: widget.deckOrder.length,
      deckName: deckName,
      selected: selectedCards[deckName]?.length ?? 0,
      required: widget.deckLimits[deckName] ?? 0,
    );
  }

  Widget _defaultBottomBar(DeckProgress p, bool canContinue, VoidCallback onNext) {
    final double frac = p.required == 0 ? 0 : (p.selected / p.required).clamp(0.0, 1.0);
    final bool isLast = p.deckIndex == p.deckCount - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.black.withOpacity(0.6),
          Colors.black.withOpacity(0.35),
        ], begin: Alignment.bottomCenter, end: Alignment.topCenter),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left: Selected X/Y + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Selected ${p.selected}/${p.required}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Deck ${p.deckIndex + 1} of ${p.deckCount} — ${p.deckName}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: CTA
            ElevatedButton(
              onPressed: canContinue ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isLast ? "Reveal reading" : "Next deck"),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextPressed() {
    final currentDeck = widget.deckOrder[currentDeckIndex];
    final need = widget.deckLimits[currentDeck] ?? 0;
    final got = selectedCards[currentDeck]?.length ?? 0;

    if (got < need) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pick $need cards to continue'),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (currentDeckIndex == widget.deckOrder.length - 1) {
      _onProceed();
      return;
    }

    // Move to next deck
    final nextIndex = currentDeckIndex + 1;
    if (widget.showDeckMicroCopy) {
      setState(() {
        currentDeckIndex = nextIndex;
        final nextDeck = widget.deckOrder[currentDeckIndex];
        _introSeen[nextDeck] = false; // show the micro-copy card
      });
      // also notify overlay/copy
      final nd = widget.deckOrder[nextIndex];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDeckStart?.call(nd, widget.deckLimits[nd] ?? 0);
      });
    } else {
      _enterDeck(nextIndex, triggerCallback: true, shuffle: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDeck = widget.deckOrder[currentDeckIndex];
    final need = widget.deckLimits[currentDeck] ?? 0;
    final got = selectedCards[currentDeck]?.length ?? 0;
    final allSelected = got == need;

    final progress = _progressFor(currentDeck);
    final bottomBar = (widget.bottomBarBuilder ?? _defaultBottomBar)(
      progress,
      allSelected,
      _handleNextPressed,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
              stops: [0.0, 1.0],
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // FULL-SCREEN BACKGROUND + protective overlays
          if (widget.backgroundAsset != null && widget.backgroundAsset!.isNotEmpty) ...[
            Positioned.fill(
              child: Image.asset(widget.backgroundAsset!, fit: BoxFit.cover),
            ),
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.22))),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black26, Colors.transparent, Colors.black26],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // CONTENT + STICKY FOOTER
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minScrollHeight = constraints.maxHeight - widget.footerHeight;
                  return Column(
                    children: [
                      // Scrollable content; guarantees at least viewport height so BG is always full.
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            max(0.0, widget.gridPadding.left),
                            max(0.0, widget.gridPadding.top),
                            max(0.0, widget.gridPadding.right),
                            16.0, // small gap above footer
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: minScrollHeight),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1000),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (_inPrep) ...[
                                      _buildPrepScreen(),
                                    ] else ...[
                                      if (widget.showDeckMicroCopy &&
                                          !(_introSeen[currentDeck] ?? false) &&
                                          (selectedCards[currentDeck]?.isEmpty ?? true))
                                        _buildDeckIntroCard(currentDeck),

                                      _buildDeck(currentDeck),
                                      const SizedBox(height: 20),
                                      Text(
                                        _inPrep
                                            ? 'Prep'
                                            : "${currentDeckIndex + 1} / ${widget.deckOrder.length}",
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // STICKY FOOTER
                      SizedBox(
                        height: widget.footerHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: bottomBar,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
