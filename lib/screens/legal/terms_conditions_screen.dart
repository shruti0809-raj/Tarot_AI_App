import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms & Conditions"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''
Terms & Conditions – Atma Tarot App
Effective Date: July 2025

Welcome to Atma Tarot, an AI-powered tarot reading app designed to offer spiritual insights and personal guidance. By using this app, you agree to be bound by the following terms:

1. User Eligibility
- You must be at least 13 years old to use this app.
- By registering, you confirm that the information provided is true and accurate.

2. Nature of Service
- The app provides AI-generated tarot readings based on your card selections.
- Readings are for **entertainment and self-reflection purposes** and should not be used as a substitute for professional advice (e.g., medical, legal, financial).

3. Usage Guidelines
- You agree not to misuse, copy, resell, or tamper with any part of the app.
- You will not attempt to reverse-engineer, extract source code, or interfere with app functionality.
- Any abusive behavior toward the app or its team may result in permanent account suspension.

4. Intellectual Property
- All content, designs, illustrations, and interpretations in the app are intellectual property of Atma Tarot or its licensors.
- You may not reproduce or redistribute any part of the app without prior written permission.

5. Payment Terms
- We offer a free tier and paid plans through in-app purchases.
- All purchases are processed securely via Razorpay or your app store billing system.
- Prices are subject to change with prior notice.

6. Refund Policy
- Refunds are only granted in accordance with our refund policy (see Refund Policy screen).
- Misuse or excessive requests may lead to refund denial.

7. Account Termination
- You may delete your account anytime by contacting support.
- We reserve the right to terminate accounts for policy violations or fraudulent activity.

8. Limitation of Liability
- Atma Tarot shall not be held liable for any decisions or actions taken by users based on tarot readings.
- We do not guarantee outcomes or accuracy of AI-generated content.

9. Data Privacy
- Your personal data is protected under our Privacy Policy.
- We do not share your data with third parties.

10. Changes to Terms
- We may update these terms from time to time.
- Continued use of the app after changes constitutes your acceptance of the updated terms.

11. Contact Us
For questions or concerns regarding these terms, please contact:
Tao Walker
Email: taowalker8@gmail.com

Thank you for using Atma Tarot.
– Your AI Tarot With Heart –
            ''',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
      ),
    );
  }
}