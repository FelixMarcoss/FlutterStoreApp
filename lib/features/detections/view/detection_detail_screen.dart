import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../cubit/detections_cubit.dart';
import '../data/models/occurrence.dart';
import 'widgets/person_avatar.dart';
import 'widgets/status_badge.dart';

class DetectionDetailScreen extends StatelessWidget {
  const DetectionDetailScreen({super.key, required this.detectionId});

  final String detectionId;

  @override
  Widget build(BuildContext context) {
    final detection = context.select((DetectionsCubit c) =>
        c.state.detections.where((d) => d.id == detectionId).firstOrNull);

    if (detection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detecção')),
        body: const Center(child: Text('Detecção não encontrada.')),
      );
    }

    final dateTimeFormat = DateFormat("dd/MM/yyyy 'às' HH:mm");

    return Scaffold(
      appBar: AppBar(title: Text(detection.displayCode)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                PersonAvatar(detection: detection, radius: 44),
                const SizedBox(height: 12),
                Text(
                  detection.displayCode,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                StatusBadge(status: detection.status),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.videocam_outlined,
                    label: 'Detectado em',
                    value: '${detection.cameraLocation} · ${dateTimeFormat.format(detection.detectedAt)}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.history_rounded,
                    label: 'Ocorrências anteriores',
                    value: '${detection.occurrenceCount}',
                  ),
                  if (detection.acknowledgedAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Alerta confirmado por você',
                      value: dateTimeFormat.format(detection.acknowledgedAt!),
                      valueColor: AppColors.success,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (detection.occurrenceHistory.isNotEmpty) ...[
            const Text(
              'Histórico de ocorrências',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...detection.occurrenceHistory
                .sortedByDateDesc()
                .map((o) => _OccurrenceTile(occurrence: o)),
          ] else
            const Text(
              'Nenhuma ocorrência anterior registrada.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _SortedOccurrences on List<Occurrence> {
  List<Occurrence> sortedByDateDesc() =>
      [...this]..sort((a, b) => b.date.compareTo(a.date));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence});
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: AppColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dateFormat.format(occurrence.date)} · ${occurrence.cameraLocation}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  occurrence.description,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
