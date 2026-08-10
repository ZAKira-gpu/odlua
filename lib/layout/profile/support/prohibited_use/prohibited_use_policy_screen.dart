// ─────────────────────────────────────────
// Screen: ProhibitedUsePolicyScreen
// Description: Displays the app’s prohibited-use policy (static text).
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class ProhibitedUsePolicyScreen extends StatelessWidget {
  const ProhibitedUsePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'prohibited_use_policy'.tr(),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _paragraph('prohibited_intro'.tr()),

            // 1. Prohibited Food Items
            _sectionTitle('1. ${'prohibited_section1_title'.tr()}'),
            _paragraph('prohibited_section1_content'.tr()),
            _bulletList([
              'prohibited_section1_bullet1'.tr(),
              'prohibited_section1_bullet2'.tr(),
              'prohibited_section1_bullet3'.tr(),
              'prohibited_section1_bullet4'.tr(),
              'prohibited_section1_bullet5'.tr(),
              'prohibited_section1_bullet6'.tr(),
            ]),

            // 2. Prohibited Conduct
            _sectionTitle('2. ${'prohibited_section2_title'.tr()}'),
            _paragraph('prohibited_section2_content'.tr()),
            _bulletList([
              'prohibited_section2_bullet1'.tr(),
              'prohibited_section2_bullet2'.tr(),
              'prohibited_section2_bullet3'.tr(),
              'prohibited_section2_bullet4'.tr(),
              'prohibited_section2_bullet5'.tr(),
              'prohibited_section2_bullet6'.tr(),
            ]),

            // 3. Content Restrictions
            _sectionTitle('3. ${'prohibited_section3_title'.tr()}'),
            _paragraph('prohibited_section3_content'.tr()),
            _bulletList([
              'prohibited_section3_bullet1'.tr(),
              'prohibited_section3_bullet2'.tr(),
              'prohibited_section3_bullet3'.tr(),
              'prohibited_section3_bullet4'.tr(),
            ]),

            // 4. Account Misuse
            _sectionTitle('4. ${'prohibited_section4_title'.tr()}'),
            _paragraph('prohibited_section4_content'.tr()),
            _bulletList([
              'prohibited_section4_bullet1'.tr(),
              'prohibited_section4_bullet2'.tr(),
              'prohibited_section4_bullet3'.tr(),
              'prohibited_section4_bullet4'.tr(),
            ]),

            // 5. Transaction Violations
            _sectionTitle('5. ${'prohibited_section5_title'.tr()}'),
            _paragraph('prohibited_section5_content'.tr()),
            _bulletList([
              'prohibited_section5_bullet1'.tr(),
              'prohibited_section5_bullet2'.tr(),
              'prohibited_section5_bullet3'.tr(),
            ]),

            // 6. Enforcement Actions
            _sectionTitle('6. ${'prohibited_section6_title'.tr()}'),
            _paragraph('prohibited_section6_content'.tr()),
            _bulletList([
              'prohibited_section6_bullet1'.tr(),
              'prohibited_section6_bullet2'.tr(),
              'prohibited_section6_bullet3'.tr(),
              'prohibited_section6_bullet4'.tr(),
            ]),

            // 7. Reporting Violations
            _sectionTitle('7. ${'prohibited_section7_title'.tr()}'),
            _paragraph('prohibited_section7_content'.tr()),

            // Contact Information
            _sectionTitle('prohibited_contact_title'.tr()),
            _paragraph('prohibited_contact_content'.tr()),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: mainColor,
          ),
        ),
      );

  Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      );

  Widget _bulletList(List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ',
                          style: TextStyle(fontSize: 14, color: mainColor)),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      );
}
