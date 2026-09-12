part of 'alert_cubit.dart';

final class AlertState extends Equatable {
  const AlertState({this.queue = const <Detection>[]});

  /// Fila de alertas de "ladrão conhecido" ainda não confirmados pelo
  /// segurança — o primeiro é o que está tocando/vibrando agora.
  final List<Detection> queue;

  Detection? get current => queue.isEmpty ? null : queue.first;
  bool get hasPending => queue.isNotEmpty;

  AlertState copyWith({List<Detection>? queue}) =>
      AlertState(queue: queue ?? this.queue);

  @override
  List<Object?> get props => [queue];
}
