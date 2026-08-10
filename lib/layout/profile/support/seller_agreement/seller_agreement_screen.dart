// ─────────────────────────────────────────
// Screen: SellerAgreementScreen
// Description: Displays the seller/chef agreement terms (static text).
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class SellerAgreementScreen extends StatelessWidget {
  const SellerAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'seller_agreement'.tr(),
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
            // Last Updated
            _lastUpdated('seller_agreement_last_updated'.tr()),
            const SizedBox(height: 16),

            // Introduction
            _paragraph('seller_agreement_intro'.tr()),

            // 1. Seller Eligibility
            _sectionTitle('1. ${'seller_section1_title'.tr()}'),
            _paragraph('seller_section1_content'.tr()),
            _bulletList([
              'seller_section1_bullet1'.tr(),
              'seller_section1_bullet2'.tr(),
              'seller_section1_bullet3'.tr(),
              'seller_section1_bullet4'.tr(),
            ]),

            // 2. Food Safety Requirements
            _sectionTitle('2. ${'seller_section2_title'.tr()}'),
            _paragraph('seller_section2_content'.tr()),
            _bulletList([
              'seller_section2_bullet1'.tr(),
              'seller_section2_bullet2'.tr(),
              'seller_section2_bullet3'.tr(),
              'seller_section2_bullet4'.tr(),
              'seller_section2_bullet5'.tr(),
            ]),

            // 3. Listing Requirements
            _sectionTitle('3. ${'seller_section3_title'.tr()}'),
            _paragraph('seller_section3_content'.tr()),
            _bulletList([
              'seller_section3_bullet1'.tr(),
              'seller_section3_bullet2'.tr(),
              'seller_section3_bullet3'.tr(),
              'seller_section3_bullet4'.tr(),
            ]),

            // 4. Pricing and Payments
            _sectionTitle('4. ${'seller_section4_title'.tr()}'),
            _paragraph('seller_section4_content'.tr()),
            _bulletList([
              'seller_section4_bullet1'.tr(),
              'seller_section4_bullet2'.tr(),
              'seller_section4_bullet3'.tr(),
            ]),

            // 5. Order Fulfillment
            _sectionTitle('5. ${'seller_section5_title'.tr()}'),
            _paragraph('seller_section5_content'.tr()),
            _bulletList([
              'seller_section5_bullet1'.tr(),
              'seller_section5_bullet2'.tr(),
              'seller_section5_bullet3'.tr(),
              'seller_section5_bullet4'.tr(),
            ]),

            // 6. Communication with Buyers
            _sectionTitle('6. ${'seller_section6_title'.tr()}'),
            _paragraph('seller_section6_content'.tr()),

            // 7. Reviews and Ratings
            _sectionTitle('7. ${'seller_section7_title'.tr()}'),
            _paragraph('seller_section7_content'.tr()),

            // 8. Account Suspension
            _sectionTitle('8. ${'seller_section8_title'.tr()}'),
            _paragraph('seller_section8_content'.tr()),
            _bulletList([
              'seller_section8_bullet1'.tr(),
              'seller_section8_bullet2'.tr(),
              'seller_section8_bullet3'.tr(),
              'seller_section8_bullet4'.tr(),
            ]),

            // 9. Liability and Insurance
            _sectionTitle('9. ${'seller_section9_title'.tr()}'),
            _paragraph('seller_section9_content'.tr()),

            // 10. Agreement Updates
            _sectionTitle('10. ${'seller_section10_title'.tr()}'),
            _paragraph('seller_section10_content'.tr()),

            // Contact Information
            _sectionTitle('seller_contact_title'.tr()),
            _paragraph('seller_contact_content'.tr()),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _lastUpdated(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade600,
        ),
      );

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
