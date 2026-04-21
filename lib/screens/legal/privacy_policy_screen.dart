import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''
Privacy Policy – Atma Tarot by AI App  
Effective Date: August 2025 (Updated for in-app account deletion support)

Thank you for using Atma Tarot – an AI-powered tarot reading application. Your privacy is important to us. This policy explains how we collect, use, store, and protect your personal information.

---

1. Information We Collect

- Phone Number: Used for secure login via OTP (managed through Firebase Authentication).
- Email and Password: Optional login method, stored securely using Firebase Authentication.
- Name and Date of Birth: Used to personalize tarot readings, securely stored in Firebase Firestore.
- Reading Data: Your selected cards and AI-generated interpretations may be stored in your account for future access.
- Saved Files: If you download reading PDFs, they are saved only on your device (not on our servers).
- Purchase History: Metadata like plan type, amount, and timestamp is stored for billing and support.
- Device Information (Non-personal): Includes app version, OS, and crash reports for diagnostics.

---

2. How We Use Your Information

- To authenticate your login and secure your account
- To personalize tarot readings based on your data
- To allow access to past readings
- To manage subscriptions and payment history
- To improve performance and meet app store policy standards

---

3. Data Storage and Security

- All cloud-stored data is hosted on Firebase Firestore, which follows global data security standards.
- Your reading PDFs are only stored on your local device.
- OTPs are never stored by us.
- Data is accessible only via authenticated, secure sessions.

---

4. Data Sharing

- We do not sell or share your data with advertisers, analytics platforms, or third parties.
- Your reading data is never used to train AI models.

---

5. Your Rights

You have full control over your data and can:

- Delete your account entirely from within the app using the “Delete My Account” option in the Profile screen.
- Alternatively, request deletion via:
  - 📝 Full Account Deletion Form → [https://forms.gle/xr1EE6CpGYizn6x19](https://forms.gle/xr1EE6CpGYizn6x19)
  - 📝 Specific Data Deletion Form → [https://forms.gle/DPyyfqFmYrXRfQgL8](https://forms.gle/DPyyfqFmYrXRfQgL8)

You may also:
- Delete saved readings manually from within the app
- Uninstall the app to remove all locally stored data
- Contact us directly at taowalker8@gmail.com

---

6. Data Retention

- We retain your profile and reading data as long as your account remains active.
- Inactive accounts may be archived or deleted after 12 months of inactivity.
- Payment and billing records may be retained for legal, tax, and audit purposes.

---

7. Children’s Privacy

This app is intended for users aged 13 and above.  
Accounts identified as created by users under 13 will be permanently deleted.

---

8. Changes to This Policy

We may update this Privacy Policy from time to time.  
Significant changes will be communicated within the app before they take effect.

---

9. Contact Us

Tao Walker
📧 Email: taowalker8@gmail.com

---

By using this app, you agree to the terms of this privacy policy and our terms of service.

—
Divine Guidance – AI Tarot With Heart
            ''',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
      ),
    );
  }
}
