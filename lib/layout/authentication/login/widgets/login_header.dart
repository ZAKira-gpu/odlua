// ─────────────────────────────────────────
// Widget: LoginHeader
// Description: Logo and welcome text at the top of the login screen.
// Contains: Logo image, title, subtitle
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'login_title'.tr(),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'login_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}