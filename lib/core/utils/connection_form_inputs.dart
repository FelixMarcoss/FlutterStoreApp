import 'package:formz/formz.dart';

enum IpAddressValidationError { invalid }

/// Valida um endereço IPv4 (ex: 192.168.0.10) da rede local da loja.
class IpAddressInput extends FormzInput<String, IpAddressValidationError> {
  const IpAddressInput.pure([super.value = '']) : super.pure();
  const IpAddressInput.dirty([super.value = '']) : super.dirty();

  static final RegExp _octet = RegExp(
    r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
  );

  @override
  IpAddressValidationError? validator(String? value) {
    final parts = (value ?? '').split('.');
    final valid = parts.length == 4 && parts.every(_octet.hasMatch);
    return valid ? null : IpAddressValidationError.invalid;
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
