import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/network/api_session.dart';
import '../models/detection.dart';
import '../models/detection_status.dart';
import 'detection_repository.dart';

class RemoteDetectionRepository
    implements DetectionRepository, RealtimeConnectionReporter {
  RemoteDetectionRepository({required ApiSession session}) : _session = session;

  final ApiSession _session;
  final _alertsController = StreamController<Detection>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _terminalCloseController = StreamController<int>.broadcast();
  final _seenEventIds = <String>{};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _retryTimer;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _welcomeTimeoutTimer;
  bool _shouldRun = false;
  bool _connecting = false;
  int _generation = 0;
  int _retryAttempt = 0;
  bool _isRealtimeConnected = false;

  static const _requestTimeout = Duration(seconds: 8);
  static const _maxFrameBytes = 128 * 1024;
  static const _maxPhotoBytes = 30 * 1024;

  @override
  Stream<Detection> get alertsStream => _alertsController.stream;

  @override
  bool get isRealtimeConnected => _isRealtimeConnected;

  @override
  Stream<bool> get realtimeConnectionChanges => _connectionController.stream;

  @override
  Stream<int> get terminalCloseCodes => _terminalCloseController.stream;

  void _setRealtimeConnected(bool value) {
    if (_isRealtimeConnected == value) return;
    _isRealtimeConnected = value;
    if (!_connectionController.isClosed) _connectionController.add(value);
  }

  @override
  Future<List<int>?> fetchPhoto(Detection detection) async =>
      detection.photoBytes;

  @override
  Future<List<Detection>> loadRecent({int limit = 20}) async {
    if (!_session.isAuthenticated) return const [];
    final safeLimit = limit.clamp(1, 50);
    try {
      final response = await _session.client
          .get(
            _session.endpoint(
              '/api/mobile/events/recent',
              queryParameters: {'limit': '$safeLimit'},
            ),
            headers: _session.authorizationHeaders,
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (!_terminalCloseController.isClosed) {
          _terminalCloseController.add(4001);
        }
        return const [];
      }
      if (response.statusCode != 200) {
        throw DetectionRepositoryException(
          apiErrorMessage(response, 'Não foi possível carregar o histórico.'),
        );
      }
      final body = decodeJsonObject(response);
      final events = body['events'];
      if (events is! List) {
        throw const FormatException('Lista de eventos ausente.');
      }
      final parsed = <Detection>[];
      for (final raw in events) {
        try {
          final event = _object(raw, 'event');
          final detection = _parseAlert(event, forceSilent: true);
          _rememberEvent(detection.id);
          parsed.add(detection);
        } catch (_) {
          // Um item inválido não impede a recuperação dos demais.
        }
      }
      return parsed;
    } on DetectionRepositoryException {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  @override
  void startRealtime() {
    if (_shouldRun || !_session.isAuthenticated) return;
    _shouldRun = true;
    _generation++;
    unawaited(_connect(_generation));
  }

  Future<void> _connect(int generation) async {
    if (!_shouldRun || generation != _generation || _connecting) return;
    _connecting = true;
    try {
      final socketUri = _session
          .endpoint('/ws/mobile')
          .replace(scheme: _session.baseUri.scheme == 'https' ? 'wss' : 'ws');
      final channel = IOWebSocketChannel.connect(
        socketUri,
        headers: {'Authorization': 'Bearer ${_session.accessToken}'},
        pingInterval: null,
        customClient: _session.webSocketClient,
      );
      await channel.ready.timeout(_requestTimeout);

      if (!_shouldRun || generation != _generation) {
        await channel.sink.close(ws_status.goingAway);
        return;
      }

      _channel = channel;
      _welcomeTimeoutTimer?.cancel();
      _welcomeTimeoutTimer = Timer(const Duration(seconds: 5), () {
        if (_shouldRun && generation == _generation) {
          unawaited(channel.sink.close(ws_status.goingAway));
        }
      });
      _socketSubscription = channel.stream.listen(
        (message) => _onSocketMessage(message, generation),
        onError: (_) => _handleSocketClosed(generation, channel),
        onDone: () => _handleSocketClosed(generation, channel),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect(generation);
    } finally {
      _connecting = false;
    }
  }

  void _onSocketMessage(dynamic rawMessage, int generation) {
    if (!_shouldRun || generation != _generation) return;
    if (rawMessage == 'pong') {
      _pongTimeoutTimer?.cancel();
      return;
    }
    if (rawMessage is! String ||
        utf8.encode(rawMessage).length > _maxFrameBytes) {
      return;
    }
    try {
      final data = _object(jsonDecode(rawMessage), 'message');
      final type = data['type'];
      if (type == 'CONNECTION_ESTABLISHED') {
        _welcomeTimeoutTimer?.cancel();
        _retryAttempt = 0;
        _setRealtimeConnected(true);
        _startHeartbeat(generation);
        return;
      }
      if (type != 'FACE_RECOGNITION_ALERT') return;
      final detection = _parseAlert(data);
      if (_seenEventIds.contains(detection.id)) return;
      _rememberEvent(detection.id);
      _alertsController.add(detection);
    } catch (_) {
      // Frames fora do contrato são descartados sem derrubar todo o canal.
    }
  }

  Detection _parseAlert(Map<String, dynamic> json, {bool forceSilent = false}) {
    final eventId = _requiredString(json, 'event_id');
    final timestamp = DateTime.tryParse(_requiredString(json, 'timestamp'));
    if (timestamp == null) throw const FormatException('timestamp inválido.');
    final confidence = json['confidence'];
    if (confidence is! num || confidence < 0 || confidence > 1) {
      throw const FormatException('confidence inválido.');
    }
    final isSilent = json['is_silent'];
    if (isSilent is! bool) throw const FormatException('is_silent inválido.');

    final person = _object(json['person'], 'person');
    final personId = _optionalInt(person['id']);
    if (personId == null || personId <= 0) {
      throw const FormatException('person.id inválido.');
    }
    final status = switch (_requiredString(person, 'risk_level')) {
      'high' => DetectionStatus.knownThief,
      'medium' => DetectionStatus.suspect,
      'low' => DetectionStatus.newPerson,
      final value => throw FormatException('risk_level inválido: $value.'),
    };

    final detection = _object(json['detection'], 'detection');
    final occurrenceRaw = person['occurrence_number'];
    final occurrenceNumber = _optionalInt(occurrenceRaw);
    if (occurrenceRaw != null &&
        occurrenceRaw != '' &&
        (occurrenceNumber == null || occurrenceNumber <= 0)) {
      throw const FormatException('occurrence_number inválido.');
    }
    final isSuperCloud = occurrenceNumber != null;
    final createdAtText = isSuperCloud
        ? null
        : _optionalString(person['created_at']);
    final createdAt = createdAtText == null || createdAtText.trim().isEmpty
        ? null
        : DateTime.tryParse(createdAtText)?.toLocal();

    return Detection(
      id: eventId,
      displayCode: _requiredString(person, 'name'),
      status: status,
      detectedAt: timestamp.toLocal(),
      cameraId: null,
      // Servidores anteriores a 1.7.8 ainda podem enviar camera_name. No
      // contrato novo ele foi removido, portanto a ausência é válida.
      cameraLocation: _optionalString(json['camera_name'])?.trim() ?? '',
      photoBytes: _decodePhoto(detection['captured_face_b64']),
      registeredPhotoBytes: _decodePhoto(person['registered_photo_b64']),
      // Metadados privados nunca atravessam uma ocorrência da Super Cloud,
      // mesmo se um servidor defeituoso tentar incluí-los no payload.
      notes: isSuperCloud ? null : _optionalString(person['notes']),
      confidence: confidence.toDouble(),
      isSilent: forceSilent || isSilent,
      // bbox também saiu do protocolo. Se vier de um backend antigo, é
      // aceito como campo extra e deliberadamente ignorado.
      boundingBox: null,
      originStoreName: _optionalString(person['origin_store_name']),
      registeredBy: isSuperCloud
          ? null
          : _optionalString(person['registered_by']),
      createdAt: createdAt,
      occurrenceNumber: occurrenceNumber,
      occurrenceHistory: const [],
    );
  }

  List<int>? _decodePhoto(dynamic value) {
    if (value == null || value == '') return null;
    if (value is! String) throw const FormatException('Imagem inválida.');
    if (value.length > 45000) {
      throw const FormatException('Imagem Base64 excede 45.000 caracteres.');
    }
    final bytes = base64Decode(value);
    if (bytes.length > _maxPhotoBytes) {
      throw const FormatException('Imagem excede 30 KB.');
    }
    return bytes;
  }

  void _rememberEvent(String eventId) {
    _seenEventIds.add(eventId);
    if (_seenEventIds.length > 200) _seenEventIds.remove(_seenEventIds.first);
  }

  void _startHeartbeat(int generation) {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_shouldRun || generation != _generation || _channel == null) return;
      _channel!.sink.add('ping');
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(const Duration(seconds: 10), () {
        final channel = _channel;
        if (channel != null) {
          unawaited(channel.sink.close(ws_status.goingAway));
        }
      });
    });
  }

  void _handleSocketClosed(int generation, WebSocketChannel channel) {
    if (!identical(_channel, channel)) return;
    final closeCode = channel.closeCode;
    _channel = null;
    _socketSubscription = null;
    _cancelConnectionTimers();
    _setRealtimeConnected(false);
    if (closeCode == 4001 || closeCode == 4002 || closeCode == 4003) {
      _shouldRun = false;
      if (!_terminalCloseController.isClosed) {
        _terminalCloseController.add(closeCode!);
      }
      return;
    }
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (!_shouldRun || generation != _generation || _retryTimer != null) return;
    final exponent = min(_retryAttempt + 1, 5);
    final baseSeconds = min(30, pow(2, exponent).toInt());
    final delay = Duration(seconds: baseSeconds + Random().nextInt(4));
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_connect(generation));
    });
  }

  void _cancelConnectionTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _welcomeTimeoutTimer?.cancel();
    _welcomeTimeoutTimer = null;
  }

  @override
  void stopRealtime() {
    _shouldRun = false;
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _cancelConnectionTimers();
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    unawaited(_channel?.sink.close(ws_status.goingAway));
    _channel = null;
    _setRealtimeConnected(false);
    _connecting = false;
    _retryAttempt = 0;
    _seenEventIds.clear();
  }

  @override
  void dispose() {
    stopRealtime();
    unawaited(_alertsController.close());
    unawaited(_connectionController.close());
    unawaited(_terminalCloseController.close());
  }
}

Map<String, dynamic> _object(dynamic value, String name) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$name inválido.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key ausente ou inválido.');
}

String? _optionalString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  throw const FormatException('Texto opcional inválido.');
}

int? _optionalInt(dynamic value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
