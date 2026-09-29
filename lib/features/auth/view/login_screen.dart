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
      create: (context) =>
          LoginCubit(connectionRepository: context.read<ConnectionRepository>())
            ..loadLastConnection(),
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
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Falha ao conectar.'),
                  backgroundColor: AppColors.dangerStrong,
                ),
              );
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    const SizedBox(height: 32),
                    BlocBuilder<LoginCubit, LoginState>(
                      buildWhen: (previous, current) =>
                          previous.awaitingApproval !=
                              current.awaitingApproval ||
                          previous.approvalExpiresAt !=
                              current.approvalExpiresAt,
                      builder: (context, state) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: state.awaitingApproval
                              ? _ApprovalWaiting(
                                  expiresAt: state.approvalExpiresAt,
                                )
                              : const Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ConnectionForm(),
                                    SizedBox(height: 24),
                                    _SubmitButton(),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _HelperText(),
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
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ).createShader(bounds),
          child: Text(
            'FaceTrack',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x403B82F6), blurRadius: 15)],
            ),
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

class _ApprovalWaiting extends StatelessWidget {
  const _ApprovalWaiting({required this.expiresAt});

  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final expiryText = expiresAt == null
        ? null
        : '${expiresAt!.hour.toString().padLeft(2, '0')}:'
              '${expiresAt!.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Aguardando aprovação do gerente',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          expiryText == null
              ? 'Confirme a solicitação na aba Fiscais Mobile do FaceTrack.'
              : 'Confirme a solicitação na aba Fiscais Mobile até $expiryText.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: context.read<LoginCubit>().cancelApproval,
          child: const Text('Cancelar solicitação'),
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
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
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
