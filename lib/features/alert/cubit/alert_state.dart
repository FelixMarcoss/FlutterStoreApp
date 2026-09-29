part of 'alert_cubit.dart';

final class AlertState extends Equatable {
  const AlertState({this.queue = const <Detection>[], this.isSilenced = false});

  /// Fila de alertas habilitados pelo fiscal e ainda não confirmados — o
  /// primeiro é o que está tocando/vibrando agora.
  final List<Detection> queue;
  final bool isSilenced;

  Detection? get current => queue.isEmpty ? null : queue.first;
  bool get hasPending => queue.isNotEmpty;

  AlertState copyWith({List<Detection>? queue, bool? isSilenced}) => AlertState(
    queue: queue ?? this.queue,
    isSilenced: isSilenced ?? this.isSilenced,
  );

  @override
  List<Object?> get props => [queue, isSilenced];
}
