import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'deck_spread/deck_spread_love.dart';
import 'deck_spread/deck_spread_career.dart';
import 'deck_spread/deck_spread_sunsign.dart';
import 'deck_spread/deck_spread_fullmoon.dart';
import 'deck_spread/deck_spread_personal.dart';
import 'deck_spread/deck_spread_angel.dart';
import 'widgets/global_sidebar_overlay_widget.dart';
import 'widgets/animations/parallax_background.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'widgets/daily_guidance_popup.dart';
import 'services/reading_balance_service.dart'; 
import 'payment/payment_popup_widget.dart';     


class HomeSelectionScreen extends StatefulWidget {
  const HomeSelectionScreen({super.key});

  @override
  State<HomeSelectionScreen> createState() => _HomeSelectionScreenState();
}

class _HomeSelectionScreenState extends State<HomeSelectionScreen> {
  final GlobalKey<GlobalSidebarOverlayWidgetState> _sidebarKey = GlobalKey();

  final List<Map<String, dynamic>> readingTypes = const [
    {"emoji": "🌹", "title": "Love Reading"},
    {"emoji": "💼", "title": "Career Reading"},
    {"emoji": "☀️", "title": "Daily Sun Sign"},
    {"emoji": "🌙", "title": "Full Moon / Retrograde"},
    {"emoji": "🔮", "title": "Personal Question"},
    {"emoji": "🕊️", "title": "Angel Guidance"},
  ];

  int readingsLeft = 0;
  bool isLoading = true;
  bool _checkingBalance = false;
  String? _loadingTitle;

  String _balanceLabel(int bal) => (bal >= 999999) ? "Unlimited" : "$bal";

  @override
  void initState() {
    super.initState();
    fetchReadingsLeft();
    _requestNotificationPermission();
  }

  Future<bool> _confirmUseCredit({
  required String readingTitle,
  required int balance,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Use 1 Reading Credit?"),
        content: Text(
          "You currently have ${_balanceLabel(balance)} reading(s) left.\n\n"
          "Do you want to use 1 credit for “$readingTitle”?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
        ],
      ),
    ).then((v) => v ?? false);
  }

  Future<void> _showPaymentPopup() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => PaymentPopupWidget(
        onClose: () => Navigator.pop(context),
        onPlanSelected: (planId) {
          Navigator.pop(context); // close popup
          // TODO: start your purchase flow / route
          Navigator.pushNamed(context, '/checkout', arguments: {'planId': planId});
        },
      ),
    );
  }

  void _navigateToReading(String title) {
    if (title == "Love Reading") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSpreadLoveScreen()));
    } else if (title == "Career Reading") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSpreadCareerScreen()));
    } else if (title == "Daily Sun Sign") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSpreadSunSignScreen()));
    } else if (title == "Full Moon / Retrograde") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSpreadFullMoonScreen()));
    } else if (title == "Personal Question") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSpreadPersonalScreen()));
    } else if (title == "Angel Guidance") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckSpreadAngelScreen()));
    } else if (title == "Daily Guidance") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyGuidancePopup()));
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print("🔔 Notifications allowed");
    } else {
      print("❌ Notifications denied");
    }
  }

  Future<void> fetchReadingsLeft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data != null) {
      final planType = data['planType'] ?? 'one_time';
      final int readingBalance = data['readingBalance'] ?? 0;
      final Timestamp? activatedAtTs = data['planActivatedAt'];
      final DateTime now = DateTime.now();
      final DateTime? activatedAt = activatedAtTs?.toDate();
      final bool isCurrentMonth = activatedAt != null &&
          activatedAt.year == now.year &&
          activatedAt.month == now.month;

      int calculatedBalance = readingBalance;

      if (planType == 'unlimited') {
        calculatedBalance = isCurrentMonth ? 9999 : 0;
      } else if (planType == 'thirty_monthly') {
        calculatedBalance = isCurrentMonth ? readingBalance : 0;
      }

      setState(() {
        readingsLeft = calculatedBalance;
        isLoading = false;
      });
    }
  }

  void _handleReadingTap(BuildContext context, String title) async {
  // Free readings bypass balance check
    const freeReadings = {"Daily Guidance"};
    final isPaid = !freeReadings.contains(title);

    if (!isPaid) {
      _navigateToReading(title);
      return;
    }

    // Prevent double taps while we're checking balance
    if (_checkingBalance) return;

    setState(() {
      _checkingBalance = true;
      _loadingTitle = title; // show spinner on the tapped tile
    });

    int balance = 0;
    try {
      // Always fetch fresh balance
      balance = await ReadingBalanceService().getReadingBalance();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn’t check balance. Please try again. ($e)")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingBalance = false; // stop global checking state
        });
      }
    }
    if (!mounted) return;

    if (balance <= 0) {
      setState(() => _loadingTitle = null); // clear tile loader
      await _showPaymentPopup();            // open your existing plan picker
      return;
    }

    // Confirm credit usage
    final ok = await _confirmUseCredit(readingTitle: title, balance: balance);
    setState(() => _loadingTitle = null); // clear tile loader

    if (ok) {
      _navigateToReading(title);
      // NOTE: do NOT deduct here. Deduct on the final reveal screen later.
      // await ReadingBalanceService().deductReading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlobalSidebarOverlayWidget(
        key: _sidebarKey,
        child: Stack(
          children: [
            ParallaxBackground(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Container(
                          color: Colors.deepPurple.shade700,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 16,
                            bottom: 16,
                            left: 16,
                            right: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _sidebarKey.currentState?.toggleSidebar();
                                },
                                child: const Icon(Icons.menu, size: 32, color: Colors.white),
                              ),
                              const Text(
                                'Choose Your Reading',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 32),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            child: ListView(
                              children: [
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 1.0, end: 1.05),
                                  duration: const Duration(seconds: 1),
                                  curve: Curves.easeInOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.heavyImpact();
                                      _handleReadingTap(context, "Daily Guidance");
                                    },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withOpacity(0.4),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      margin: const EdgeInsets.symmetric(vertical: 10),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // ✨ Shimmer background only
                                          Shimmer.fromColors(
                                            baseColor: Colors.purple.shade200.withOpacity(0.5),
                                            highlightColor: Colors.deepPurpleAccent.withOpacity(0.7),
                                            child: Container(
                                              height: 70,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.purpleAccent.shade100.withOpacity(0.8),
                                                    Colors.deepPurpleAccent.withOpacity(0.9),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),

                                          // 🌟 Foreground content not shimmered
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurple.shade700.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.auto_awesome, color: Colors.white),
                                                SizedBox(width: 12),
                                                Flexible(
                                                  child: Text(
                                                    "Click for your Daily Guidance (Free)",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                ...readingTypes.map((item) => InkWell(
                                  onTap: (_checkingBalance && _loadingTitle == item['title'])
                                    ? null
                                    : () {
                                        HapticFeedback.heavyImpact();
                                        _handleReadingTap(context, item['title']);
                                      },
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade700.withAlpha(204),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple.shade700.withAlpha(51),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // 👇 replace emoji with a tiny spinner when THIS tile is loading
                                          (_checkingBalance && _loadingTitle == item['title'])
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : Text(item['emoji'], style: const TextStyle(fontSize: 28)),

                                          const SizedBox(width: 12),

                                          // 👇 dim the title while this tile is loading
                                          Text(
                                            item['title'],
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                              color: (_checkingBalance && _loadingTitle == item['title'])
                                                  ? Colors.white70
                                                  : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
