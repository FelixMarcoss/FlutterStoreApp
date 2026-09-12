import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/detections_cubit.dart';
import '../data/models/detection_status.dart';
import 'widgets/detection_card.dart';

class DetectionsListScreen extends StatelessWidget {
  const DetectionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detecções'),
        actions: const [_ConnectionStatusAction()],
      ),
      body: Column(
        children: [
          const _StatusFilterBar(),
          const Expanded(child: _DetectionsListBody()),
        ],
      ),
    );
  }
}

class _ConnectionStatusAction extends StatelessWidget {
  const _ConnectionStatusAction();

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<SessionCubit>().state;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.wifi_tethering_rounded, color: AppColors.success),
      tooltip: connection != null ? 'Conectado a ${connection.address}' : 'Conexão',
      onSelected: (value) {
        if (value == 'disconnect') {
          context.read<SessionCubit>().disconnect();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            connection != null ? 'Conectado a ${connection.address}' : 'Desconectado',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'disconnect',
          child: Text('Desconectar'),
        ),
      ],
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar();

  @override
  Widget build(BuildContext context) {
    final filter = context.select((DetectionsCubit c) => c.state.filter);

    Widget chip(String label, DetectionStatus? value) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => context.read<DetectionsCubit>().setFilter(value),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Todos', null),
            chip('Ladrões conhecidos', DetectionStatus.knownThief),
            chip('Suspeitos', DetectionStatus.suspect),
            chip('Novos', DetectionStatus.newPerson),
          ],
        ),
      ),
    );
  }
}

class _DetectionsListBody extends StatelessWidget {
  const _DetectionsListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetectionsCubit, DetectionsState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.filteredDetections != curr.filteredDetections,
      builder: (context, state) {
        if (state.status == DetectionsStatus.loading && state.detections.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == DetectionsStatus.failure && state.detections.isEmpty) {
          return _ErrorState(message: state.errorMessage ?? 'Erro ao carregar.');
        }

        final items = state.filteredDetections;
        if (items.isEmpty) {
          return const Center(
            child: Text('Nenhuma detecção encontrada.', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<DetectionsCubit>().refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final detection = items[index];
              return DetectionCard(
                detection: detection,
                onTap: () => context.push('/detection/${detection.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<DetectionsCubit>().fetchInitial(),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
