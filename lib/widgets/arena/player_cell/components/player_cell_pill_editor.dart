import 'dart:async';
import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:counter_spell/data/color_scheme_extensions.dart';
import 'package:counter_spell/main.dart';
import 'package:counter_spell/models/game/partner_vectors.dart';
import 'package:counter_spell/models/interaction/pill_focus.dart';
import 'package:counter_spell/models/pages.dart';
import 'package:counter_spell/widgets/arena/player_cell/arena_player_cell.dart';
import 'package:counter_spell/widgets/arena/player_cell/components/player_cell_side_taps.dart';
import 'package:flutter/material.dart';
import 'package:sid_base/sid_base.dart';

class PlayerCellPillEditor extends StatefulWidget {
  const PlayerCellPillEditor({
    super.key,
    required this.playerIndex,
    required this.focus,
  });

  final int playerIndex;
  final PillFocus focus;

  @override
  State<PlayerCellPillEditor> createState() => _PlayerCellPillEditorState();
}

class _PlayerCellPillEditorState extends State<PlayerCellPillEditor>
    with SingleTickerProviderStateMixin {
  Timer? _autoCloseTimer;
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _closing = false;

  static const Alignment _origin = Alignment.topRight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Durations.medium4,
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _autoCloseTimer?.cancel();
    await _controller.reverse();
    if (mounted) {
      final controller = context.arenaPlayerController;
      controller.advanced.update(false);
      controller.focusedPill.update(null);
    }
  }

  void _scheduleAutoClose() {
    _autoCloseTimer?.cancel();
    final delay = context.counterSpell.interactionLogic.confirmationDelay.value;
    _autoCloseTimer = Timer(delay, () {
      if (mounted) _close();
    });
  }

  void _edit(int amount) {
    final gameLogic = context.counterSpell.gameLogic;
    switch (widget.focus) {
      case CounterPillFocus(:final counter):
        gameLogic.editGame(
          (game) => game.addCounters(
            playerIndex: widget.playerIndex,
            counter: counter,
            amount: amount,
          ),
        );
      case CastPillFocus(:final partnerA):
        gameLogic.editGame(
          (game) => game.castCommander(
            playerIndex: widget.playerIndex,
            partnerA: partnerA,
            times: amount,
          ),
        );
    }
    _scheduleAutoClose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final Color behindColor = colorScheme.primaryContainerDim;

    final IconData icon = switch (widget.focus) {
      CounterPillFocus(:final counter) => counter.bigIcon,
      CastPillFocus() => BodyPage.cast.filledIcon,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final double side = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final double centerHeight = side * 0.34;
        final double behindHeight = centerHeight / 1.5;
        final double buttonZone = behindHeight * 0.85;
        final double centerWidth = centerHeight * 1.3;

        final Widget control = Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: behindColor,
              borderRadius: BorderRadius.circular(behindHeight / 2),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: behindHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: buttonZone + centerWidth / 2,
                      child: _StepButton(
                        icon: Icons.remove,
                        color: colorScheme.onPrimaryContainer,
                        sign: -1,
                        onEdit: _edit,
                        iconAlignment: Alignment.centerLeft,
                        iconZone: buttonZone,
                      ),
                    ),
                    SizedBox(
                      width: buttonZone + centerWidth / 2,
                      child: _StepButton(
                        icon: Icons.add,
                        color: colorScheme.onPrimaryContainer,
                        sign: 1,
                        onEdit: _edit,
                        iconAlignment: Alignment.centerRight,
                        iconZone: buttonZone,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: centerWidth,
              height: centerHeight,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(centerHeight / 2),
              ),
              child: _CenterValue(
                icon: icon,
                color: colorScheme.onPrimaryContainer,
                playerIndex: widget.playerIndex,
                focus: widget.focus,
              ),
            ),
          ],
        );

        return AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final double t = _t.value;
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                    ),
                  ),
                  Align(
                    alignment: Alignment.lerp(_origin, Alignment.center, t)!,
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * t,
                      child: control,
                    ),
                  ),
                  Positioned(
                    top: side * 0.06,
                    right: side * 0.06,
                    child: _CloseButton(
                      size: centerHeight * 0.5,
                      iconColor: colorScheme.onPrimaryContainer,
                      onTap: _close,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.sign,
    required this.onEdit,
    required this.iconAlignment,
    required this.iconZone,
  });

  final IconData icon;
  final Color color;
  final int sign;
  final void Function(int amount) onEdit;
  final AlignmentGeometry iconAlignment;
  final double iconZone;

  @override
  Widget build(BuildContext context) {
    return ContinuedLongPress(
      onTapDown: () => onEdit(sign),
      onTapUp: () {},
      onContinuedLongPress: (duration) {
        final n = continuedLongPressMultiplier(duration);
        if (n != null) onEdit(sign * n);
      },
      child: Align(
        alignment: iconAlignment,
        child: SizedBox(
          width: iconZone,
          child: Center(child: Icon(icon, color: color, size: 28)),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.size,
    required this.iconColor,
    required this.onTap,
  });

  final double size;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: Center(
          child: Icon(Icons.close, color: iconColor, size: size * 0.6),
        ),
      ),
    );
  }
}

class _CenterValue extends StatelessWidget {
  const _CenterValue({
    required this.icon,
    required this.color,
    required this.playerIndex,
    required this.focus,
  });

  final IconData icon;
  final Color color;
  final int playerIndex;
  final PillFocus focus;

  @override
  Widget build(BuildContext context) {
    final layout = context.theme.layout;
    return context.counterSpell.gameLogic.buildWithGame((context, game) {
      final state = game.currentState.playerStates[playerIndex];
      final int value = switch (focus) {
        CounterPillFocus(:final counter) => state.counters[counter] ?? 0,
        CastPillFocus(:final partnerA) => state.commanderCasts.of(partnerA),
      };
      return Pad(
        all: layout.padding.small,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Icon(icon, color: color)),
            Space.horizontal(layout.spacing.small),
            Flexible(
              child: FittedBox(
                child: DefaultTextStyle(
                  style: context.theme.textTheme.titleLarge!.copyWith(
                    color: color,
                  ),
                  child: AutoSizeText(value.toString(), maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
