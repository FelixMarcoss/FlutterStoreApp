import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:sentinela_app/core/utils/connection_form_inputs.dart';

void main() {
  group('IpAddressInput', () {
    test('pure é inválido mas não exibe erro', () {
      const ip = IpAddressInput.pure();
      expect(ip.isPure, isTrue);
      expect(ip.isValid, isFalse);
      expect(ip.displayError, isNull);
    });

    test('aceita um IPv4 válido', () {
      const ip = IpAddressInput.dirty('192.168.0.10');
      expect(ip.isValid, isTrue);
    });

    test('aceita hostname local valido', () {
      expect(const IpAddressInput.dirty('facetrack.local').isValid, isTrue);
    });

    test('rejeita endereço público em conexão HTTP local', () {
      expect(const IpAddressInput.dirty('8.8.8.8').isValid, isFalse);
      expect(const IpAddressInput.dirty('example.com').isValid, isFalse);
    });

    test('rejeita octeto fora do intervalo', () {
      const ip = IpAddressInput.dirty('192.168.0.999');
      expect(ip.isValid, isFalse);
      expect(ip.displayError, IpAddressValidationError.invalid);
    });

    test('rejeita formato incompleto', () {
      const ip = IpAddressInput.dirty('192.168.0');
      expect(ip.isValid, isFalse);
    });

    test('rejeita loopback de smartphone físico', () {
      expect(const IpAddressInput.dirty('127.0.0.1').isValid, isFalse);
      expect(const IpAddressInput.dirty('localhost').isValid, isFalse);
    });
  });

  group('PortInput', () {
    test('aceita porta válida', () {
      expect(const PortInput.dirty('8080').isValid, isTrue);
    });

    test('rejeita porta 0', () {
      expect(const PortInput.dirty('0').isValid, isFalse);
    });

    test('rejeita porta acima de 65535', () {
      expect(const PortInput.dirty('70000').isValid, isFalse);
    });

    test('rejeita valor não numérico', () {
      expect(const PortInput.dirty('abc').isValid, isFalse);
    });
  });

  group('UsernameInput / PasswordInput', () {
    test('usuário vazio é inválido', () {
      expect(const UsernameInput.dirty('').isValid, isFalse);
      expect(const UsernameInput.dirty('  ').isValid, isFalse);
    });

    test('senha vazia é inválida', () {
      expect(const PasswordInput.dirty('').isValid, isFalse);
    });

    test('Formz.validate exige todos os campos válidos', () {
      const valid = <FormzInput>[
        IpAddressInput.dirty('10.0.0.5'),
        PortInput.dirty('9000'),
        OperatorNameInput.dirty('Marcos Silva'),
        UsernameInput.dirty('guarda'),
        PasswordInput.dirty('1234'),
      ];
      expect(Formz.validate(valid), isTrue);

      const missingPassword = <FormzInput>[
        IpAddressInput.dirty('10.0.0.5'),
        PortInput.dirty('9000'),
        OperatorNameInput.dirty('Marcos Silva'),
        UsernameInput.dirty('guarda'),
        PasswordInput.dirty(''),
      ];
      expect(Formz.validate(missingPassword), isFalse);
    });
  });

  group('OperatorNameInput', () {
    test('exige nome ou matricula do fiscal', () {
      expect(const OperatorNameInput.dirty('Fiscal 01').isValid, isTrue);
      expect(const OperatorNameInput.dirty('   ').isValid, isFalse);
    });
  });
}
