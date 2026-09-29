import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/connection_config.dart';
import '../data/repositories/connection_repository.dart';

/// Fonte única de verdade sobre a sessão ativa com o software principal.
/// `state == null` => não conectado (o [AppRouter] redireciona para /login).
class SessionCubit extends Cubit<ConnectionConfig?> {
  SessionCubit({required ConnectionRepository connectionRepository})
    : _connectionRepository = connectionRepository,
      super(null);

  final ConnectionRepository _connectionRepository;
  bool _disconnecting = false;

  void setConnected(ConnectionConfig connection) => emit(connection);

  Future<void> restore() async {
    try {
      final connection = await _connectionRepository.restoreSession();
      if (!isClosed && connection != null) emit(connection);
    } catch (_) {
      // Sessão ausente/corrompida não impede a abertura da tela de login.
    }
  }

  Future<void> disconnect() async {
    if (_disconnecting) return;
    _disconnecting = true;
    // Bloqueia a interface imediatamente. A revogação no servidor pode levar
    // alguns segundos quando justamente foi a rede que caiu.
    if (!isClosed && state != null) emit(null);
    try {
      await _connectionRepository.disconnect();
    } finally {
      _disconnecting = false;
    }
  }
}
