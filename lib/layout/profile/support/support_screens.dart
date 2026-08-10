// ─────────────────────────────────────────
// Screen: SupportScreens
// Description: Container / router for legal and support pages —
//              Help Center, Contact, Privacy, Terms, Seller Agreement.
// Contains: Navigation tiles to individual policy/support screens
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../utils/theme/custom_themes/main_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoScreen(
      title: 'Terms & Conditions',
      content:
          'These are the Terms and Conditions of your app. Outline usage rights, responsibilities, limitations, and service disclaimers here.',
    );
  }
}

class _SimpleInfoScreen extends StatelessWidget {
  final String title;
  final String content;

  const _SimpleInfoScreen({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(fontSize: 15.5, height: 1.7),
          ),
        ),
      ),
    );
  }
}
