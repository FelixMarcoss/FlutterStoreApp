part of 'login_cubit.dart';

final class LoginState extends Equatable {
  const LoginState({
    this.ip = const IpAddressInput.pure(),
    this.port = const PortInput.pure(),
    this.username = const UsernameInput.pure(),
    this.password = const PasswordInput.pure(),
    this.rememberConnection = true,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.connection,
  });

  final IpAddressInput ip;
  final PortInput port;
  final UsernameInput username;
  final PasswordInput password;
  final bool rememberConnection;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final ConnectionConfig? connection;

  bool get isValid => Formz.validate([ip, port, username, password]);
  bool get isLoading => status.isInProgress;

  LoginState copyWith({
    IpAddressInput? ip,
    PortInput? port,
    UsernameInput? username,
    PasswordInput? password,
    bool? rememberConnection,
    FormzSubmissionStatus? status,
    String? errorMessage,
    ConnectionConfig? connection,
  }) {
    return LoginState(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      rememberConnection: rememberConnection ?? this.rememberConnection,
      status: status ?? this.status,
      // errorMessage é limpo deliberadamente quando não passado explicitamente.
      errorMessage: errorMessage,
      connection: connection ?? this.connection,
    );
  }

  @override
  List<Object?> get props => [
        ip,
        port,
        username,
        password,
        rememberConnection,
        status,
        errorMessage,
        connection,
      ];
}
