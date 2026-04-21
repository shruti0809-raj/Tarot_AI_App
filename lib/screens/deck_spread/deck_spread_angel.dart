// lib/screens/deck_spread/deck_spread_angel.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'base_deck_spread_screen.dart';

/// ────────────────────────────────────────────────────────────────
/// Manual-advance overlay (tap = next line; last tap closes)
/// Strong scrim, σ=12 blur, vignette, NO underline, and NO CTA button.
/// ────────────────────────────────────────────────────────────────
class GuidedIntentOverlay extends StatefulWidget {
  final List<String> lines;      // lines to show in order
  final VoidCallback onDone;     // closes overlay (also triggered by last tap)

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
      // last line -> close overlay
      widget.onDone();
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
      onTap: _nextOrClose, // tap advances; last tap closes
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
            left: 0,
            right: 0,
            bottom: 36,
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
/// ANGEL READING SCREEN
/// - Overlay between decks with deck-specific intentions
/// - Top-right "Re-center" chip
/// - Background uses PNG (fixes broken JPG ref)
/// - ⚠️ Removed the white CTA button; overlay is tap-only now
/// ────────────────────────────────────────────────────────────────
class DeckSpreadAngelScreen extends StatefulWidget {
  const DeckSpreadAngelScreen({super.key});

  @override
  State<DeckSpreadAngelScreen> createState() => _DeckSpreadAngelScreenState();
}

class _DeckSpreadAngelScreenState extends State<DeckSpreadAngelScreen> {
  bool _showOverlay = false;
  List<String> _overlayLines = const [];

  // Track current deck so "Re-center" shows the right script
  String _currentDeckName = "Oracle";
  int _currentDeckNeed = 3;

  List<String> _scriptForDeck(String deckName, int need) {
    // Crisp, deck-specific intention lines (short + actionable)
    switch (deckName) {
      case "Oracle":
        return [
          "Settle your breath. In… 1, 2, 3… out… easy.",
          "Intention: reveal the main theme and the kindest next step.",
          "Now pick from Oracle. Choose $need card${need == 1 ? '' : 's'} by first pull—don’t overthink.",
        ];
      case "Messages":
        return [
          "One slow breath to soften the mind.",
          "Intention: let one clear message reach you now.",
          "Now pick from Messages. Choose $need—go with your first ‘yes’.",
        ];
      case "Affirmations":
        return [
          "Feel your feet. Relax the jaw.",
          "Intention: words that ground and steady you.",
          "Now pick from Affirmations. Choose $need by what feels calming in your body.",
        ];
      case "Charms":
        return [
          "You’re centered. Stay open and curious.",
          "Intention: the sign you’ll notice over the next week.",
          "Now pick from Charms. Choose $need—follow the first image that tugs at you.",
        ];
      default:
        return [
          "Breathe in… 1, 2, 3… and out.",
          "Hold a gentle intention for this draw.",
          "Now pick from $deckName. Choose $need card${need == 1 ? '' : 's'}.",
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

    final base = BaseDeckSpreadScreen(
      title: "👼 Angel Guidance Reading",

      // ✅ Use PNG here (match your asset + pubspec)
      backgroundAsset: 'assets/backgrounds/bg_angel.png',

      // Use overlay flow (no micro-copy cards)
      showPrep: false,
      captureIntention: false,
      showDeckMicroCopy: false,

      // Ensure headings never collide with the first card row
      deckTopGap: 16.0,
      gridPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

      // Overlay trigger per deck
      onDeckStart: _handleDeckStart,

      // Tarot prompts not used for Angel
      prompts: const {},

      // Deck settings for Angel
      deckLimits: const {
        "Oracle": 3,
        "Messages": 2,
        "Affirmations": 2,
        "Charms": 2,
      },
      deckCounts: const {
        "Oracle": 52,
        "Messages": 104,
        "Affirmations": 40,
        "Charms": 20,
      },
      deckOrder: const ["Oracle", "Messages", "Affirmations", "Charms"],
    );

    return Stack(
      children: [
        // Base renders title + grids + sticky footer
        Positioned.fill(child: base),

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
