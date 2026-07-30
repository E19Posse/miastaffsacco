import 'package:flutter/material.dart';
import 'package:unicons/unicons.dart';
import '../theme/app_theme.dart';

enum StepDotState { done, current, pending, failed }

/// Horizontal multi-stage progress indicator (e.g. Submitted → Under Review →
/// Approved → Disbursed). Generalized from the KYC screen's 2-step version.
class StepProgress extends StatelessWidget {
  final List<String> labels;
  final List<StepDotState> states;
  const StepProgress({super.key, required this.labels, required this.states})
      : assert(labels.length == states.length);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      children.add(_StepDot(number: i + 1, label: labels[i], state: states[i]));
      if (i < labels.length - 1) {
        final lineFilled = states[i] == StepDotState.done;
        children.add(Expanded(child: Container(height: 2,
            color: lineFilled ? AppColors.emeraldDeep : c.border)));
      }
    }
    return Row(children: children);
  }
}

class _StepDot extends StatelessWidget {
  final int number; final String label; final StepDotState state;
  const _StepDot({required this.number, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = switch (state) {
      StepDotState.done    => AppColors.emeraldDeep,
      StepDotState.current => AppColors.gold,
      StepDotState.failed  => AppColors.danger,
      StepDotState.pending => c.surface,
    };
    final border = state == StepDotState.pending ? c.border : bg;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(
          child: switch (state) {
            StepDotState.done    => const Icon(UniconsLine.check, color: Colors.black, size: 16),
            StepDotState.failed  => const Icon(UniconsLine.times, color: Colors.white, size: 16),
            _ => Text('$number', style: TextStyle(
                color: state == StepDotState.current ? Colors.white : c.textSecondary,
                fontSize: 13, fontWeight: FontWeight.w700)),
          },
        ),
      ),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: state == StepDotState.pending ? c.textHint : AppColors.emeraldDeep,
          fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}
