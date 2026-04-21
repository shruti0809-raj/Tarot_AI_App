// report_content_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportContentScreen extends StatefulWidget {
  const ReportContentScreen({super.key});

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'Offensive / Abusive';
  final _detailsCtrl = TextEditingController();
  bool _includeLastReading = true;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a report.')),
      );
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final sessionId = _includeLastReading ? (args?['sessionId'] as String?) : null;

    final payload = {
      'category': _category,
      'details': _detailsCtrl.text.trim(),
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'android',
      'status': 'open',
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reports')
          .add(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your report was submitted.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Content'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Tell us what went wrong. This helps us review and take action.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Offensive / Abusive', child: Text('Offensive / Abusive')),
                  DropdownMenuItem(value: 'Hate / Harassment', child: Text('Hate / Harassment')),
                  DropdownMenuItem(value: 'Sexual Content', child: Text('Sexual Content')),
                  DropdownMenuItem(value: 'Self-harm / Safety', child: Text('Self-harm / Safety')),
                  DropdownMenuItem(value: 'Spam / Scam', child: Text('Spam / Scam')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please add details' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _includeLastReading,
                onChanged: (v) => setState(() => _includeLastReading = v),
                title: const Text('Include last reading context (if available)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
