// lib/screens/deck_spread/deck_spread_personal.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'base_deck_spread_screen.dart';

class DeckSpreadPersonalScreen extends StatefulWidget {
  const DeckSpreadPersonalScreen({super.key});

  @override
  State<DeckSpreadPersonalScreen> createState() => _DeckSpreadPersonalScreenState();
}

/// ────────────────────────────────────────────────────────────────
/// Tap-through overlay (last tap closes). σ=12 blur, vignette.
/// ────────────────────────────────────────────────────────────────
class GuidedIntentOverlay extends StatefulWidget {
  final List<String> lines;
  final VoidCallback onDone;

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
      widget.onDone(); // last tap closes to deck
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
          // Blur + scrim
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withOpacity(0.60)),
            ),
          ),
          // Vignette
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
          // Hint ONLY (no button)
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
/// Screen: question entry → overlay-driven deck flow
/// ────────────────────────────────────────────────────────────────
class _DeckSpreadPersonalScreenState extends State<DeckSpreadPersonalScreen> {
  final TextEditingController _questionController = TextEditingController();
  bool _showDeckScreen = false;

  // Overlay state
  bool _showOverlay = false;
  List<String> _overlayLines = const [];
  String _currentDeckName = "Tarot";
  int _currentDeckNeed = 3;

  String _safeQuestion() {
    final q = _questionController.text.trim();
    if (q.length <= 120) return q;
    return q.substring(0, 117) + '…';
    // keeps overlays from wrapping too much on smaller devices
  }

  List<String> _scriptForDeck(String deckName, int need) {
    final q = _safeQuestion();
    switch (deckName) {
      case "Tarot":
        return [
          "Hold your question softly:\n“$q”.",
          "Intention: layered insight, the unseen factor, and likely direction.",
          "Now draw from Tarot. Choose $need card${need == 1 ? '' : 's'} by first pull—don’t overthink.",
        ];
      case "Oracle":
        return [
          "Good. Let perspective widen around “$q”.",
          "Intention: a kinder angle and the next small step within your timeframe.",
          "Now pick from Oracle. Choose $need—let the gentlest pointer stand out first.",
        ];
      case "Messages":
        return [
          "Breathe once; release the need to control the answer.",
          "Intention: a direct nudge related to “$q”.",
          "Now pick Messages. Choose $need by what lands true in your body.",
        ];
      case "Affirmations":
        return [
          "Steady the shoulders; soften your jaw.",
          "Intention: one mantra you can repeat while acting on “$q”.",
          "Now pick an Affirmation. Choose $need—select what feels strong and simple.",
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
    if (!_showDeckScreen) {
      return Scaffold(
        backgroundColor: Colors.deepPurple.shade900,
        appBar: AppBar(
          backgroundColor: Colors.deepPurple.shade700,
          title: const Text("✨ Ask Your Question ✨"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Type your question clearly — whether it's about love, career, your life path, or any decision.",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _questionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.deepPurple.shade700,
                  hintText: "Type your question here...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_questionController.text.trim().isNotEmpty) {
                      setState(() => _showDeckScreen = true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please type your question.")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("🔮 Proceed to Your Reading", style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      );
    }

    final topForChip = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Stack(
      children: [
        // Base flow with overlay between decks (no prep/micro-copy)
        Positioned.fill(
          child: BaseDeckSpreadScreen(
            title: "✨ Personal Question Reading",
            customIntroText: "Your question: \"${_questionController.text}\"",

            backgroundAsset: 'assets/backgrounds/bg_personal.png',

            showPrep: false,
            captureIntention: false,
            showDeckMicroCopy: false,

            deckTopGap: 16.0,
            gridPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

            onDeckStart: _handleDeckStart,

            prompts: const {},

            deckLimits: const {
              "Tarot": 3,
              "Oracle": 2,
              "Messages": 2,
              "Affirmations": 1,
            },
            deckCounts: const {
              "Tarot": 78,
              "Oracle": 52,
              "Messages": 104,
              "Affirmations": 40,
            },
            deckOrder: const ["Tarot", "Oracle", "Messages", "Affirmations"],
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

        // Cinematic overlay
        if (_showOverlay)
          GuidedIntentOverlay(
            lines: _overlayLines,
            onDone: () => setState(() => _showOverlay = false),
          ),
      ],
    );
  }
}
