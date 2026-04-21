// lib/screens/user/billing_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BillingHistoryScreen extends StatelessWidget {
  const BillingHistoryScreen({super.key});

  // One-time (legacy) fetch
  Future<List<Map<String, dynamic>>> _fetchLegacyPlans() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    final plansSnap = await userRef
        .collection('plans')
        .orderBy('purchasedAt', descending: true)
        .get();

    return plansSnap.docs
        .map((d) => _normalize(d.data(), source: 'plans'))
        .toList();
  }

  // Live purchases stream
  Stream<List<Map<String, dynamic>>> _purchasesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    return userRef
        .collection('purchases')
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs
            .map((d) => _normalize(d.data(), source: 'purchases'))
            .toList());
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> raw, {required String source}) {
    final tsPurchased = raw['purchasedAt'];
    final tsExpires = raw['expiresAt'];
    final purchasedAt = tsPurchased is Timestamp ? tsPurchased.toDate() : null;
    final expiresAt   = tsExpires   is Timestamp ? tsExpires.toDate()   : null;

    final productId = (raw['productId'] ?? raw['id']) as String?;
    final title = (raw['title'] as String?) ?? _titleFromProduct(productId);

    String priceText = '-';
    if (raw['priceText'] is String && (raw['priceText'] as String).isNotEmpty) {
      priceText = raw['priceText'];
    } else if (raw['amount'] != null) {
      final amount = raw['amount'];
      final currency = (raw['currency'] as String?) ?? '';
      priceText = currency.isNotEmpty ? '$currency $amount' : amount.toString();
    }

    return {
      'title': title ?? (productId ?? 'Unknown product'),
      'priceText': priceText,
      'productId': productId,
      'type': raw['type'] ?? (raw['isSubscription'] == true ? 'subs' : 'inapp'),
      'purchasedAt': purchasedAt,
      'expiresAt': expiresAt,
      'source': source,
    };
  }

  static String? _titleFromProduct(String? id) {
    switch (id) {
      case 'one_reading':        return '1 Reading';
      case 'pack5':              return '5 Pack';
      case 'pack10_plus1':       return '10 Pack + 1 Free';
      case 'sub_daily_30':       return 'Daily (30 days)';
      case 'sub_unlimited_30':   return 'Unlimited (30 days)';
      default:                   return id;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _openManageSubscription() async {
    const packageName = 'com.taowalker.divineguidance';
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions?package=$packageName');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Billing History"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Manage / Cancel',
            icon: const Icon(Icons.manage_accounts),
            onPressed: _openManageSubscription,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view purchases.'))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchLegacyPlans(),
              builder: (context, legacySnap) {
                final legacy = legacySnap.data ?? [];

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _purchasesStream(),
                  builder: (context, purchaseSnap) {
                    if (legacySnap.connectionState == ConnectionState.waiting ||
                        purchaseSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final purchases = purchaseSnap.data ?? [];
                    final items = <Map<String, dynamic>>[...legacy, ...purchases];

                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          "No purchases found.",
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    items.sort((a, b) {
                      final at = a['purchasedAt'] as DateTime?;
                      final bt = b['purchasedAt'] as DateTime?;
                      if (at == null && bt == null) return 0;
                      if (at == null) return 1;
                      if (bt == null) return -1;
                      return bt.compareTo(at);
                    });

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final p = items[index];
                        final title      = p['title'] as String? ?? 'Unknown';
                        final purchased  = _formatDate(p['purchasedAt'] as DateTime?);
                        final expires    = _formatDate(p['expiresAt'] as DateTime?);
                        final priceText  = p['priceText'] as String? ?? '-';
                        final type       = (p['type'] as String?) ?? '-';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text(
                              type == 'subs'
                                  ? "Purchased on: $purchased\nExpires on: $expires"
                                  : "Purchased on: $purchased",
                            ),
                            trailing: Text(
                              priceText,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
