import 'package:flutter/material.dart';

class DataDeletionPolicyScreen extends StatelessWidget {
  const DataDeletionPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Deletion Policy'),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.black,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Data Deletion Policy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'At Atma Tarot, we value your privacy and your right to manage your data. This Data Deletion Policy explains how you can request deletion of your data and what information will be removed.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 24),
          Text(
            '1. What Can Be Deleted:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            '- Your name and date of birth stored in our records'
            '- Your reading history and saved readings'
            '- Any data linked to your account including billing and preferences',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 24),
          Text(
            '2. How to Request Data Deletion:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'To request deletion of your data, please email us at:'
            '📧 taowalker8@gmail.com'
            'Use the subject line "Data Deletion Request" and mention your registered phone number.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 24),
          Text(
            '3. What Happens Next:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            '- Your request will be verified via email confirmation.'
            '- Data will be deleted within 7 business days from confirmation.'
            '- Once deleted, your data cannot be recovered.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 24),
          Text(
            '4. Exceptions:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'We may retain certain data if:'
            '- Required by law'
            '- For fraud prevention or security concerns'
            '- For resolving disputes or enforcing our policies',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 24),
          Text(
            '5. Need Help?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'If you have any questions about our Data Deletion Policy or how your data is used, feel free to reach out at the email above.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
