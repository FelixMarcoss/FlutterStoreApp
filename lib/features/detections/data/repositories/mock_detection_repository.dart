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

/// Simula exclusivamente eventos novos, sem fornecer histórico anterior.
class MockDetectionRepository implements DetectionRepository {
  MockDetectionRepository({
    Duration alertInterval = const Duration(seconds: 35),
  }) : _alertInterval = alertInterval;

  final Duration _alertInterval;
  final _random = Random();
  final _alertsController = StreamController<Detection>.broadcast();
  Timer? _timer;
  int _generatedCount = 0;

  @override
  Stream<Detection> get alertsStream => _alertsController.stream;

  @override
  Future<List<Detection>> loadRecent({int limit = 20}) async => const [];

  @override
  Future<List<int>?> fetchPhoto(Detection detection) async =>
      detection.photoBytes;

  @override
  void startRealtime() {
    _timer ??= Timer.periodic(_alertInterval, (_) => _emitRandomAlert());
  }

  @override
  void stopRealtime() {
    _timer?.cancel();
    _timer = null;
  }

  void _emitRandomAlert() {
    if (_alertsController.isClosed) return;
    _generatedCount++;
    final now = DateTime.now();
    _alertsController.add(
      Detection(
        id: 'live-$_generatedCount-${now.millisecondsSinceEpoch}',
        displayCode: 'Pessoa #T${100 + _generatedCount}',
        status: DetectionStatus.knownThief,
        detectedAt: now,
        cameraLocation:
            _cameraLocations[_random.nextInt(_cameraLocations.length)],
        occurrenceHistory: [
          Occurrence(
            id: 'occ-live-$_generatedCount-1',
            date: now.subtract(Duration(days: 5 + _random.nextInt(30))),
            cameraLocation:
                _cameraLocations[_random.nextInt(_cameraLocations.length)],
            description: 'Ocorrência registrada anteriormente.',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertsController.close();
  }
}
