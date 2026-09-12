import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../detections/view/widgets/person_avatar.dart';
import '../cubit/alert_cubit.dart';

/// Tela cheia, não descartável (sem botão de voltar/gesto), exibida sempre
/// que alguém com histórico de furto é detectado. Só fecha quando o
/// segurança confirma "OK, verifiquei" — o que também para a vibração.
class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<AlertCubit, AlertState>(
        listenWhen: (prev, curr) => prev.current != null && curr.current == null,
        listener: (context, state) {
          if (context.canPop()) context.pop();
        },
        builder: (context, state) {
          final detection = state.current;
          if (detection == null) {
            return const Scaffold(
              backgroundColor: AppColors.danger,
              body: SizedBox.shrink(),
            );
          }

          final timeFormat = DateFormat('HH:mm');

          return Scaffold(
            backgroundColor: AppColors.danger,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 72),
                    const SizedBox(height: 16),
                    const Text(
                      'PESSOA COM HISTÓRICO DE FURTO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          PersonAvatar(detection: detection, radius: 44),
                          const SizedBox(height: 12),
                          Text(
                            detection.displayCode,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${detection.cameraLocation} · ${timeFormat.format(detection.detectedAt)}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${detection.occurrenceCount} ocorrência(s) anterior(es) registrada(s)',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          if (state.queue.length > 1) ...[
                            const SizedBox(height: 8),
                            Text(
                              '+${state.queue.length - 1} outro(s) alerta(s) na fila',
                              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('alert_ok_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        onPressed: () => context.read<AlertCubit>().acknowledgeCurrent(),
                        child: const Text(
                          'OK, VERIFIQUEI',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
