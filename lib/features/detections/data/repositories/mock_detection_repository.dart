import 'dart:async';
import 'dart:math';

import '../models/detection.dart';
import '../models/detection_status.dart';
import '../models/occurrence.dart';
import 'detection_repository.dart';

const _cameraLocations = [
  'Entrada principal',
  'Corredor 3 - Bebidas',
  'Caixa 2',
  'Corredor 1 - Higiene',
  'Fundos - Estoque',
  'Provador',
];

/// Implementação mockada: gera um histórico fixo de detecções e simula
/// alertas em tempo real chegando periodicamente (no software real isso
/// seria um evento de WebSocket vindo do computador da loja).
class MockDetectionRepository implements DetectionRepository {
  MockDetectionRepository({Duration alertInterval = const Duration(seconds: 35)})
      : _alertInterval = alertInterval;

  final Duration _alertInterval;
  final _random = Random();
  final _alertsController = StreamController<Detection>.broadcast();

  /// `null` enquanto não conectado — ver [startRealtime]/[stopRealtime].
  Timer? _timer;
  int _generatedCount = 0;

  @override
  Stream<Detection> get alertsStream => _alertsController.stream;

  @override
  void startRealtime() {
    // Idempotente: reconectar não deve empilhar timers duplicados.
    _timer ??= Timer.periodic(_alertInterval, (_) => _emitRandomAlert());
  }

  @override
  void stopRealtime() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<List<Detection>> fetchHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    return _seedDetections(now)..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
  }

  void _emitRandomAlert() {
    if (_alertsController.isClosed) return;
    _generatedCount++;
    final now = DateTime.now();
    _alertsController.add(Detection(
      id: 'live-$_generatedCount-${now.millisecondsSinceEpoch}',
      displayCode: 'Pessoa #T${100 + _generatedCount}',
      status: DetectionStatus.knownThief,
      detectedAt: now,
      cameraLocation: _cameraLocations[_random.nextInt(_cameraLocations.length)],
      occurrenceHistory: [
        Occurrence(
          id: 'occ-live-$_generatedCount-1',
          date: now.subtract(Duration(days: 5 + _random.nextInt(30))),
          cameraLocation: _cameraLocations[_random.nextInt(_cameraLocations.length)],
          description: 'Furto confirmado por revisão de imagens.',
        ),
      ],
    ));
  }

  List<Detection> _seedDetections(DateTime now) {
    return [
      Detection(
        id: 'p-a231',
        displayCode: 'Pessoa #A231',
        status: DetectionStatus.knownThief,
        detectedAt: now.subtract(const Duration(minutes: 12)),
        cameraLocation: 'Entrada principal',
        occurrenceHistory: [
          Occurrence(
            id: 'p-a231-1',
            date: now.subtract(const Duration(days: 40)),
            cameraLocation: 'Corredor 3 - Bebidas',
            description: 'Furto de duas garrafas de bebida.',
          ),
          Occurrence(
            id: 'p-a231-2',
            date: now.subtract(const Duration(days: 12)),
            cameraLocation: 'Caixa 2',
            description: 'Tentativa de saída sem pagamento, abordado pela equipe.',
          ),
        ],
      ),
      Detection(
        id: 'p-b104',
        displayCode: 'Pessoa #B104',
        status: DetectionStatus.suspect,
        detectedAt: now.subtract(const Duration(hours: 2)),
        cameraLocation: 'Corredor 1 - Higiene',
        occurrenceHistory: [
          Occurrence(
            id: 'p-b104-1',
            date: now.subtract(const Duration(days: 3)),
            cameraLocation: 'Provador',
            description: 'Permaneceu no provador por tempo prolongado sem compra.',
          ),
        ],
      ),
      Detection(
        id: 'p-c777',
        displayCode: 'Pessoa #C777',
        status: DetectionStatus.newPerson,
        detectedAt: now.subtract(const Duration(hours: 5)),
        cameraLocation: 'Entrada principal',
        occurrenceHistory: const [],
      ),
      Detection(
        id: 'p-d552',
        displayCode: 'Pessoa #D552',
        status: DetectionStatus.knownThief,
        detectedAt: now.subtract(const Duration(days: 1, hours: 3)),
        cameraLocation: 'Fundos - Estoque',
        occurrenceHistory: [
          Occurrence(
            id: 'p-d552-1',
            date: now.subtract(const Duration(days: 60)),
            cameraLocation: 'Fundos - Estoque',
            description: 'Furto de mercadoria na área de estoque.',
          ),
        ],
      ),
      Detection(
        id: 'p-e903',
        displayCode: 'Pessoa #E903',
        status: DetectionStatus.newPerson,
        detectedAt: now.subtract(const Duration(days: 1, hours: 6)),
        cameraLocation: 'Caixa 2',
        occurrenceHistory: const [],
      ),
      Detection(
        id: 'p-f118',
        displayCode: 'Pessoa #F118',
        status: DetectionStatus.suspect,
        detectedAt: now.subtract(const Duration(days: 2)),
        cameraLocation: 'Corredor 3 - Bebidas',
        occurrenceHistory: [
          Occurrence(
            id: 'p-f118-1',
            date: now.subtract(const Duration(days: 20)),
            cameraLocation: 'Corredor 3 - Bebidas',
            description: 'Comportamento suspeito perto de itens de alto valor.',
          ),
        ],
      ),
      Detection(
        id: 'p-g340',
        displayCode: 'Pessoa #G340',
        status: DetectionStatus.knownThief,
        detectedAt: now.subtract(const Duration(days: 3, hours: 4)),
        cameraLocation: 'Entrada principal',
        occurrenceHistory: [
          Occurrence(
            id: 'p-g340-1',
            date: now.subtract(const Duration(days: 90)),
            cameraLocation: 'Entrada principal',
            description: 'Furto de itens de vestuário.',
          ),
          Occurrence(
            id: 'p-g340-2',
            date: now.subtract(const Duration(days: 45)),
            cameraLocation: 'Provador',
            description: 'Reincidência: itens escondidos em bolsa própria.',
          ),
          Occurrence(
            id: 'p-g340-3',
            date: now.subtract(const Duration(days: 5)),
            cameraLocation: 'Caixa 2',
            description: 'Abordado antes de sair da loja, mercadoria recuperada.',
          ),
        ],
      ),
      Detection(
        id: 'p-h221',
        displayCode: 'Pessoa #H221',
        status: DetectionStatus.newPerson,
        detectedAt: now.subtract(const Duration(days: 4)),
        cameraLocation: 'Corredor 1 - Higiene',
        occurrenceHistory: const [],
      ),
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertsController.close();
  }
}
