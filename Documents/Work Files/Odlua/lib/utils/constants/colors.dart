import 'package:flutter/material.dart';


class NColors {
  NColors._();

  ///App Basic Colors
  static const Color primary =  Color(0xFF4b68ff);
  static const Color secondary =  Color(0xFFFFE24B);
  static const Color accent =  Color(0xFFb0c7ff);


  ///Gradient Colors
  static const Gradient linearGradient =  LinearGradient(
      begin: Alignment(0.0, 0.0),
      end: Alignment(0.707, -0.707),
      colors: [
        Color(0xffff9a9e),
        Color(0xfff8b2b4),
        Color(0xfff1c2c4),
      ]
  );


  ///Text Colors
  static const Color textPrimary =  Color(0xFF333333);
  static const Color textSecondary =  Color(0xFF6c757D);
  static const Color textWhite =  Colors.white;


  ///Background Colors
  static const Color light =  Color(0xFFFFFFFF);
  static const Color dark =  Color(0x0f090b15);
  static const Color primaryBackground =  Colors.white;


  ///Background Container Colors
  static const Color lightContainer =  Color(0xFFFFFFFF);
  static Color darkContainer =  NColors.textWhite.withOpacity(0.1);


  ///Button Colors
  static const Color buttonPrimary =  Color(0xFF4b68ff);
  static const Color buttonSecondary =  Color(0xFF6c757D);
  static const Color buttonDisabled =  Color(0xFFFFFFFF);


  ///Border Colors
  static const Color borderPrimary =  Color(0xFFFFFFFF);
  static const Color borderSecondary =  Color(0xFFFFFFFF);


  ///Error and validation Colors
  static const Color error =  Color(0xffed2b4e);
  static const Color success =  Color(0xff25912a);
  static const Color warning =  Color(0xFFEF8538);
  static const Color info =  Color(0xFF2B6DE8);


  ///Neutral Shades
  static const Color black =  Color(0xff000000);
  static const Color darkerGrey =  Color(0xFF302E2E);
  static const Color darkGrey =  Color(0xFF403F3E);
  static const Color grey =  Color(0xFF78797A);
  static const Color softGrey =  Color(0xff9f9d9d);
  static const Color softerGrey =  Color(0xffa3a6a3);
  static const Color lightGrey =  Color(0xFFCAC9C9);
  static const Color white =  Color(0xFFFBFBFB);
}