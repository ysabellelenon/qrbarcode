import 'package:flutter/material.dart';

const Color kBackgroundColor =
    Color(0xFFF5F5F5); // Use the color from engineer_login
const Color kPrimaryColor = Colors.deepPurple;

// Border Radius Constants
const double kBorderNoneSmall = 0.0;
const double kBorderRadiusSmall = 8.0;
const double kBorderRadiusMedium = 12.0;
const double kBorderRadiusLarge = 16.0;

// Border Radius Styles
final kBorderRadiusNoneAll = BorderRadius.circular(kBorderNoneSmall);
final kBorderRadiusSmallAll = BorderRadius.circular(kBorderRadiusSmall);
final kBorderRadiusMediumAll = BorderRadius.circular(kBorderRadiusMedium);
final kBorderRadiusLargeAll = BorderRadius.circular(kBorderRadiusLarge);

// Dialog Size Constants
const Size kDialogSizeSmall = Size(400, 300);
const Size kDialogSizeMedium = Size(500, 400);
const Size kDialogSizeLarge = Size(600, 500);

// Dialog Constraints
const BoxConstraints kDialogConstraintsSmall = BoxConstraints(
  maxWidth: 400,
  minWidth: 300,
  maxHeight: 300,
  minHeight: 200,
);

const BoxConstraints kDialogConstraintsMedium = BoxConstraints(
  maxWidth: 500,
  minWidth: 400,
  maxHeight: 400,
  minHeight: 300,
);

const BoxConstraints kDialogConstraintsLarge = BoxConstraints(
  maxWidth: 600,
  minWidth: 500,
  maxHeight: 500,
  minHeight: 400,
);
