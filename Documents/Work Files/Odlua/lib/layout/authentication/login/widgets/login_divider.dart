import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../utils/constants/colors.dart';

class LoginDivider extends StatelessWidget {
  const LoginDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Flexible(
          child: Divider(
            color: NColors.darkGrey,
            thickness: 0.5,
            indent: 10,
            endIndent: 5,
          ),
        ),
        Text(
          'or_sign_in_with'.tr(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const Flexible(
          child: Divider(
            color: NColors.darkGrey,
            thickness: 0.5,
            indent: 5,
            endIndent: 10,
          ),
        ),
      ],
    );
  }
}