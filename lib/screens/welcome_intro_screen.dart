import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:divine_guidance_app/screens/widgets/animations/twinkling_star.dart';
import 'package:divine_guidance_app/screens/login_screen.dart';

// Brand palette (Deep Purple)
const Color kBrandDeepPurple      = Color(0xFF673AB7);
const Color kBrandDeepPurpleDark  = Color(0xFF512DA8);
const Color kBrandDeepPurpleLight = Color(0xFFB39DDB);

class WelcomeIntroScreen extends StatefulWidget {
  const WelcomeIntroScreen({super.key});

  @override
  State<WelcomeIntroScreen> createState() => _WelcomeIntroScreenState();
}

class _WelcomeIntroScreenState extends State<WelcomeIntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;   // background drift
  late final AnimationController _hintController;   // chevrons bounce
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pageController = PageController(initialPage: 0);

    // If already signed in, skip intro/login and go straight home
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return;
      }
      // Show the 3-free-readings popup to NEW users (once)
      await _maybeShowFree3Dialog();
    });
  }

  Future<void> _maybeShowFree3Dialog() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'welcome_free3_dialog_shown_v1';
    final shown = prefs.getBool(key) ?? false;
    if (shown) return;

    if (!mounted) return;
    await _showFree3Dialog();

    // Mark as shown so we don't nag again
    await prefs.setBool(key, true);
  }

  Future<void> _showFree3Dialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // tap outside to dismiss
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).maybePop(), // tapping anywhere closes
          child: Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: GestureDetector(
                onTap: () {}, // swallow taps so only outside dismisses
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          const Text(
                            '🎁 Welcome!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              'New users get 3 free readings to begin their journey.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrandDeepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            ),
                            onPressed: () => Navigator.of(ctx).maybePop(),
                            child: const Text('OK'),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    _hintController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        children: [
          _buildIntroScreen(context),
          const LoginScreen(),
        ],
      ),
    );
  }

  Widget _buildIntroScreen(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/design/welcome_screen1.jpg', fit: BoxFit.cover),
        Container(color: Colors.black.withAlpha((0.4 * 255).toInt())),
        AnimatedBuilder(
          animation: _iconController,
          builder: (context, child) {
            final screenWidth = MediaQuery.of(context).size.width;
            final iconOffset = _iconController.value * screenWidth * 1.2;
            return Stack(
              children: [
                const TwinklingStarField(),
                ..._buildCelestialIcons(-iconOffset),
              ],
            );
          },
        ),

        // HERO — shifted up so the glass tagline clears the figure
        Align(
          alignment: const Alignment(0, -0.38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientText(
                  'ATMA TAROT',
                  gradient: const LinearGradient(
                    colors: [
                      kBrandDeepPurpleLight,
                      kBrandDeepPurple,
                      kBrandDeepPurpleDark
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Color(0x40FFFFFF),
                        blurRadius: 10,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'by AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 18),
                const _GlassTagline(
                  text: 'Enter the mystical realm where your soul meets its message',
                ),
                const SizedBox(height: 14),
                const Text(
                  '✦  ✦  ✦',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
          ),
        ),

        // SIMPLE "Swipe to begin →" hint (no slider)
        Align(
          alignment: const Alignment(0, 0.86),
          child: _SwipeHint(
            controller: _hintController,
            label: 'Swipe left to begin',
          ),
        ),

        // FOOTER
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Powered by Tao Walker',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCelestialIcons(double offsetX) {
    final List<Map<String, dynamic>> iconData = [
      {'path': 'assets/icons/star_small.png', 'top': 100.0, 'left': 30.0, 'size': 12.0},
      {'path': 'assets/icons/star_medium.png', 'top': 250.0, 'right': 40.0, 'size': 16.0},
      {'path': 'assets/icons/star_large.png', 'bottom': 180.0, 'left': 80.0, 'size': 20.0},
      {'path': 'assets/icons/moonstar.png', 'bottom': 60.0, 'right': 60.0, 'size': 18.0},
      {'path': 'assets/icons/constellation.png', 'top': 120.0, 'right': 100.0, 'size': 24.0},
      {'path': 'assets/icons/eye.png', 'bottom': 100.0, 'right': 120.0, 'size': 18.0},
      {'path': 'assets/icons/evileye.png', 'top': 80.0, 'left': 160.0, 'size': 18.0},
      {'path': 'assets/icons/feather.png', 'bottom': 150.0, 'left': 40.0, 'size': 22.0},
      {'path': 'assets/icons/planet.png', 'top': 200.0, 'left': 200.0, 'size': 24.0},
      {'path': 'assets/icons/moon.png', 'bottom': 50.0, 'right': 20.0, 'size': 26.0},
    ];

    return iconData.map((icon) {
      return Positioned(
        top: icon['top'] as double?,
        bottom: icon['bottom'] as double?,
        left: icon.containsKey('left') ? (icon['left'] as double?)! + offsetX : null,
        right: icon.containsKey('right') ? (icon['right'] as double?)! - offsetX : null,
        child: _animatedIcon(icon['path'] as String, icon['size'] as double),
      );
    }).toList();
  }

  Widget _animatedIcon(String path, double size) {
    final duration = Duration(seconds: 5 + Random().nextInt(6));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.15),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.85 + Random().nextDouble() * 0.15,
          child: Transform.rotate(
            angle: value / 6,
            child: Transform.scale(
              scale: value,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        path,
        width: size,
        height: size,
        color: Colors.white.withAlpha((0.8 * 255).toInt()),
      ),
    );
  }
}

// ───────────── Helpers ─────────────

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}

class _GlassTagline extends StatelessWidget {
  final String text;
  const _GlassTagline({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16.5,
              height: 1.4,
              color: Colors.white,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

// Simple animated "Swipe left to begin >>>"
class _SwipeHint extends StatelessWidget {
  final AnimationController controller;
  final String label;
  const _SwipeHint({super.key, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // 0..1..0 loop → 0..10 px wiggle
        final dx = -(controller.value - 0.5) * 20; // -10..+10
        final o1 = 0.4 + 0.6 * controller.value;
        final o2 = 0.3 + 0.5 * (1 - controller.value);
        final o3 = 0.2 + 0.4 * controller.value;

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Transform.translate(
                    offset: Offset(dx, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, color: Colors.white.withOpacity(o1), size: 22),
                        Icon(Icons.chevron_left, color: Colors.white.withOpacity(o2), size: 20),
                        Icon(Icons.chevron_left, color: Colors.white.withOpacity(o3), size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
