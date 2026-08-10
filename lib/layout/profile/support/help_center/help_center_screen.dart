// ─────────────────────────────────────────
// Screen: HelpCenterScreen
// Description: FAQ and self-service help articles.
// Contains: Expandable FAQ list, category sections
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../utils/theme/custom_themes/main_colors.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // Removed: faq_q3 (payments), faq_q4 (card fees), faq_q5 (refunds), faq_q9 (chef reliability), faq_q15 (card storage)
  final List<Map<String, dynamic>> faqItems = const [
    {'question': 'faq_q1', 'answer': 'faq_a1'},
    {'question': 'faq_q2', 'answer': 'faq_a2'},
    {'question': 'faq_q6', 'answer': 'faq_a6'},
    {'question': 'faq_q7', 'answer': 'faq_a7'},
    {'question': 'faq_q8', 'answer': 'faq_a8'},
    {'question': 'faq_q10', 'answer': 'faq_a10'},
    {'question': 'faq_q11', 'answer': 'faq_a11'},
    {'question': 'faq_q12', 'answer': 'faq_a12'},
    {'question': 'faq_q13', 'answer': 'faq_a13'},
    {'question': 'faq_q14', 'answer': 'faq_a14'},
    {'question': 'faq_q16', 'answer': 'faq_a16'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('help_center'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0.5,
      ),
      backgroundColor: backgroundColor,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqItems.length,
        itemBuilder: (context, index) {
          final item = faqItems[index];
          return _buildFAQCard(item['question']!, item['answer']!);
        },
      ),
    );
  }

  Widget _buildFAQCard(String questionKey, String answerKey) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 12),
        iconColor: mainColor,
        collapsedIconColor: Colors.grey,
        title: Text(
          questionKey.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        children: [
          Text(
            answerKey.tr(),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
