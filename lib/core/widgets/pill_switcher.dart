import 'package:flutter/material.dart';

/// Two or more segments in a rounded gray track; the selected one is a soft
/// red pill with bold red text. Used by the Activity and History tabs.
class PillSwitcher<T> extends StatelessWidget {
  const PillSwitcher({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  static const softRed = Color(0xFFFDECEC);
  static const red = Color(0xFFC62828);
  static const track = Color(0xFFF1F1F1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: value == selected ? softRed : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: value == selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: value == selected ? red : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
