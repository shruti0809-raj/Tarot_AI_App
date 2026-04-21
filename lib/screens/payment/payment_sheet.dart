// lib/screens/payment/payment_sheet.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==== Your product IDs (must match Play Console / App Store) ====
const Set<String> _kConsumables = {
  'one_reading',
  'pack5',
  'pack10_plus1',
};

const Set<String> _kSubscriptions = {
  'sub_daily_30',
  'sub_unlimited_30',
};

const List<String> _kDisplayOrder = [
  'one_reading',
  'pack5',
  'pack10_plus1',
  'sub_daily_30',
  'sub_unlimited_30',
];

class PaymentSheet extends StatefulWidget {
  final VoidCallback onClose;

  /// If provided, we won't purchase here. We'll call this with a legacy planId
  /// so you can navigate to your own Checkout screen/flow.
  final void Function(String selectedPlanId)? onPlanSelected;

  const PaymentSheet({
    super.key,
    required this.onClose,
    this.onPlanSelected,
  });

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _loading = true;
  bool _isPurchasing = false;
  String? _error;

  List<ProductDetails> _products = const [];
  String? _activePlanType; // null | 'unlimited' | 'thirty_monthly'

  void _d(String m) => debugPrint('[IAP] $m');

  @override
  void initState() {
    super.initState();
    // 1) Listen first so restores/past ownership get delivered to us.
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) => _showSnack('Purchase stream error: $e'),
    );
    // 2) Then initialize billing.
    _initBilling();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _initBilling() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _d('Checking billing availability...');
      final available = await _iap.isAvailable();
      if (!available) throw Exception('Billing is not available on this device.');

      await _refreshActivePlanType();

      final ids = <String>{..._kConsumables, ..._kSubscriptions};
      _d('Querying products: $ids');
      final resp = await _iap.queryProductDetails(ids);
      if (resp.error != null) throw Exception(resp.error!.message);

      final map = {for (final p in resp.productDetails) p.id: p};
      final ordered = _kDisplayOrder.map((id) => map[id]).whereNotNull().toList();

      setState(() {
        _products = ordered;
        _loading = false;
      });

      // Proactively restore (replaces old queryPastPurchases).
      // Restored items will be emitted on purchaseStream.
      await _iap.restorePurchases();
      _d('restorePurchases() invoked');
    } catch (e) {
      setState(() {
        _error = 'Could not load products: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshActivePlanType() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _activePlanType = null;
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    String? plan = data?['planType'] as String?;
    if (plan == 'unlimited' || plan == 'thirty_monthly') {
      final ts = data?['planActivatedAt'];
      DateTime? started;
      if (ts is Timestamp) started = ts.toDate();
      if (started != null && DateTime.now().difference(started).inDays >= 30) {
        plan = null; // treat expired as no plan
      }
    }
    _activePlanType = plan;
  }

  bool _isConsumable(String productId) => _kConsumables.contains(productId);

  String _legacyPlanIdFor(String productId) {
    switch (productId) {
      case 'one_reading':
        return 'pay1';
      case 'pack5':
        return 'pack5';
      case 'pack10_plus1':
        return 'pack10';
      case 'sub_daily_30':
        return 'daily';
      case 'sub_unlimited_30':
        return 'unlimited';
      default:
        return productId;
    }
  }

  Future<void> _tapProduct(ProductDetails pd) async {
    final isUnlimitedActive = _activePlanType == 'unlimited';
    if (isUnlimitedActive) {
      _showSnack("You're on Unlimited—no need to purchase more.");
      return;
    }

    // Legacy handoff to external checkout if provided.
    if (widget.onPlanSelected != null) {
      final legacyId = _legacyPlanIdFor(pd.id);
      widget.onPlanSelected!(legacyId);
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    // inside _tapProduct(ProductDetails pd)
    debugPrint('[IAP] tap ${pd.id}; usingLegacy=${widget.onPlanSelected != null}');

    // Otherwise, buy via IAP.
    await _buy(pd);
  }

  Future<void> _buy(ProductDetails pd) async {
    setState(() => _isPurchasing = true);
    try {
      final param = PurchaseParam(productDetails: pd);

      if (_isConsumable(pd.id)) {
        // Keep autoConsume true to avoid "already owned" stalls.
        await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
      } else {
        await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      _showSnack('Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> list) async {
    for (final d in list) {
      _d('update: ${d.productID} → ${d.status}');
      try {
        switch (d.status) {
          case PurchaseStatus.pending:
            // Optional: show a spinner or info; we already show the sheet UI.
            break;

          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            _showSnack(d.error?.message ?? 'Purchase cancelled or failed.');
            if (d.pendingCompletePurchase) {
              await _iap.completePurchase(d);
            }
            break;

          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            // Acknowledge (required on both platforms).
            if (d.pendingCompletePurchase) {
              await _iap.completePurchase(d);
            }

            // If this is a consumable that somehow still shows as owned on Android,
            // consuming again is a safe no-op if it's already consumed.
            if (Platform.isAndroid && _isConsumable(d.productID) && d is GooglePlayPurchaseDetails) {
              final add = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
              try {
                await add.consumePurchase(d);
              } catch (e) {
                // Swallow; it's fine if it was already consumed.
                _d('consumePurchase ignored: $e');
              }
            }

            // Grant entitlements
            await _grantEntitlement(d.productID);

            // Log purchase
            final pd = _products.firstWhereOrNull((p) => p.id == d.productID);
            await _safeLogPurchase(
              productId: d.productID,
              isSubscription: _kSubscriptions.contains(d.productID),
              priceText: pd?.price,
              title: pd?.title,
            );

            await _refreshActivePlanType();
            _showSnack('Purchase successful!');
            if (mounted) Navigator.of(context).maybePop();
            break;
        }
      } catch (e) {
        _showSnack('Could not finalize purchase: $e');
      }
    }
  }

  Future<void> _grantEntitlement(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    if (_kSubscriptions.contains(productId)) {
      if (productId == 'sub_unlimited_30') {
        await ref.set({
          'planType': 'unlimited',
          'readingBalance': 9999,
          'planActivatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (productId == 'sub_daily_30') {
        await ref.set({
          'planType': 'thirty_monthly',
          'readingBalance': 30,
          'planActivatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    int delta = 0;
    if (productId == 'one_reading') delta = 1;
    if (productId == 'pack5') delta = 5;
    if (productId == 'pack10_plus1') delta = 11;

    if (delta > 0) {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final curr = (snap.data()?['readingBalance'] ?? 0) as int;
        tx.set(ref, {
          'readingBalance': curr + delta,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    }
  }

  Future<void> _safeLogPurchase({
    required String productId,
    required bool isSubscription,
    String? priceText,
    String? title,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('purchases')
          .add({
        'productId': productId,
        'title': title ?? _titleFromProduct(productId),
        'priceText': priceText ?? '',
        'type': isSubscription ? 'subs' : 'inapp',
        'purchasedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ignore logging failures
    }
  }

  String _titleFromProduct(String id) {
    switch (id) {
      case 'one_reading':
        return '1 Reading';
      case 'pack5':
        return '5 Pack';
      case 'pack10_plus1':
        return '10 Pack + 1 Free';
      case 'sub_daily_30':
        return 'Daily (30 days)';
      case 'sub_unlimited_30':
        return 'Unlimited (30 days)';
      default:
        return id;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isUnlimitedActive = _activePlanType == 'unlimited';

    return Dialog(
      backgroundColor: Colors.deepPurple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Get More Readings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                        fontFamily: 'Cinzel',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: _isPurchasing ? null : widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a plan to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 10),

              if (isUnlimitedActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'You are on Unlimited—additional purchases are disabled.',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                    TextButton(onPressed: _initBilling, child: const Text('Retry')),
                  ],
                )
              else
                ..._products.map((pd) {
                  final blocked = isUnlimitedActive || _isPurchasing;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      enabled: !blocked,
                      title: Text(pd.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_subtitleFor(pd.id, pd.description)),
                      trailing: blocked
                          ? const Icon(Icons.lock, color: Colors.grey)
                          : Text(pd.price, style: const TextStyle(color: Colors.green)),
                      onTap: blocked ? null : () => _tapProduct(pd),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await _iap.restorePurchases(); // emits on purchaseStream
                },
                child: const Text('Restore purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleFor(String id, String fallback) {
    switch (id) {
      case 'one_reading':
        return 'Single reading';
      case 'pack5':
        return '5 readings';
      case 'pack10_plus1':
        return '10 + 1 free';
      case 'sub_daily_30':
        return '1 reading/day for 30 days';
      case 'sub_unlimited_30':
        return 'Unlimited for 30 days';
      default:
        return fallback;
    }
  }
}
