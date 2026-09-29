import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/facetrack_app_bar.dart';
import '../../../core/widgets/facetrack_navigation_bar.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/detections_cubit.dart';
import '../data/models/detection_status.dart';
import '../data/repositories/detection_repository.dart';
import 'widgets/detection_card.dart';

class DetectionsListScreen extends StatelessWidget {
  const DetectionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<SessionCubit>().state;
    return Scaffold(
      appBar: FaceTrackAppBar(
        centerBrand: true,
        subtitle: connection == null
            ? 'SERVIDOR NÃO CONECTADO'
            : connection.address.toUpperCase(),
        actions: const [_ConnectionStatusAction(), SizedBox(width: 6)],
      ),
      body: const _MonitoringBody(),
      bottomNavigationBar: const FaceTrackNavigationBar(currentIndex: 0),
    );
  }
}

class _ConnectionStatusAction extends StatelessWidget {
  const _ConnectionStatusAction();

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<SessionCubit>().state;
    final repository = context.read<DetectionRepository>();
    if (repository case final RealtimeConnectionReporter reporter) {
      return StreamBuilder<bool>(
        stream: reporter.realtimeConnectionChanges,
        initialData: reporter.isRealtimeConnected,
        builder: (context, snapshot) => _ConnectionMenu(
          address: connection?.address,
          realtimeConnected: snapshot.data ?? false,
        ),
      );
    }
    return _ConnectionMenu(
      address: connection?.address,
      realtimeConnected: connection != null,
    );
  }
}

class _ConnectionMenu extends StatelessWidget {
  const _ConnectionMenu({
    required this.address,
    required this.realtimeConnected,
  });

  final String? address;
  final bool realtimeConnected;

  @override
  Widget build(BuildContext context) {
    final label = realtimeConnected
        ? 'Tempo real conectado a $address'
        : 'Reconectando ao canal em tempo real';
    return PopupMenuButton<String>(
      tooltip: label,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: realtimeConnected ? AppColors.action : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Text(
              realtimeConnected ? 'AO VIVO' : 'RECONECTANDO',
              style: TextStyle(
                color: realtimeConnected ? AppColors.action : AppColors.warning,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == 'disconnect') {
          context.read<SessionCubit>().disconnect();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'disconnect',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 19),
              SizedBox(width: 10),
              Text('Desconectar'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonitoringBody extends StatelessWidget {
  const _MonitoringBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetectionsCubit, DetectionsState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: context.read<DetectionsCubit>().loadRecent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ocorrências biométricas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.circle, color: AppColors.action, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'SINCRONIZADO',
                        style: TextStyle(
                          color: AppColors.action,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 0, 12),
                sliver: SliverToBoxAdapter(child: _StatusFilterBar()),
              ),
              if (state.filteredDetections.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyMonitoringState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: state.filteredDetections.length,
                    itemBuilder: (context, index) {
                      final detection = state.filteredDetections[index];
                      return DetectionCard(
                        detection: detection,
                        onTap: () => context.push('/detection/${detection.id}'),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar();

  @override
  Widget build(BuildContext context) {
    final filter = context.select(
      (DetectionsCubit cubit) => cubit.state.filter,
    );

    Widget chip(String label, DetectionStatus? value) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
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
          onSelected: (_) => context.read<DetectionsCubit>().setFilter(value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Todos', null),
          chip('Alto risco', DetectionStatus.knownThief),
          chip('Atenção', DetectionStatus.suspect),
          chip('Informativo', DetectionStatus.newPerson),
        ],
      ),
    );
  }
}

class _EmptyMonitoringState extends StatelessWidget {
  const _EmptyMonitoringState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar_rounded, color: AppColors.action, size: 52),
            const SizedBox(height: 14),
            const Text(
              'Monitoramento ativo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Aguardando uma nova detecção em tempo real.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
