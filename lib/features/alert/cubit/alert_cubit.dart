import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../detections/cubit/detections_cubit.dart';
import '../../detections/data/models/detection.dart';
import '../../detections/data/repositories/detection_repository.dart';
import '../../settings/cubit/alert_preferences_cubit.dart';
import '../../settings/data/models/alert_tone.dart';
import '../alert_service.dart';

part 'alert_state.dart';

/// Observa a stream de detecções em tempo real e dispara vibração/notificação
/// para todos os níveis de risco. Apenas eventos marcados como silenciosos pelo
/// servidor (histórico/cooldown) não rearmam o alarme.
class AlertCubit extends Cubit<AlertState> {
  AlertCubit({
    required DetectionRepository detectionRepository,
    required DetectionsCubit detectionsCubit,
    AlertPreferencesCubit? preferencesCubit,
    AlertService? alertService,
    Stream<void>? acknowledgementRequests,
  }) : _detectionsCubit = detectionsCubit,
       _preferencesCubit = preferencesCubit,
       _alertService = alertService ?? AlertService.instance,
       super(const AlertState()) {
    _sub = detectionRepository.alertsStream.listen(
      (detection) => unawaited(_onDetection(detection)),
    );
    final requests =
        acknowledgementRequests ??
        (alertService == null
            ? _alertService.acknowledgementRequests
            : const Stream<void>.empty());
    _acknowledgementSub = requests.listen(
      (_) => unawaited(acknowledgeCurrent()),
    );
  }

  final DetectionsCubit _detectionsCubit;
  final AlertPreferencesCubit? _preferencesCubit;
  final AlertService _alertService;
  late final StreamSubscription<Detection> _sub;
  late final StreamSubscription<void> _acknowledgementSub;
  bool _isAcknowledging = false;

  Future<void> _onDetection(Detection detection) async {
    if (isClosed || detection.isSilent) {
      return;
    }
    final wasEmpty = state.queue.isEmpty;
    emit(
      state.copyWith(
        queue: [...state.queue, detection],
        isSilenced: wasEmpty ? false : state.isSilenced,
      ),
    );
    if (wasEmpty) {
      await _alertService.startAlert(
        detection,
        tone: _preferencesCubit?.state.tone ?? AlertTone.electronicOne,
        volume: _preferencesCubit?.state.volume ?? 0.8,
      );
    }
  }

  /// Interrompe som, vibração e notificação sem consumir o alerta atual.
  /// O fiscal ainda precisa tocar em "Ciente / atender" para avançar a fila.
  Future<void> silenceCurrent() async {
    if (state.current == null || state.isSilenced) return;
    await _alertService.stopAlert();
    if (isClosed) return;
    emit(state.copyWith(isSilenced: true));
  }

  /// Chamado quando o segurança toca em "OK, verifiquei".
  Future<void> acknowledgeCurrent() async {
    if (_isAcknowledging) return;
    final current = state.current;
    if (current == null) return;
    _isAcknowledging = true;

    try {
      await _alertService.stopAlert();
      if (isClosed) return;
      _detectionsCubit.acknowledge(current.id);

      final remaining = state.queue.skip(1).toList();
      emit(state.copyWith(queue: remaining, isSilenced: false));

      if (remaining.isNotEmpty) {
        await _alertService.startAlert(
          remaining.first,
          tone: _preferencesCubit?.state.tone ?? AlertTone.electronicOne,
          volume: _preferencesCubit?.state.volume ?? 0.8,
        );
      }
    } finally {
      _isAcknowledging = false;
    }
  }

  /// Limpa a fila de alertas pendentes e garante que vibração/notificação
  /// parem — chamado ao desconectar, já que o app não deve continuar
  /// vibrando/exibindo alertas de uma sessão que não existe mais.
  Future<void> reset() async {
    if (state.queue.isEmpty) return;
    await _alertService.stopAlert();
    if (!isClosed && state.queue.isNotEmpty) emit(const AlertState());
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _acknowledgementSub.cancel();
    return super.close();
  }
}
