import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:divine_guidance_app/screens/payment/payment_popup_widget.dart';

class GlobalSidebarOverlayWidget extends StatefulWidget {
  final Widget child;

  const GlobalSidebarOverlayWidget({super.key, required this.child});

  @override
  State<GlobalSidebarOverlayWidget> createState() => GlobalSidebarOverlayWidgetState();
}

class GlobalSidebarOverlayWidgetState extends State<GlobalSidebarOverlayWidget> {
  bool _showSidebar = false;
  Map<String, dynamic>? userData;
  int readingsLeft = 0;
  File? _profileImage;

  Stream<User?>? _authStream;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSub;

  Map<String, dynamic>? _pendingSession;
  String? _pendingSessionId;

  @override
  void initState() {
    super.initState();

    _authStream = FirebaseAuth.instance.authStateChanges();
    _authSub = _authStream!.listen((user) async {
      await _userSub?.cancel();
      _userSub = null;
      await _pendingSub?.cancel();
      _pendingSub = null;
      _pendingSession = null;
      _pendingSessionId = null;

      if (user == null) {
        setState(() {
          userData = null;
          readingsLeft = 0;
          _profileImage = null;
          _pendingSession = null;
          _pendingSessionId = null;
        });
        return;
      }

      await _loadLocalImage(user.uid);

      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        final data = doc.data();
        if (data != null) {
          final left = _calculateReadingsLeft(data);
          setState(() {
            userData = data;
            readingsLeft = left;
          });
        }
      });

      _pendingSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readingSessions')
          .where('status', isEqualTo: 'revealed')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .listen((qs) {
        if (qs.docs.isNotEmpty) {
          final d = qs.docs.first;
          setState(() {
            _pendingSessionId = d.id;
            _pendingSession = d.data();
          });
        } else {
          setState(() {
            _pendingSessionId = null;
            _pendingSession = null;
          });
        }
      });
    });
  }

  Future<void> _loadLocalImage(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path_$uid');
    final updated = prefs.getBool('profile_image_updated_$uid') ?? false;

    if (path != null && File(path).existsSync()) {
      setState(() {
        _profileImage = File(path);
      });
    } else {
      setState(() {
        _profileImage = null;
      });
    }

    if (updated) {
      await prefs.setBool('profile_image_updated_$uid', false);
    }
  }

  int _calculateReadingsLeft(Map<String, dynamic> data) {
    final String planType = data['planType'] ?? 'one_time';
    final int readingBalance = data['readingBalance'] ?? 0;
    final Timestamp? activatedAtTs = data['planActivatedAt'];
    final DateTime now = DateTime.now();

    final DateTime? activatedAt = activatedAtTs?.toDate();
    final bool isCurrentMonth = activatedAt != null &&
        activatedAt.year == now.year &&
        activatedAt.month == now.month;

    if (planType == 'unlimited') {
      return isCurrentMonth ? 9999 : 0;
    }

    if (planType == 'thirty_monthly') {
      return isCurrentMonth ? readingBalance : 0;
    }

    return readingBalance;
  }

  void toggleSidebar() {
    setState(() => _showSidebar = !_showSidebar);
  }

  void navigateTo(String route, {Object? arguments}) {
    setState(() => _showSidebar = false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Navigator.pushNamed(context, route, arguments: arguments);

      if (route == '/profile') {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _loadLocalImage(user.uid);
        }
      }
    });
  }

  Future<void> _resumePendingReading() async {
    if (_pendingSessionId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readingSessions')
          .doc(_pendingSessionId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unfinished reading found.')),
        );
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] != 'revealed') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unfinished reading to resume.')),
        );
        return;
      }

      final rawCards = data['selectedCardsByDeck'];
      Map<String, List<String>> cards = {};
      if (rawCards is Map) {
        cards = rawCards.map((k, v) {
          final list = (v as List).map((e) => e.toString()).toList();
          final sanitized = list.map((s) => s.split('/').last).toList();
          return MapEntry(k.toString(), sanitized);
        });
      }

      final title = (data['title'] as String?) ?? 'Your Reading';

      setState(() => _showSidebar = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamed(
          context,
          '/final-reading',
          arguments: {
            'sessionId': _pendingSessionId,
            'cards': cards,
            'title': title,
          },
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resume reading: $e')),
      );
    }
  }

  Future<void> _openManageSubscription({String? sku}) async {
    const packageName = 'com.taowalker.divineguidance';
    final url = sku == null
        ? 'https://play.google.com/store/account/subscriptions?package=$packageName'
        : 'https://play.google.com/store/account/subscriptions?package=$packageName&sku=$sku';
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Play subscriptions.')),
      );
    }
  }

  void _openUpgradePlans() {
    setState(() => _showSidebar = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => PaymentPopupWidget(
          onClose: () => Navigator.pop(ctx),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSignedIn = FirebaseAuth.instance.currentUser != null;

    return Stack(
      children: [
        widget.child,
        if (_showSidebar) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: toggleSidebar,
              child: Container(color: Colors.black54),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              color: Colors.white,
              child: Drawer(
                elevation: 0,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(color: Colors.deepPurple),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            key: ValueKey(_profileImage?.path),
                            radius: 32,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (isSignedIn ? (userData?['name'] ?? 'User') : 'Guest'),
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (isSignedIn)
                            Text(
                              readingsLeft >= 9999
                                  ? 'Unlimited readings this month'
                                  : '$readingsLeft readings left',
                              style: const TextStyle(fontSize: 13, color: Colors.white70),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            const Text(
                              'Sign in to save and sync readings',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          // NOTE: intentionally removed the "Last Readings" list here to prevent overflow
                        ],
                      ),
                    ),

                    // ─── Guest: route to onboarding ───
                    if (!isSignedIn) ...[
                      ListTile(
                        leading: const Icon(Icons.login),
                        title: const Text('Sign in / Create account'),
                        onTap: () {
                          setState(() => _showSidebar = false);
                          Navigator.pushNamed(context, '/onboarding');
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Help & Support'),
                        onTap: () => navigateTo('/help'),
                      ),
                      ExpansionTile(
                        leading: const Icon(Icons.policy),
                        title: const Text('Legal'),
                        children: [
                          ListTile(
                            title: const Text('Privacy Policy'),
                            onTap: () => navigateTo('/privacy'),
                          ),
                          ListTile(
                            title: const Text('Terms & Conditions'),
                            onTap: () => navigateTo('/terms'),
                          ),
                          ListTile(
                            title: const Text('Data Deletion'),
                            onTap: () => navigateTo('/data-deletion'),
                          ),
                          ListTile(
                            title: const Text('Refund Policy'),
                            onTap: () => navigateTo('/refund-policy'),
                          ),
                        ],
                      ),
                    ],

                    // ─── Signed-in: full menu ───
                    if (isSignedIn) ...[
                      if (_pendingSession != null)
                        ListTile(
                          leading: const Icon(Icons.play_circle_fill, color: Colors.green),
                          title: const Text('Resume last reading'),
                          subtitle: (() {
                            final createdAt = _pendingSession!['createdAt'];
                            DateTime? dt;
                            if (createdAt is Timestamp) dt = createdAt.toDate();
                            return dt != null
                                ? Text(DateFormat('dd MMM yyyy – hh:mm a').format(dt))
                                : null;
                          })(),
                          onTap: _resumePendingReading,
                        ),

                      ListTile(
                        leading: const Icon(Icons.bookmark),
                        title: const Text('Saved Readings'),
                        onTap: () => navigateTo('/saved'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.payment),
                        title: const Text('Billing History'),
                        onTap: () => navigateTo('/billing'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Profile'),
                        onTap: () => navigateTo('/profile'),
                      ),

                      ListTile(
                        leading: const Icon(Icons.upgrade),
                        title: const Text('Upgrade / Buy Plan'),
                        subtitle: const Text('Subscriptions & packs'),
                        onTap: _openUpgradePlans,
                      ),

                      ListTile(
                        leading: const Icon(Icons.manage_accounts),
                        title: const Text('Manage / Cancel Subscription'),
                        subtitle: const Text('Opens Google Play'),
                        onTap: () => _openManageSubscription(),
                      ),

                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Report Offensive Content'),
                        onTap: () {
                          setState(() => _showSidebar = false);
                          Navigator.pushNamed(
                            context,
                            '/report',
                            arguments: {'sessionId': _pendingSessionId},
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Help & Support'),
                        onTap: () => navigateTo('/help'),
                      ),
                      ExpansionTile(
                        leading: const Icon(Icons.policy),
                        title: const Text('Legal'),
                        children: [
                          ListTile(
                            title: const Text('Privacy Policy'),
                            onTap: () => navigateTo('/privacy'),
                          ),
                          ListTile(
                            title: const Text('Terms & Conditions'),
                            onTap: () => navigateTo('/terms'),
                          ),
                          ListTile(
                            title: const Text('Data Deletion'),
                            onTap: () => navigateTo('/data-deletion'),
                          ),
                          ListTile(
                            title: const Text('Refund Policy'),
                            onTap: () => navigateTo('/refund-policy'),
                          ),
                        ],
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Logout'),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _authSub?.cancel();
    _pendingSub?.cancel();
    super.dispose();
  }
}
