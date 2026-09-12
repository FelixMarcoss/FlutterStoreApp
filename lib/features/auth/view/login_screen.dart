import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../../core/theme/app_theme.dart';
import '../cubit/login_cubit.dart';
import '../cubit/session_cubit.dart';
import '../data/repositories/connection_repository.dart';
import 'widgets/connection_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(
        connectionRepository: context.read<ConnectionRepository>(),
      )..loadLastConnection(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<LoginCubit, LoginState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status.isFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.errorMessage ?? 'Falha ao conectar.'),
                backgroundColor: AppColors.danger,
              ));
          } else if (state.status.isSuccess && state.connection != null) {
            context.read<SessionCubit>().setConnected(state.connection!);
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(),
                    SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConnectionForm(),
                            SizedBox(height: 24),
                            _SubmitButton(),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _HelperText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Sentinela',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Conecte-se ao sistema de segurança da loja',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final isValid = context.select((LoginCubit c) => c.state.isValid);
    final isLoading = context.select((LoginCubit c) => c.state.isLoading);

    return FilledButton(
      key: const Key('login_submit_button'),
      onPressed: (isValid && !isLoading)
          ? () => context.read<LoginCubit>().submit()
          : null,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : const Text('Conectar'),
    );
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'O IP e a porta são exibidos na tela do software principal, no computador da loja. '
      'As contas de acesso são criadas por lá — este app não cria nem altera usuários.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
    );
  }
}
