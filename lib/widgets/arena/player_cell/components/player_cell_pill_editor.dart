import 'dart:async';
import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:counter_spell/main.dart';
import 'package:counter_spell/models/game/partner_vectors.dart';
import 'package:counter_spell/models/interaction/pill_focus.dart';
import 'package:counter_spell/models/pages.dart';
import 'package:counter_spell/widgets/arena/player_cell/arena_player_cell.dart';
import 'package:flutter/material.dart';
import 'package:sid_base/sid_base.dart';

/// Takes over the arena cell to edit a single count-bearing pill (a numeric
/// counter or a commander-cast). Renders as a centered horizontal control — a
/// `+` on the left, the icon + live value in a highlighted capsule, a `−` on
/// the right — floating over the commander art (the rest of the cell UI is
/// hidden by [PlayerCellBody] while this is shown).
///
/// Tapping outside the control closes it; once the player has interacted it
/// also closes itself after the confirmation-delay of inactivity.
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

  /// Where the control animates from/to — the top-right corner, where the
  /// tapped count pills live, so it reads as the pill repositioning itself.
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
      // Always return to the normal (basic) cell view — if the editor was
      // opened from the advanced page, leave that page too.
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
    // The center capsule matches the original quick-info pill
    // (primaryContainer); the +/- pill behind is a darker shade of it.
    final Color behindColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.35),
      colorScheme.primaryContainer,
    );

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
        // The whole control is a horizontal pill: [+] [icon value] [-],
        // with the center capsule noticeably taller than the +/- pill.
        final double centerHeight = side * 0.34;
        final double behindHeight = centerHeight / 1.5;
        final double buttonZone = behindHeight * 0.85;
        final double centerWidth = centerHeight * 1.3;

        final Widget control = Stack(
          alignment: Alignment.center,
          children: [
            // Pill behind, holding the + and - buttons.
            Container(
              height: behindHeight,
              decoration: BoxDecoration(
                color: behindColor,
                borderRadius: BorderRadius.circular(behindHeight / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: buttonZone,
                    child: _StepButton(
                      icon: Icons.add,
                      color: colorScheme.onPrimaryContainer,
                      onTap: () => _edit(1),
                    ),
                  ),
                  SizedBox(width: centerWidth),
                  SizedBox(
                    width: buttonZone,
                    child: _StepButton(
                      icon: Icons.remove,
                      color: colorScheme.onPrimaryContainer,
                      onTap: () => _edit(-1),
                    ),
                  ),
                ],
              ),
            ),
            // Highlighted center capsule with the icon + live value.
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

        // Animate the control in/out as if the tapped pill repositions itself
        // from its top-right origin to the center, scaling up and fading in.
        return AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final double t = _t.value;
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Stack(
                children: [
                  // Tapping outside the control closes the editor.
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
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Center(child: Icon(icon, color: color, size: 28)),
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
