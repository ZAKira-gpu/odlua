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