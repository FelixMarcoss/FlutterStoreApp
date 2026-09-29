import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/detection.dart';
import 'status_badge.dart';

class DetectionCard extends StatelessWidget {
  const DetectionCard({
    super.key,
    required this.detection,
    required this.onTap,
  });

  final Detection detection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final confidence = detection.confidence == null
        ? null
        : '${(detection.confidence! * 100).toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ColoredBox(
              color: detection.status.color,
              child: const SizedBox(width: 5),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(
                          status: detection.status,
                          dense: true,
                          label: detection.riskLabel,
                        ),
                        const Spacer(),
                        Text(
                          timeFormat.format(detection.detectedAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetectionThumbnail(detection: detection),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detection.displayCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                !detection.isSuperCloud &&
                                        detection.notes?.trim().isNotEmpty ==
                                            true
                                    ? detection.notes!
                                    : detection.riskLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (detection.availableLocation != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      detection.originStoreName
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? Icons.storefront_outlined
                                          : Icons.videocam_outlined,
                                      size: 16,
                                      color: detection.status.color,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        detection.availableLocation!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (confidence != null) ...[
                                const SizedBox(height: 7),
                                Text(
                                  '$confidence de correspondência',
                                  style: TextStyle(
                                    color: detection.status.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (detection.acknowledgedAt != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.actionDark,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.done_all_rounded,
                              color: AppColors.action,
                              size: 15,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Ciente',
                              style: TextStyle(
                                color: AppColors.action,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionThumbnail extends StatelessWidget {
  const _DetectionThumbnail({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final bytes = detection.photoBytes;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: detection.status.color),
        image: bytes == null || bytes.isEmpty
            ? null
            : DecorationImage(
                image: MemoryImage(Uint8List.fromList(bytes)),
                fit: BoxFit.cover,
              ),
      ),
      child: bytes == null || bytes.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              color: detection.status.color,
              size: 38,
            )
          : null,
    );
  }
}
