import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/connection_form_inputs.dart';
import '../../cubit/login_cubit.dart';

class ConnectionForm extends StatefulWidget {
  const ConnectionForm({super.key});

  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final state = context.read<LoginCubit>().state;
    _ipController = TextEditingController(text: state.ip.value);
    _portController = TextEditingController(text: state.port.value);
    _usernameController = TextEditingController(text: state.username.value);
    _passwordController = TextEditingController(text: state.password.value);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _IpField(controller: _ipController),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _PortField(controller: _portController),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _UsernameField(controller: _usernameController),
        const SizedBox(height: 16),
        _PasswordField(
          controller: _passwordController,
          obscure: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 8),
        _RememberConnectionSwitch(),
      ],
    );
  }
}

class _IpField extends StatelessWidget {
  const _IpField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final displayError =
        context.select((LoginCubit c) => c.state.ip.displayError);
    return TextField(
      controller: controller,
      key: const Key('login_ip_field'),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      onChanged: context.read<LoginCubit>().ipChanged,
      decoration: InputDecoration(
        labelText: 'Endereço IP',
        hintText: '192.168.0.10',
        prefixIcon: const Icon(Icons.router_outlined),
        errorText: displayError == IpAddressValidationError.invalid
            ? 'IP inválido'
            : null,
      ),
    );
  }
}

class _PortField extends StatelessWidget {
  const _PortField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final displayError =
        context.select((LoginCubit c) => c.state.port.displayError);
    return TextField(
      controller: controller,
      key: const Key('login_port_field'),
      keyboardType: TextInputType.number,
      onChanged: context.read<LoginCubit>().portChanged,
      decoration: InputDecoration(
        labelText: 'Porta',
        hintText: '8080',
        errorText: displayError == PortValidationError.invalid ? 'Inválida' : null,
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final displayError =
        context.select((LoginCubit c) => c.state.username.displayError);
    return TextField(
      controller: controller,
      key: const Key('login_username_field'),
      textInputAction: TextInputAction.next,
      onChanged: context.read<LoginCubit>().usernameChanged,
      decoration: InputDecoration(
        labelText: 'Usuário',
        prefixIcon: const Icon(Icons.person_outline),
        errorText:
            displayError == UsernameValidationError.empty ? 'Obrigatório' : null,
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final displayError =
        context.select((LoginCubit c) => c.state.password.displayError);
    return TextField(
      controller: controller,
      key: const Key('login_password_field'),
      obscureText: obscure,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => context.read<LoginCubit>().submit(),
      onChanged: context.read<LoginCubit>().passwordChanged,
      decoration: InputDecoration(
        labelText: 'Senha',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: onToggleObscure,
        ),
        errorText:
            displayError == PasswordValidationError.empty ? 'Obrigatória' : null,
      ),
    );
  }
}

class _RememberConnectionSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final remember =
        context.select((LoginCubit c) => c.state.rememberConnection);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: remember,
      activeThumbColor: AppColors.primary,
      onChanged: context.read<LoginCubit>().rememberConnectionChanged,
      title: const Text('Lembrar IP e porta neste aparelho'),
      subtitle: const Text('A senha nunca é salva no dispositivo'),
    );
  }
}
