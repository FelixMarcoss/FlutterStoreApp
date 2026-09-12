import 'package:equatable/equatable.dart';

import 'detection_status.dart';
import 'occurrence.dart';

/// Uma pessoa detectada pela câmera e identificada pela IA do software
/// principal. Não existe uma foto real armazenada aqui: por privacidade,
/// só vetores faciais chegam ao Supabase — a foto (quando o software
/// principal expuser uma API local para isso) viria como bytes/URL em
/// [photoBytes], hoje sempre nulo no mock.
final class Detection extends Equatable {
  const Detection({
    required this.id,
    required this.displayCode,
    required this.status,
    required this.detectedAt,
    required this.cameraLocation,
    required this.occurrenceHistory,
    this.photoBytes,
    this.acknowledgedAt,
  });

  final String id;

  /// Código de exibição, ex: "Pessoa #A231" — nunca um nome real vindo do banco.
  final String displayCode;
  final DetectionStatus status;
  final DateTime detectedAt;
  final String cameraLocation;
  final List<Occurrence> occurrenceHistory;
  final List<int>? photoBytes;

  /// Momento em que o segurança confirmou ("OK") o alerta. Estado local do
  /// aparelho — o app é somente leitura e não grava isso no banco principal.
  final DateTime? acknowledgedAt;

  int get occurrenceCount => occurrenceHistory.length;
  bool get needsAcknowledgement =>
      status == DetectionStatus.knownThief && acknowledgedAt == null;

  Detection copyWith({DateTime? acknowledgedAt}) => Detection(
        id: id,
        displayCode: displayCode,
        status: status,
        detectedAt: detectedAt,
        cameraLocation: cameraLocation,
        occurrenceHistory: occurrenceHistory,
        photoBytes: photoBytes,
        acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      );

  @override
  List<Object?> get props => [
        id,
        displayCode,
        status,
        detectedAt,
        cameraLocation,
        occurrenceHistory,
        photoBytes,
        acknowledgedAt,
      ];
}
