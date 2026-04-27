import 'package:flutter/material.dart';

class PracticeTaskInfoChip extends StatelessWidget {
  const PracticeTaskInfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final chipColor = onTap == null
        ? const Color(0xFFF8FAFC)
        : const Color(0xFFEAFBF1);
    final borderColor = onTap == null ? null : const Color(0xFFD6F2E2);

    if (iconOnly) {
      final chip = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(14),
          border: borderColor == null ? null : Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2FA77D)),
      );

      final wrapped = Tooltip(message: label, child: chip);
      if (onTap == null) {
        return wrapped;
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: wrapped,
        ),
      );
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(14),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2FA77D)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: Color(0xFF2FA77D),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: chip,
      ),
    );
  }
}
