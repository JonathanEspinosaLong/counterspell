import 'package:counter_spell/models/game/counter.dart';

/// Identifies which count-bearing quick-info pill has taken over an arena cell
/// for focused +/- editing. Boolean statuses have no count and are excluded.
sealed class PillFocus {
  const PillFocus();
}

/// A numeric counter pill (poison, energy, rad, experience, storm, ...).
class CounterPillFocus extends PillFocus {
  const CounterPillFocus(this.counter);
  final Counter counter;

  @override
  bool operator ==(Object other) =>
      other is CounterPillFocus && other.counter == counter;

  @override
  int get hashCode => counter.hashCode;
}

/// A commander-cast pill for partner A or B.
class CastPillFocus extends PillFocus {
  const CastPillFocus({required this.partnerA});
  final bool partnerA;

  @override
  bool operator ==(Object other) =>
      other is CastPillFocus && other.partnerA == partnerA;

  @override
  int get hashCode => partnerA.hashCode;
}
