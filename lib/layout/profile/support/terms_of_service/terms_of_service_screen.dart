// ─────────────────────────────────────────
// Screen: TermsOfServiceScreen
// Description: Displays the app’s terms of service (static text).
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'tos_title'.tr(),
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
            // Title
            Text(
              'tos_header'.tr(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: mainColor,
              ),
            ),
            const SizedBox(height: 20),

            // 1. Nature of the Platform
            _sectionTitle('1. ${'tos_nature_title'.tr()}'),
            _bulletList([
              'tos_nature_bullet1'.tr(),
              'tos_nature_bullet2'.tr(),
            ]),

            // 2. Eligibility
            _sectionTitle('2. ${'tos_eligibility_title'.tr()}'),
            _bulletList([
              'tos_eligibility_bullet1'.tr(),
              'tos_eligibility_bullet2'.tr(),
            ]),

            // 3. What Is Allowed
            _sectionTitle('3. ${'tos_allowed_title'.tr()}'),
            _bulletList([
              'tos_allowed_bullet1'.tr(),
              'tos_allowed_bullet2'.tr(),
            ]),

            // 4. What Is Prohibited
            _sectionTitle('4. ${'tos_prohibited_title'.tr()}'),
            _bulletList([
              'tos_prohibited_bullet1'.tr(),
              'tos_prohibited_bullet2'.tr(),
              'tos_prohibited_bullet3'.tr(),
              'tos_prohibited_bullet4'.tr(),
            ]),
            _warningText('tos_prohibited_warning'.tr()),

            // 5. Responsibility for Food
            _sectionTitle('5. ${'tos_responsibility_title'.tr()}'),
            _paragraph('tos_responsibility_intro'.tr()),
            _bulletList([
              'tos_responsibility_bullet1'.tr(),
            ]),
            _paragraph('tos_responsibility_note'.tr()),

            // 6. Allergens and Ingredients
            _sectionTitle('6. ${'tos_allergens_title'.tr()}'),
            _bulletList([
              'tos_allergens_bullet1'.tr(),
              'tos_allergens_bullet2'.tr(),
            ]),

            // 7. Communication and Handover
            _sectionTitle('7. ${'tos_communication_title'.tr()}'),
            _bulletList([
              'tos_communication_bullet1'.tr(),
              'tos_communication_bullet2'.tr(),
            ]),

            // 8. Community Conduct
            _sectionTitle('8. ${'tos_conduct_title'.tr()}'),
            _paragraph('tos_conduct_content'.tr()),

            // 9. Changes and Enforcement
            _sectionTitle('9. ${'tos_changes_title'.tr()}'),
            _paragraph('tos_changes_content'.tr()),

            const SizedBox(height: 30),
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

  Widget _warningText(String text) => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bulletList(List<String> items) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 14,
                            color: mainColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );
}
