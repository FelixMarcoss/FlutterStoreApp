part of 'login_cubit.dart';

final class LoginState extends Equatable {
  const LoginState({
    this.ip = const IpAddressInput.pure(),
    this.port = const PortInput.pure(),
    this.operatorName = const OperatorNameInput.pure(),
    this.username = const UsernameInput.pure(),
    this.password = const PasswordInput.pure(),
    this.rememberConnection = true,
    this.status = FormzSubmissionStatus.initial,
    this.errorMessage,
    this.connection,
    this.awaitingApproval = false,
    this.approvalExpiresAt,
  });

  final IpAddressInput ip;
  final PortInput port;
  final OperatorNameInput operatorName;
  final UsernameInput username;
  final PasswordInput password;
  final bool rememberConnection;
  final FormzSubmissionStatus status;
  final String? errorMessage;
  final ConnectionConfig? connection;
  final bool awaitingApproval;
  final DateTime? approvalExpiresAt;

  bool get isValid => Formz.validate([ip, port, username, password]);
  bool get isLoading => status.isInProgress;

  LoginState copyWith({
    IpAddressInput? ip,
    PortInput? port,
    OperatorNameInput? operatorName,
    UsernameInput? username,
    PasswordInput? password,
    bool? rememberConnection,
    FormzSubmissionStatus? status,
    String? errorMessage,
    ConnectionConfig? connection,
    bool clearConnection = false,
    bool? awaitingApproval,
    DateTime? approvalExpiresAt,
    bool clearApprovalExpiresAt = false,
  }) {
    return LoginState(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      operatorName: operatorName ?? this.operatorName,
      username: username ?? this.username,
      password: password ?? this.password,
      rememberConnection: rememberConnection ?? this.rememberConnection,
      status: status ?? this.status,
      // errorMessage é limpo deliberadamente quando não passado explicitamente.
      errorMessage: errorMessage,
      connection: clearConnection ? null : connection ?? this.connection,
      awaitingApproval: awaitingApproval ?? this.awaitingApproval,
      approvalExpiresAt: clearApprovalExpiresAt
          ? null
          : approvalExpiresAt ?? this.approvalExpiresAt,
    );
  }

  @override
  List<Object?> get props => [
    ip,
    port,
    operatorName,
    username,
    password,
    rememberConnection,
    status,
    errorMessage,
    connection,
    awaitingApproval,
    approvalExpiresAt,
  ];
}
