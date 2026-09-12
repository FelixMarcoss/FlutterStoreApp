import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../detections/cubit/detections_cubit.dart';
import '../../detections/data/models/detection.dart';
import '../../detections/data/models/detection_status.dart';
import '../../detections/data/repositories/detection_repository.dart';
import '../alert_service.dart';

part 'alert_state.dart';

/// Observa a stream de detecções em tempo real e, sempre que chega alguém
/// com status "ladrão conhecido", dispara o alerta (vibração + notificação
/// via [AlertService]) e mantém uma fila até o segurança confirmar cada um.
class AlertCubit extends Cubit<AlertState> {
  AlertCubit({
    required DetectionRepository detectionRepository,
    required DetectionsCubit detectionsCubit,
    AlertService? alertService,
  })  : _detectionsCubit = detectionsCubit,
        _alertService = alertService ?? AlertService.instance,
        super(const AlertState()) {
    _sub = detectionRepository.alertsStream.listen(_onDetection);
  }

  final DetectionsCubit _detectionsCubit;
  final AlertService _alertService;
  late final StreamSubscription<Detection> _sub;

  void _onDetection(Detection detection) {
    if (isClosed || detection.status != DetectionStatus.knownThief) return;
    final wasEmpty = state.queue.isEmpty;
    emit(state.copyWith(queue: [...state.queue, detection]));
    if (wasEmpty) {
      _alertService.startAlert(detection);
    }
  }

  /// Chamado quando o segurança toca em "OK, verifiquei".
  void acknowledgeCurrent() {
    final current = state.current;
    if (current == null) return;

    _alertService.stopAlert();
    _detectionsCubit.acknowledge(current.id);

    final remaining = state.queue.skip(1).toList();
    emit(state.copyWith(queue: remaining));

    if (remaining.isNotEmpty) {
      _alertService.startAlert(remaining.first);
    }
  }

  /// Limpa a fila de alertas pendentes e garante que vibração/notificação
  /// parem — chamado ao desconectar, já que o app não deve continuar
  /// vibrando/exibindo alertas de uma sessão que não existe mais.
  void reset() {
    if (state.queue.isEmpty) return;
    _alertService.stopAlert();
    emit(const AlertState());
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
