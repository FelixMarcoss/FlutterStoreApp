import 'package:flutter/material.dart';

import '../../data/models/detection_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.dense = false,
    this.label,
  });

  final DetectionStatus status;
  final bool dense;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: status.color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: dense ? 14 : 16, color: status.color),
          const SizedBox(width: 4),
          Text(
            (label ?? status.label).toUpperCase(),
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.w800,
              fontSize: dense ? 10 : 11.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
