import 'package:equatable/equatable.dart';

/// Um registro histórico de ocorrência associado a uma pessoa detectada.
final class Occurrence extends Equatable {
  const Occurrence({
    required this.id,
    required this.date,
    required this.cameraLocation,
    required this.description,
  });

  final String id;
  final DateTime date;
  final String cameraLocation;
  final String description;

  @override
  List<Object?> get props => [id, date, cameraLocation, description];
}
