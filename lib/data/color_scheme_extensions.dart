import 'package:flutter/material.dart';

extension CounterSpellColorScheme on ColorScheme {
  /// A darker shade of [primaryContainer], for surfaces that sit *behind* a
  /// primaryContainer element — e.g. the +/- pill behind the pill editor's
  /// highlighted center capsule.
  Color get primaryContainerDim => Color.alphaBlend(
    Colors.black.withValues(alpha: 0.35),
    primaryContainer,
  );
}
