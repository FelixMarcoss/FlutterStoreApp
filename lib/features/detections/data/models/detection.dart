import 'package:equatable/equatable.dart';

import 'detection_status.dart';
import 'occurrence.dart';

/// Uma pessoa detectada pela câmera e identificada pela IA do software
/// principal. Fotos reais são carregadas sob demanda pelo repositório.
final class Detection extends Equatable {
  const Detection({
    required this.id,
    required this.displayCode,
    required this.status,
    required this.detectedAt,
    required this.cameraLocation,
    required this.occurrenceHistory,
    this.cameraId,
    this.photoUrl,
    this.photoBytes,
    this.registeredPhotoBytes,
    this.notes,
    this.confidence,
    this.isSilent = false,
    this.boundingBox,
    this.originStoreName,
    this.registeredBy,
    this.createdAt,
    this.occurrenceNumber,
    this.acknowledgedAt,
  });

  final String id;

  /// Nome cadastrado na própria rede ou o identificador sintético
  /// `Ocorrência #numero` quando o evento vem da Super Cloud.
  final String displayCode;
  final DetectionStatus status;
  final DateTime detectedAt;
  final String cameraLocation;
  final String? cameraId;
  final List<Occurrence> occurrenceHistory;
  final String? photoUrl;
  final List<int>? photoBytes;
  final List<int>? registeredPhotoBytes;
  final String? notes;
  final double? confidence;
  final bool isSilent;
  final List<int>? boundingBox;
  final String? originStoreName;
  final String? registeredBy;
  final DateTime? createdAt;
  final int? occurrenceNumber;

  /// Ocorrencias da Super Cloud usam um risco medio apenas como valor de
  /// compatibilidade do protocolo. Ele nao representa a classificacao real.
  bool get isSuperCloud => occurrenceNumber != null;
  String get riskLabel => isSuperCloud ? 'Risco não informado' : status.label;

  /// Melhor local disponivel para a interface. Servidores 1.7.8 nao enviam
  /// mais camera_name; nesse caso a loja de origem ocupa esse espaco visual.
  String? get availableLocation {
    final store = originStoreName?.trim();
    if (store != null && store.isNotEmpty) return store;
    final camera = cameraLocation.trim();
    return camera.isEmpty ? null : camera;
  }

  /// Momento em que o segurança confirmou ("OK") o alerta. Estado local do
  /// aparelho — o app é somente leitura e não grava isso no banco principal.
  final DateTime? acknowledgedAt;

  int get occurrenceCount => occurrenceHistory.length;
  bool get needsAcknowledgement =>
      status == DetectionStatus.knownThief && acknowledgedAt == null;

  Detection copyWith({DateTime? acknowledgedAt, List<int>? photoBytes}) =>
      Detection(
        id: id,
        displayCode: displayCode,
        status: status,
        detectedAt: detectedAt,
        cameraLocation: cameraLocation,
        cameraId: cameraId,
        occurrenceHistory: occurrenceHistory,
        photoUrl: photoUrl,
        photoBytes: photoBytes ?? this.photoBytes,
        registeredPhotoBytes: registeredPhotoBytes,
        notes: notes,
        confidence: confidence,
        isSilent: isSilent,
        boundingBox: boundingBox,
        originStoreName: originStoreName,
        registeredBy: registeredBy,
        createdAt: createdAt,
        occurrenceNumber: occurrenceNumber,
        acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      );

  @override
  List<Object?> get props => [
    id,
    displayCode,
    status,
    detectedAt,
    cameraLocation,
    cameraId,
    occurrenceHistory,
    photoUrl,
    photoBytes,
    registeredPhotoBytes,
    notes,
    confidence,
    isSilent,
    boundingBox,
    originStoreName,
    registeredBy,
    createdAt,
    occurrenceNumber,
    acknowledgedAt,
  ];
}
