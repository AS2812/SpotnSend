import 'package:flutter/material.dart';

import 'colors.dart';

class AppGradients {
  static const Alignment _start = Alignment.topLeft;
  static const Alignment _end = Alignment.bottomRight;

  static const LinearGradient heading = LinearGradient(
    begin: _start,
    end: _end,
    colors: [
      AppColors.primaryBlue,
      AppColors.primaryMagenta,
      AppColors.primaryRed,
    ],
  );

  static const LinearGradient background = LinearGradient(
    begin: _start,
    end: _end,
    colors: [
      AppColors.primaryIndigo,
      AppColors.primaryMagenta,
      AppColors.primaryRed,
    ],
  );
}
