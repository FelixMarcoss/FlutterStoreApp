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

  void setConnected(ConnectionConfig connection) => emit(connection);

  Future<void> disconnect() async {
    await _connectionRepository.disconnect();
    emit(null);
  }
}
