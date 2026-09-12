import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/detection.dart';
import 'person_avatar.dart';
import 'status_badge.dart';

class DetectionCard extends StatelessWidget {
  const DetectionCard({super.key, required this.detection, required this.onTap});

  final Detection detection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('dd/MM HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PersonAvatar(detection: detection),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detection.displayCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        StatusBadge(status: detection.status, dense: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.videocam_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            detection.cameraLocation,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeFormat.format(detection.detectedAt),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                    if (detection.occurrenceCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${detection.occurrenceCount} ocorrência(s) anterior(es)',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
