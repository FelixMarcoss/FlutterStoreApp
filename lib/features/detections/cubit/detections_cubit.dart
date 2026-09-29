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

  void setFilter(DetectionStatus? filter) {
    emit(state.copyWith(filter: filter, clearFilter: filter == null));
  }

  Future<void> loadRecent() async {
    List<Detection> recent;
    try {
      recent = await _repository.loadRecent();
    } catch (_) {
      return;
    }
    if (isClosed || recent.isEmpty) return;
    final byId = <String, Detection>{
      for (final item in state.detections) item.id: item,
    };
    for (final item in recent) {
      final local = byId[item.id];
      // O payload mais recente substitui integralmente os metadados remotos.
      // Isso é especialmente importante para Super Cloud: notes, autor e
      // data de cadastro precisam permanecer limpos, sem merge com alertas
      // antigos. Apenas a confirmação local do fiscal é preservada.
      byId[item.id] = local == null
          ? item
          : item.copyWith(acknowledgedAt: local.acknowledgedAt);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    emit(state.copyWith(detections: merged.take(100).toList()));
  }

  void _onAlertReceived(Detection detection) {
    if (isClosed) return;
    final updated = [
      detection,
      ...state.detections.where((d) => d.id != detection.id),
    ].take(100).toList();
    emit(state.copyWith(detections: updated));
  }

  /// Marca localmente que o segurança confirmou ter visto o alerta. Isto é
  /// um estado só do aparelho — nunca é gravado no banco do software
  /// principal, já que o app é somente leitura.
  void acknowledge(String detectionId) {
    final updated = state.detections
        .map(
          (d) => d.id == detectionId
              ? d.copyWith(acknowledgedAt: DateTime.now())
              : d,
        )
        .toList();
    emit(state.copyWith(detections: updated));
  }

  @override
  Future<void> close() {
    _alertSub.cancel();
    return super.close();
  }
}
