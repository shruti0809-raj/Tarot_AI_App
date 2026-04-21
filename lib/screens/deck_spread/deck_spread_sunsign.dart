// lib/screens/deck_spread/deck_spread_sunsign.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'base_deck_spread_screen.dart';

class DeckSpreadSunSignScreen extends StatefulWidget {
  const DeckSpreadSunSignScreen({super.key});

  @override
  State<DeckSpreadSunSignScreen> createState() => _DeckSpreadSunSignScreenState();
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

class _DeckSpreadSunSignScreenState extends State<DeckSpreadSunSignScreen> {
  bool _proceedToDeck = false;
  DateTime? _selectedDate;
  String? _calculatedSunSign;
  String? _manualSunSign;

  // Overlay state (for deck flow)
  bool _showOverlay = false;
  List<String> _overlayLines = const [];
  String _currentDeckName = "Tarot";
  int _currentDeckNeed = 1;
  String _userSunSignForFlow = "Sun Sign";

  final List<String> _sunSigns = const [
    "Aries","Taurus","Gemini","Cancer","Leo","Virgo",
    "Libra","Scorpio","Sagittarius","Capricorn","Aquarius","Pisces",
  ];

  String get _userSunSign => (_manualSunSign ?? _calculatedSunSign ?? "Your Sign");

  // Deck-specific, sign-aware scripts
  List<String> _scriptForDeck(String deckName, int need) {
    final sign = _userSunSignForFlow;
    switch (deckName) {
      case "Tarot":
        return [
          "Breathe in… 4. Out… 6.",
          "For $sign: today’s core energy—what to lean into now.",
          "Now draw from Tarot. Choose $need card by first pull—trust the first spark.",
        ];
      case "Oracle":
        return [
          "Let the day simplify.",
          "For $sign: a gentle nudge or timing cue for one small action.",
          "Now pick from Oracle. Choose $need—let the kindest pointer stand out.",
        ];
      case "Affirmations":
        return [
          "Hand to heart; relax the shoulders.",
          "For $sign: one mantra to hold center as you move.",
          "Now pick an Affirmation. Choose $need—what feels strong and simple.",
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
    // If user has chosen a sign and wants to proceed → deck flow with overlays
    if (_proceedToDeck && (_calculatedSunSign != null || _manualSunSign != null)) {
      _userSunSignForFlow = _userSunSign;

      final topForChip = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

      return Stack(
        children: [
          // Base deck flow (no prep/micro-copy), sign-aware intro
          Positioned.fill(
            child: BaseDeckSpreadScreen(
              title: "🌞 Daily Sun Sign Reading",
              customIntroText: "Based on your Sun Sign: $_userSunSignForFlow",

              // ✅ Use your background PNG for Sun Sign
              backgroundAsset: 'assets/backgrounds/bg_sunsign.png',

              // Overlay flow
              showPrep: false,
              captureIntention: false,
              showDeckMicroCopy: false,

              deckTopGap: 16.0,
              gridPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

              // Overlay trigger per deck
              onDeckStart: _handleDeckStart,

              // Prompts unused in overlay flow
              prompts: const {},

              // One card per deck for daily read
              deckLimits: const {
                "Tarot": 1,
                "Oracle": 1,
                "Affirmations": 1,
              },
              deckCounts: const {
                "Tarot": 78,
                "Oracle": 52,
                "Affirmations": 40,
              },
              deckOrder: const ["Tarot", "Oracle", "Affirmations"],
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

    // ────────────────────────────────────────────────────────────────
    // Entry screen: pick DOB or choose sign
    // ────────────────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.deepPurple[800],
      appBar: AppBar(
        title: const Text("🌞 Enter Your Sun Sign"),
        backgroundColor: Colors.deepPurple[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "To personalize your reading, please enter your date of birth or directly choose your sun sign:",
              style: TextStyle(fontSize: 18, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000, 1, 1),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.purpleAccent,
                          onPrimary: Colors.white,
                          surface: Colors.deepPurple,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _calculatedSunSign = _getSunSign(picked);
                    _manualSunSign = null; // Clear manual if DOB selected
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.purpleAccent,
              ),
              child: Text(
                _selectedDate == null
                    ? "📅 Select Date of Birth"
                    : "📅 ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} — $_calculatedSunSign",
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_calculatedSunSign != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "Your Sun Sign is: $_calculatedSunSign",
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 30),
            const Text(
              "OR",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _manualSunSign,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelText: "Select your Sun Sign",
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              dropdownColor: Colors.deepPurple[700],
              items: _sunSigns.map((sign) {
                return DropdownMenuItem(
                  value: sign,
                  child: Text(sign, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _manualSunSign = value;
                  _calculatedSunSign = null; // Clear DOB if manual selected
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: (_calculatedSunSign != null || _manualSunSign != null)
                  ? () {
                      setState(() {
                        _userSunSignForFlow = _userSunSign; // capture for overlay scripts
                        _proceedToDeck = true;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text("✨ Continue to Reading ✨"),
            ),
          ],
        ),
      ),
    );
  }

  String _getSunSign(DateTime date) {
    final day = date.day;
    final month = date.month;

    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return "Aquarius";
    if ((month == 2 && day >= 19) || (month == 3 && day <= 20)) return "Pisces";
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return "Aries";
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return "Taurus";
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return "Gemini";
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return "Cancer";
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return "Leo";
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return "Virgo";
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return "Libra";
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return "Scorpio";
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return "Sagittarius";
    return "Capricorn";
  }
}
