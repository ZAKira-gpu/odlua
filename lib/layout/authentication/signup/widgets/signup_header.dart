// ─────────────────────────────────────────
// Widget: SignupHeader
// Description: Title and description at the top of the signup screen.
// Contains: Title text, subtitle text
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SignupHeader extends StatelessWidget {
  const SignupHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'signup_title'.tr(),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ],
    );
  }
}