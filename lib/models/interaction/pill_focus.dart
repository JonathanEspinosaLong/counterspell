import 'package:counter_spell/models/game/counter.dart';

sealed class PillFocus {
  const PillFocus();
}

class CounterPillFocus extends PillFocus {
  const CounterPillFocus(this.counter);
  final Counter counter;

  @override
  bool operator ==(Object other) =>
      other is CounterPillFocus && other.counter == counter;

  @override
  int get hashCode => counter.hashCode;
}

class CastPillFocus extends PillFocus {
  const CastPillFocus({required this.partnerA});
  final bool partnerA;

  @override
  bool operator ==(Object other) =>
      other is CastPillFocus && other.partnerA == partnerA;

  @override
  int get hashCode => partnerA.hashCode;
}
