// lib/screens/deck_spread/deck_spread_career.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'base_deck_spread_screen.dart';

/// ────────────────────────────────────────────────────────────────
/// Manual-advance overlay (tap = next line; last tap closes)
/// Strong scrim, σ=12 blur, vignette, NO underline, and NO CTA button.
/// ────────────────────────────────────────────────────────────────
class GuidedIntentOverlay extends StatefulWidget {
  final List<String> lines;   // lines to show in order
  final VoidCallback onDone;  // closes overlay (also triggered by last tap)

  const GuidedIntentOverlay({
    super.key,
    required this.lines,
    required this.onDone,
  });

  @override
  State<GuidedIntentOverlay> createState() => _GuidedIntentOverlayState();
}

class _GuidedIntentOverlayState extends State<GuidedIntentOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    if (widget.lines.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else {
      _fade.forward(from: 0);
    }
  }

  Future<void> _nextOrClose() async {
    final atLast = _index >= widget.lines.length - 1;
    if (atLast) {
      widget.onDone(); // last tap closes
      return;
    }
    await _fade.reverse();
    if (!mounted) return;
    setState(() => _index++);
    await _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _nextOrClose,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Blur + darker scrim + vignette
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withOpacity(0.60)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
                    stops: const [0.70, 1.00],
                  ),
                ),
              ),
            ),
          ),

          // Animated line
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _opacity,
                builder: (context, child) {
                  final scale = 0.98 + 0.02 * _opacity.value;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: _opacity.value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    widget.lines[_index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.35,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom hint ONLY (no button)
          const Positioned(
            left: 0, right: 0, bottom: 36,
            child: Text(
              "Tap for next line",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// CAREER READING SCREEN (overlay between decks; top-right Re-center)
/// Background uses PNG created earlier for Career.
/// ────────────────────────────────────────────────────────────────
class DeckSpreadCareerScreen extends StatefulWidget {
  const DeckSpreadCareerScreen({super.key});

  @override
  State<DeckSpreadCareerScreen> createState() => _DeckSpreadCareerScreenState();
}

class _DeckSpreadCareerScreenState extends State<DeckSpreadCareerScreen> {
  bool _showOverlay = false;
  List<String> _overlayLines = const [];

  // Track current deck so "Re-center" shows the right script
  String _currentDeckName = "Tarot";
  int _currentDeckNeed = 6;

  // Story-like, deck-specific scripts (short, actionable, career-focused)
  List<String> _scriptForDeck(String deckName, int need) {
    switch (deckName) {
      case "Tarot":
        return [
          "Settle your breath. In… 4, out… 6.",
          "Intention: see your path, your strength, and the honest block.",
          "Now draw from Tarot. Choose $need card${need == 1 ? '' : 's'} by first pull—don’t overthink.",
        ];
      case "Oracle":
        return [
          "Good. You’ve named the terrain.",
          "Intention: timing nudges and the next lever you can pull.",
          "Now pick from Oracle. Choose $need—let opportunity cards stand out to you.",
        ];
      case "Affirmations":
        return [
          "Breathe into the chest; relax the shoulders.",
          "Intention: words that steady action and visibility.",
          "Now pick Affirmations. Choose $need by what feels strengthening in your body.",
        ];
      case "Charms":
        return [
          "You’re aligned. Keep the pace, not the panic.",
          "Intention: a sign that confirms traction in the next 2 weeks.",
          "Now pick Charms. Choose $need—follow the first symbol that lights up for you.",
        ];
      default:
        return [
          "Breathe in… and out.",
          "Hold a clear intention for this deck.",
          "Now draw $need from $deckName.",
        ];
    }
  }

  void _handleDeckStart(String deckName, int requiredCount) {
    setState(() {
      _currentDeckName = deckName;
      _currentDeckNeed = requiredCount;
      _overlayLines = _scriptForDeck(deckName, requiredCount);
      _showOverlay = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topForChip = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Stack(
      children: [
        // Base renders grids + sticky footer; we disable prep & micro-copy.
        Positioned.fill(
          child: BaseDeckSpreadScreen(
            title: "💼 Career Reading",

            // ✅ Use your PNG background for career
            backgroundAsset: 'assets/backgrounds/bg_career.png',

            // Use overlay flow (no micro-copy/prep screens)
            showPrep: false,
            captureIntention: false,
            showDeckMicroCopy: false,

            // Spacing so headings never collide with first row
            deckTopGap: 16.0,
            gridPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

            // Overlay trigger per deck
            onDeckStart: _handleDeckStart,

            // Prompts are unused in this overlay flow
            prompts: const {},

            // Deck settings for Career
            deckLimits: const {
              "Tarot": 6,
              "Oracle": 4,
              "Affirmations": 4,
              "Charms": 3,
            },
            deckCounts: const {
              "Tarot": 78,
              "Oracle": 52,
              "Affirmations": 40,
              "Charms": 20,
            },
            deckOrder: const ["Tarot", "Oracle", "Affirmations", "Charms"],
          ),
        ),

        // Top-right "Re-center" chip
        Positioned(
          right: 12,
          top: topForChip,
          child: Material(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _overlayLines = _scriptForDeck(_currentDeckName, _currentDeckNeed);
                  _showOverlay = true;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "Re-center",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Cinematic overlay (tap-through; last tap closes)
        if (_showOverlay)
          GuidedIntentOverlay(
            lines: _overlayLines,
            onDone: () => setState(() => _showOverlay = false),
          ),
      ],
    );
  }
}
