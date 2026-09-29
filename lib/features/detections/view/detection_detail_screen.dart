import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/facetrack_app_bar.dart';
import '../cubit/detections_cubit.dart';
import '../data/models/detection.dart';
import '../data/models/occurrence.dart';
import 'widgets/status_badge.dart';

class DetectionDetailScreen extends StatelessWidget {
  const DetectionDetailScreen({super.key, required this.detectionId});

  final String detectionId;

  @override
  Widget build(BuildContext context) {
    final detection = context.select(
      (DetectionsCubit cubit) => cubit.state.detections
          .where((item) => item.id == detectionId)
          .firstOrNull,
    );

    if (detection == null) {
      return const Scaffold(
        appBar: FaceTrackAppBar(title: 'Detecção', showBack: true),
        body: Center(child: Text('Detecção não encontrada.')),
      );
    }

    return Scaffold(
      appBar: FaceTrackAppBar(title: 'Informações detalhadas', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _IdentityCard(detection: detection),
          const SizedBox(height: 14),
          _BiometricComparison(detection: detection),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.terminal_rounded,
            title: 'INFORMAÇÕES DA DETECÇÃO',
          ),
          const SizedBox(height: 10),
          _EventSpecifications(detection: detection),
          if (!detection.isSuperCloud &&
              (detection.notes?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.shield_outlined,
              title: 'OBSERVAÇÕES OPERACIONAIS',
            ),
            const SizedBox(height: 10),
            _NotesCard(notes: detection.notes!),
          ],
          if (detection.occurrenceHistory.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              icon: Icons.history_rounded,
              title: 'OCORRÊNCIAS ANTERIORES',
            ),
            const SizedBox(height: 10),
            ...detection.occurrenceHistory.sortedByDateDesc().map(
              (occurrence) => _OccurrenceTile(occurrence: occurrence),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border(
          left: BorderSide(color: detection.status.color, width: 5),
          top: const BorderSide(color: AppColors.stroke),
          right: const BorderSide(color: AppColors.stroke),
          bottom: const BorderSide(color: AppColors.stroke),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(status: detection.status, label: detection.riskLabel),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            detection.isSuperCloud
                ? 'Ocorrência #${detection.occurrenceNumber}'
                : detection.displayCode,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          if (detection.isSuperCloud) ...[
            const SizedBox(height: 5),
            const Text(
              'Ocorrência recebida da rede FaceTrack',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (detection.acknowledgedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.actionDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: AppColors.action,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Alerta confirmado às ${DateFormat('HH:mm').format(detection.acknowledgedAt!)}',
                    style: const TextStyle(
                      color: AppColors.action,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BiometricComparison extends StatelessWidget {
  const _BiometricComparison({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final confidence = detection.confidence;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_rounded, color: AppColors.action, size: 21),
              SizedBox(width: 8),
              Text(
                'COMPARAÇÃO BIOMÉTRICA',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ComparisonPhoto(
                  label: 'FLAGRANTE',
                  bytes: detection.photoBytes,
                  accent: detection.status.color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ComparisonPhoto(
                  label: detection.isSuperCloud
                      ? 'FOTO LOCAL'
                      : 'CADASTRO OFICIAL',
                  bytes: detection.registeredPhotoBytes,
                  accent: AppColors.action,
                ),
              ),
            ],
          ),
          if (confidence != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CONFIANÇA BIOMÉTRICA',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.action,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 9,
                color: AppColors.action,
                backgroundColor: AppColors.surfaceElevated,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonPhoto extends StatelessWidget {
  const _ComparisonPhoto({
    required this.label,
    required this.bytes,
    required this.accent,
  });

  final String label;
  final List<int>? bytes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 0.82,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent),
              image: bytes == null || bytes!.isEmpty
                  ? null
                  : DecorationImage(
                      image: MemoryImage(Uint8List.fromList(bytes!)),
                      fit: BoxFit.cover,
                    ),
            ),
            child: bytes == null || bytes!.isEmpty
                ? Icon(Icons.person_outline_rounded, color: accent, size: 48)
                : null,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(Icons.circle, color: accent, size: 8),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventSpecifications extends StatelessWidget {
  const _EventSpecifications({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _SpecCard(
        icon: Icons.schedule_rounded,
        label: 'DETECTADO EM',
        value: DateFormat('dd/MM/yyyy\nHH:mm:ss').format(detection.detectedAt),
      ),
      if (detection.originStoreName?.trim().isNotEmpty == true)
        _SpecCard(
          icon: Icons.storefront_outlined,
          label: 'LOJA DE ORIGEM',
          value: detection.originStoreName!.trim(),
        ),
      if (detection.cameraLocation.trim().isNotEmpty)
        _SpecCard(
          icon: Icons.videocam_outlined,
          label: 'CÂMERA (SERVIDOR ANTIGO)',
          value: detection.cameraLocation,
        ),
      if (!detection.isSuperCloud &&
          detection.registeredBy?.trim().isNotEmpty == true)
        _SpecCard(
          icon: Icons.badge_outlined,
          label: 'CADASTRADO POR',
          value: detection.registeredBy!.trim(),
        ),
      if (!detection.isSuperCloud && detection.createdAt != null)
        _SpecCard(
          icon: Icons.event_available_outlined,
          label: 'CADASTRADO EM',
          value: DateFormat('dd/MM/yyyy\nHH:mm').format(detection.createdAt!),
        ),
      if (detection.isSuperCloud)
        _SpecCard(
          icon: Icons.public_rounded,
          label: 'NÚMERO NACIONAL',
          value: '#${detection.occurrenceNumber}',
        ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.action, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(
        notes,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.action, size: 19),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.circle, color: AppColors.danger, size: 9),
        title: Text(
          '${DateFormat('dd/MM/yyyy').format(occurrence.date)} · ${occurrence.cameraLocation}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(occurrence.description),
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
