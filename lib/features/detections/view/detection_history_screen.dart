import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/facetrack_app_bar.dart';
import '../../../core/widgets/facetrack_navigation_bar.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/detections_cubit.dart';
import '../data/models/detection.dart';
import '../data/models/detection_status.dart';
import 'widgets/status_badge.dart';

class DetectionHistoryScreen extends StatefulWidget {
  const DetectionHistoryScreen({super.key});

  @override
  State<DetectionHistoryScreen> createState() => _DetectionHistoryScreenState();
}

class _DetectionHistoryScreenState extends State<DetectionHistoryScreen> {
  final _searchController = TextEditingController();
  DetectionStatus? _filter;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<SessionCubit>().state;
    return Scaffold(
      appBar: FaceTrackAppBar(
        title: 'Histórico',
        subtitle: connection?.address.toUpperCase(),
      ),
      bottomNavigationBar: const FaceTrackNavigationBar(currentIndex: 1),
      body: BlocBuilder<DetectionsCubit, DetectionsState>(
        builder: (context, state) {
          final normalizedQuery = _query.trim().toLowerCase();
          final detections = state.detections.where((item) {
            final matchesRisk = _filter == null || item.status == _filter;
            final matchesQuery =
                normalizedQuery.isEmpty ||
                item.displayCode.toLowerCase().contains(normalizedQuery) ||
                item.cameraLocation.toLowerCase().contains(normalizedQuery) ||
                (item.originStoreName?.toLowerCase().contains(
                      normalizedQuery,
                    ) ??
                    false) ||
                (item.occurrenceNumber?.toString().contains(normalizedQuery) ??
                    false);
            return matchesRisk && matchesQuery;
          }).toList()..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

          final groups = _groupByDate(detections);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Histórico de ocorrências',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${detections.length} itens',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Registro local dos alertas recebidos do servidor.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome, loja ou câmera',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _HistoryFilterChip(
                              label: 'Todos os riscos',
                              selected: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            _HistoryFilterChip(
                              label: 'Alto risco',
                              selected: _filter == DetectionStatus.knownThief,
                              onTap: () => setState(
                                () => _filter = DetectionStatus.knownThief,
                              ),
                            ),
                            _HistoryFilterChip(
                              label: 'Risco médio',
                              selected: _filter == DetectionStatus.suspect,
                              onTap: () => setState(
                                () => _filter = DetectionStatus.suspect,
                              ),
                            ),
                            _HistoryFilterChip(
                              label: 'Informativo',
                              selected: _filter == DetectionStatus.newPerson,
                              onTap: () => setState(
                                () => _filter = DetectionStatus.newPerson,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (detections.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Nenhuma ocorrência encontrada.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                for (final group in groups) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: _DateHeader(
                        date: group.date,
                        count: group.items.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: group.items.length,
                      itemBuilder: (context, index) {
                        final detection = group.items[index];
                        return _HistoryCard(
                          detection: detection,
                          onTap: () =>
                              context.push('/detection/${detection.id}'),
                        );
                      },
                    ),
                  ),
                ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.action,
        backgroundColor: AppColors.surfaceElevated,
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: selected ? AppColors.background : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _DateGroup {
  const _DateGroup(this.date, this.items);
  final DateTime date;
  final List<Detection> items;
}

List<_DateGroup> _groupByDate(List<Detection> detections) {
  final result = <_DateGroup>[];
  for (final detection in detections) {
    final date = DateTime(
      detection.detectedAt.year,
      detection.detectedAt.month,
      detection.detectedAt.day,
    );
    if (result.isEmpty || result.last.date != date) {
      result.add(_DateGroup(date, [detection]));
    } else {
      result.last.items.add(detection);
    }
  }
  return result;
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    final prefix = difference == 0
        ? 'HOJE'
        : difference == 1
        ? 'ONTEM'
        : 'ANTERIOR';
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return Row(
      children: [
        const Icon(Icons.circle, color: AppColors.action, size: 8),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$prefix — $formatted',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Text(
          '$count detecções',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.detection, required this.onTap});

  final Detection detection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = detection.photoBytes;
    final confidence = detection.confidence == null
        ? null
        : '${(detection.confidence! * 100).toStringAsFixed(1)}%';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(9),
                  image: photo == null || photo.isEmpty
                      ? null
                      : DecorationImage(
                          image: MemoryImage(Uint8List.fromList(photo)),
                          fit: BoxFit.cover,
                        ),
                ),
                child: photo == null || photo.isEmpty
                    ? Icon(
                        Icons.person_outline_rounded,
                        color: detection.status.color,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detection.displayCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(detection.detectedAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detection.availableLocation ??
                                'Local não informado',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (confidence != null)
                          Text(
                            confidence,
                            style: const TextStyle(
                              color: AppColors.action,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        StatusBadge(
                          status: detection.status,
                          dense: true,
                          label: detection.riskLabel,
                        ),
                        if (detection.acknowledgedAt != null) ...[
                          const SizedBox(width: 7),
                          Text(
                            'Ciente às ${DateFormat('HH:mm').format(detection.acknowledgedAt!)}',
                            style: const TextStyle(
                              color: AppColors.action,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
