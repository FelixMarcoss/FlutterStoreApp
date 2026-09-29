import '../models/detection.dart';

/// Capacidade opcional para a interface exibir o estado do canal em tempo real.
abstract interface class RealtimeConnectionReporter {
  bool get isRealtimeConnected;
  Stream<bool> get realtimeConnectionChanges;
  Stream<int> get terminalCloseCodes;
}

class DetectionRepositoryException implements Exception {
  const DetectionRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Seam entre o app e o software principal para dados de detecção.
/// A implementação real (fase 2) troca isto por chamadas REST (histórico)
/// e um WebSocket (`alertsStream`) para `ws://ip:porta`, mantendo a mesma
/// interface — nada em [DetectionsCubit] muda quando o back-end real chegar.
abstract class DetectionRepository {
  /// Emite uma nova [Detection] sempre que o software principal identifica
  /// alguém em tempo real. Só as de [DetectionStatus.knownThief] devem
  /// disparar o alerta com vibração no app.
  Stream<Detection> get alertsStream;

  /// Busca ocorrências anteriores sem publicá-las em [alertsStream]. Assim,
  /// sincronizar o histórico nunca dispara som ou vibração.
  Future<List<Detection>> loadRecent({int limit = 20});

  /// Carrega a foto autenticada sob demanda. Retorna `null` quando ausente.
  Future<List<int>?> fetchPhoto(Detection detection);

  /// Inicia a entrega de eventos em tempo real — chamado assim que a sessão
  /// conecta. Na implementação real isso abre o WebSocket com o software
  /// principal; no mock, começa a simular alertas periódicos.
  ///
  /// Importante: sem isto, alertas (inclusive os de alto risco, que
  /// abrem a tela cheia de alerta) poderiam chegar antes do login ou depois
  /// de desconectar — quando não há de fato nenhuma conexão com um sistema
  /// principal para tê-los gerado.
  void startRealtime();

  /// Pausa a entrega de eventos em tempo real — chamado ao desconectar. Na
  /// implementação real isso fecha o WebSocket.
  void stopRealtime();

  void dispose();
}
