import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';


class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_policy'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0.5,
      ),
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('pp_section1'.tr()),
            _bulletList([
              'pp_bullet1_1'.tr(),
              'pp_bullet1_2'.tr(),
              'pp_bullet1_3'.tr(),
              'pp_bullet1_4'.tr(),
            ]),
            _sectionTitle('pp_section2'.tr()),
            _bulletList([
              'pp_bullet2_1'.tr(),
              'pp_bullet2_2'.tr(),
              'pp_bullet2_3'.tr(),
              'pp_bullet2_4'.tr(),
            ]),
            _sectionTitle('pp_section3'.tr()),
            _paragraph('pp_paragraph3'.tr()),
            _bulletList([
              'pp_bullet3_1'.tr(),
              'pp_bullet3_2'.tr(),
            ]),
            _sectionTitle('pp_section4'.tr()),
            _paragraph('pp_paragraph4'.tr()),
            _sectionTitle('pp_section5'.tr()),
            _paragraph('pp_paragraph5'.tr()),
            _sectionTitle('pp_section6'.tr()),
            _paragraph('pp_paragraph6'.tr()),
            _sectionTitle('pp_section7'.tr()),
            _paragraph('pp_paragraph7'.tr()),
            _sectionTitle('pp_section8'.tr()),
            _paragraph('pp_paragraph8'.tr()),
            _sectionTitle('pp_section9'.tr()),
            _paragraph('pp_paragraph9'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  Widget _paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 14)),
  );

  Widget _bulletList(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items
        .map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(item, style: const TextStyle(fontSize: 14))),
        ],
      ),
    ))
        .toList(),
  );
}