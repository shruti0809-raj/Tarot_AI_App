import 'package:flutter/material.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Refund Policy'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refund Policy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'We value your satisfaction and aim to provide the best experience through our app. However, we encourage you to carefully review our refund policy below before making any purchases.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '1. Non-refundable Purchases',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'All purchases made through the Atma Tarot app are non-refundable, including pay-per-reading packs and subscriptions. Once a reading is initiated or a pack is activated, it cannot be reversed or refunded.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '2. Technical Issues',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'In case of a technical glitch that prevents you from accessing your reading or if you are charged but don’t receive access to the service, please contact us at taowalker8@gmail.com within 24 hours. Include your registered phone number and transaction ID.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '3. Discretionary Refunds',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'We may consider a discretionary refund on a case-by-case basis only for technical failures. Refunds, if issued, will be processed back to the original payment method within 7–10 working days.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '4. Subscription Cancellation',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'You may cancel your subscription anytime, but no partial refunds will be provided for unused days. Your plan will remain active until the end of the current billing cycle.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '5. Contact Us',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'For all refund-related queries, contact us at taowalker8@gmail.com.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}