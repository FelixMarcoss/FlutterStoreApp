import 'package:formz/formz.dart';

enum IpAddressValidationError { invalid }

/// Aceita somente endereços de rede privada ou hostname `.local`. Como esta
/// versão usa HTTP/WS sem CA, bloquear destinos públicos evita que credenciais
/// sejam enviadas acidentalmente para fora da rede da loja.
class IpAddressInput extends FormzInput<String, IpAddressValidationError> {
  const IpAddressInput.pure([super.value = '']) : super.pure();
  const IpAddressInput.dirty([super.value = '']) : super.dirty();

  static final RegExp _octet = RegExp(r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$');
  static final RegExp _hostname = RegExp(
    r'^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );

  @override
  IpAddressValidationError? validator(String? value) {
    final normalized = (value ?? '').trim();
    final parts = normalized.split('.');
    final isIpv4 = parts.length == 4 && parts.every(_octet.hasMatch);
    final octets = isIpv4 ? parts.map(int.parse).toList() : const <int>[];
    final isPrivateIpv4 =
        isIpv4 &&
        (octets[0] == 10 ||
            (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
            (octets[0] == 192 && octets[1] == 168));
    final looksNumeric = RegExp(r'^[0-9.]+$').hasMatch(normalized);
    final isForbiddenLoopback =
        normalized.toLowerCase() == 'localhost' ||
        normalized.startsWith('127.');
    final isLocalHostname =
        !looksNumeric &&
        normalized.toLowerCase().endsWith('.local') &&
        _hostname.hasMatch(normalized);
    final valid = !isForbiddenLoopback && (isPrivateIpv4 || isLocalHostname);
    return valid ? null : IpAddressValidationError.invalid;
  }
}

enum OperatorNameValidationError { empty }

class OperatorNameInput
    extends FormzInput<String, OperatorNameValidationError> {
  const OperatorNameInput.pure([super.value = '']) : super.pure();
  const OperatorNameInput.dirty([super.value = '']) : super.dirty();

  @override
  OperatorNameValidationError? validator(String? value) {
    return (value == null || value.trim().isEmpty)
        ? OperatorNameValidationError.empty
        : null;
  }
}

enum PortValidationError { invalid }

/// Valida uma porta TCP válida (1-65535) usada pelo software principal.
class PortInput extends FormzInput<String, PortValidationError> {
  const PortInput.pure([super.value = '']) : super.pure();
  const PortInput.dirty([super.value = '']) : super.dirty();

  @override
  PortValidationError? validator(String? value) {
    final port = int.tryParse(value ?? '');
    final valid = port != null && port > 0 && port <= 65535;
    return valid ? null : PortValidationError.invalid;
  }
}

enum UsernameValidationError { empty }

class UsernameInput extends FormzInput<String, UsernameValidationError> {
  const UsernameInput.pure([super.value = '']) : super.pure();
  const UsernameInput.dirty([super.value = '']) : super.dirty();

  @override
  UsernameValidationError? validator(String? value) {
    return (value == null || value.trim().isEmpty)
        ? UsernameValidationError.empty
        : null;
  }
}

enum PasswordValidationError { empty }

class PasswordInput extends FormzInput<String, PasswordValidationError> {
  const PasswordInput.pure([super.value = '']) : super.pure();
  const PasswordInput.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String? value) {
    return (value == null || value.isEmpty)
        ? PasswordValidationError.empty
        : null;
  }
}
