import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/request_progress.dart';

const requestRed = Color(0xFFC62828);
const requestSoftRed = Color(0xFFFDECEC);
const requestBorder = Color(0xFFEDEDED);

(Color background, Color foreground) toneColors(ProgressTone tone) =>
    switch (tone) {
      ProgressTone.amber => (const Color(0xFFFFF4E0), const Color(0xFFB26A00)),
      ProgressTone.blue => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      ProgressTone.green => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      ProgressTone.red => (requestSoftRed, requestRed),
      ProgressTone.grey => (const Color(0xFFF1F1F1), Colors.black54),
    };

String formatRequestDate(DateTime? date) =>
    date == null ? 'Not specified' : DateFormat('MMMM d, yyyy').format(date);

class BloodTypeBadge extends StatelessWidget {
  const BloodTypeBadge(this.bloodType, {super.key, this.size = 52});

  final String bloodType;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: requestSoftRed,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      bloodType,
      style: TextStyle(
        fontSize: size * 0.34,
        fontWeight: FontWeight.bold,
        color: requestRed,
      ),
    ),
  );
}

class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: requestRed,
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.priority_high_rounded, size: 12, color: Colors.white),
        SizedBox(width: 2),
        Text(
          'Urgent',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.progress, {super.key});

  final RequestProgress progress;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(progress.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        progress.chipLabel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class RequestStatusCallout extends StatelessWidget {
  const RequestStatusCallout(this.progress, {super.key, this.heading});

  final RequestProgress progress;

  /// Optional small label above the title, e.g. "Current Status".
  final String? heading;

  IconData get _icon => switch (progress.tone) {
    ProgressTone.amber => Icons.manage_search_rounded,
    ProgressTone.blue => Icons.people_alt_outlined,
    ProgressTone.green => Icons.check_circle_outline,
    ProgressTone.red => Icons.error_outline,
    ProgressTone.grey => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(progress.tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading != null)
                  Text(heading!, style: TextStyle(fontSize: 11, color: fg)),
                Text(
                  progress.calloutTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  progress.calloutMessage,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value rows of the Request Information section.
class RequestInfoRows extends StatelessWidget {
  const RequestInfoRows({super.key, required this.rows});

  final List<(String, Widget)> rows;

  static List<(String, Widget)> basic(RequestProgress p) => [
    ('Blood Type Needed', _value(p.bloodType)),
    ('Units Needed', _value(p.unitsText)),
    ('Hospital', _value(p.hospital)),
    ('Location', _value(p.location)),
    ('Date Needed', _value(formatRequestDate(p.neededBy))),
    (
      'Urgency Level',
      p.isUrgent
          ? const Align(alignment: Alignment.centerLeft, child: UrgentBadge())
          : _value('Normal'),
    ),
  ];

  static Widget _value(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  );

  static Widget value(String text) => _value(text);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                Expanded(child: value),
              ],
            ),
          ),
      ],
    );
  }
}

/// The 4-step vertical Request Progress timeline.
class RequestProgressTimeline extends StatelessWidget {
  const RequestProgressTimeline({super.key, required this.steps});

  final List<ProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final ProgressStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData? icon) = switch (step.state) {
      ProgressStepState.done => (const Color(0xFF2E7D32), Icons.check),
      ProgressStepState.active => (requestRed, null),
      ProgressStepState.stopped => (Colors.black45, Icons.close),
      ProgressStepState.upcoming => (const Color(0xFFD0D0D0), null),
    };
    final filled = step.state != ProgressStepState.upcoming;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  key: ValueKey('step-${step.title}-${step.state.name}'),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? color : Colors.white,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: icon != null
                      ? Icon(icon, size: 14, color: Colors.white)
                      : step.state == ProgressStepState.active
                      ? const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: step.state == ProgressStepState.done
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: step.state == ProgressStepState.active
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: step.state == ProgressStepState.upcoming
                          ? Colors.black45
                          : step.state == ProgressStepState.active
                          ? requestRed
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded card used across the Activity and Request Details screens.
class RequestCardShell extends StatelessWidget {
  const RequestCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: requestBorder),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class RequestSectionTitle extends StatelessWidget {
  const RequestSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );
}
