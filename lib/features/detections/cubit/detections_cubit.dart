import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/detection.dart';
import '../data/models/detection_status.dart';
import '../data/repositories/detection_repository.dart';

part 'detections_state.dart';

class DetectionsCubit extends Cubit<DetectionsState> {
  DetectionsCubit({required DetectionRepository detectionRepository})
      : _repository = detectionRepository,
        super(const DetectionsState()) {
    _alertSub = _repository.alertsStream.listen(_onAlertReceived);
  }

  final DetectionRepository _repository;
  late final StreamSubscription<Detection> _alertSub;

  Future<void> fetchInitial() async {
    emit(state.copyWith(status: DetectionsStatus.loading));
    await _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    try {
      final detections = await _repository.fetchHistory();
      if (isClosed) return;
      emit(state.copyWith(
        status: DetectionsStatus.success,
        detections: detections,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        status: DetectionsStatus.failure,
        errorMessage: 'Não foi possível carregar as detecções.',
      ));
    }
  }

  void setFilter(DetectionStatus? filter) {
    emit(state.copyWith(filter: filter, clearFilter: filter == null));
  }

  void _onAlertReceived(Detection detection) {
    if (isClosed) return;
    final updated = [
      detection,
      ...state.detections.where((d) => d.id != detection.id),
    ];
    emit(state.copyWith(detections: updated));
  }

  /// Marca localmente que o segurança confirmou ter visto o alerta. Isto é
  /// um estado só do aparelho — nunca é gravado no banco do software
  /// principal, já que o app é somente leitura.
  void acknowledge(String detectionId) {
    final updated = state.detections
        .map((d) => d.id == detectionId ? d.copyWith(acknowledgedAt: DateTime.now()) : d)
        .toList();
    emit(state.copyWith(detections: updated));
  }

  @override
  Future<void> close() {
    _alertSub.cancel();
    return super.close();
  }
}
