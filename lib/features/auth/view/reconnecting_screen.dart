import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Bloqueia o conteúdo operacional enquanto o canal em tempo real está fora
/// do ar. A sessão e o endereço permanecem intactos; o repositório continua
/// tentando abrir o WebSocket no mesmo IP e porta em segundo plano.
class ReconnectingScreen extends StatelessWidget {
  const ReconnectingScreen({
    required this.address,
    required this.onLogout,
    super.key,
  });

  final String address;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        key: const Key('reconnecting_screen'),
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                const _FaceTrackBrand(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _ConnectionLoader(),
                          const SizedBox(height: 30),
                          const Text(
                            'Reconectando...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'A conexão com o servidor da loja foi perdida. O FaceTrack continuará tentando automaticamente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.dns_outlined,
                                  color: AppColors.action,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    address,
                                    key: const Key('reconnecting_address'),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_find_rounded,
                                color: AppColors.warning,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Mantenha o Wi-Fi da loja ativado.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('reconnecting_logout_button'),
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('SAIR E FAZER LOGOUT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.stroke),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaceTrackBrand extends StatelessWidget {
  const _FaceTrackBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.center_focus_strong_rounded,
          color: AppColors.action,
          size: 31,
        ),
        SizedBox(width: 10),
        Text(
          'FaceTrack',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ConnectionLoader extends StatelessWidget {
  const _ConnectionLoader();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox.square(
            dimension: 104,
            child: CircularProgressIndicator(
              key: Key('reconnecting_progress'),
              strokeWidth: 3,
              color: AppColors.action,
              backgroundColor: AppColors.surfaceElevated,
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_tethering_error_rounded,
              color: AppColors.warning,
              size: 35,
            ),
          ),
        ],
      ),
    );
  }
}
