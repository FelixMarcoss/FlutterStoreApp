import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/facetrack_app_bar.dart';
import '../../../core/widgets/facetrack_navigation_bar.dart';
import '../../alert/alert_audio_service.dart';
import '../cubit/alert_preferences_cubit.dart';
import '../data/models/alert_tone.dart';

class AlertPreferencesScreen extends StatefulWidget {
  const AlertPreferencesScreen({super.key, this.audioController});

  final AlertAudioController? audioController;

  @override
  State<AlertPreferencesScreen> createState() => _AlertPreferencesScreenState();
}

class _AlertPreferencesScreenState extends State<AlertPreferencesScreen> {
  bool _isTestingSound = false;

  AlertAudioController get _audio =>
      widget.audioController ?? AlertAudioService.instance;

  @override
  void dispose() {
    if (_isTestingSound) unawaited(_audio.stop());
    super.dispose();
  }

  Future<void> _toggleSoundTest(AlertPreferencesState preferences) async {
    try {
      if (_isTestingSound) {
        await _audio.stop();
        if (mounted) setState(() => _isTestingSound = false);
        return;
      }
      await _audio.playLoop(preferences.tone, volume: preferences.volume);
      if (mounted) setState(() => _isTestingSound = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível reproduzir este som.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FaceTrackAppBar(
        title: 'FaceTrack',
        subtitle: 'TERMINAL TÁTICO • AJUSTES LOCAIS',
      ),
      bottomNavigationBar: const FaceTrackNavigationBar(currentIndex: 2),
      body: BlocBuilder<AlertPreferencesCubit, AlertPreferencesState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const Text(
                'Preferências de alertas',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Escolha o som e o volume dos alertas deste aparelho.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.action,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alertas para todos os riscos',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Detecções de risco baixo, médio e alto abrem a tela de alerta e acionam som e vibração.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SOM DO ALARME',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Escolha um dos sons incluídos no FaceTrack. A seleção não depende dos sons configurados no celular.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<AlertTone>(
                      key: const Key('alert_tone_dropdown'),
                      initialValue: state.tone,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Som selecionado',
                        prefixIcon: Icon(Icons.library_music_outlined),
                        border: InputBorder.none,
                      ),
                      items: AlertTone.values
                          .map(
                            (tone) => DropdownMenuItem(
                              value: tone,
                              child: Text(tone.title),
                            ),
                          )
                          .toList(),
                      onChanged: (tone) async {
                        if (tone == null) return;
                        final cubit = context.read<AlertPreferencesCubit>();
                        await cubit.selectTone(tone);
                        if (_isTestingSound) {
                          await _audio.playLoop(
                            tone,
                            volume: cubit.state.volume,
                          );
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text(
                        state.tone.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                        Expanded(
                          child: Slider(
                            key: const Key('alert_volume_slider'),
                            value: state.volume,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            label: '${(state.volume * 100).round()}%',
                            onChanged: (value) {
                              context
                                  .read<AlertPreferencesCubit>()
                                  .selectVolume(value, persist: false);
                              if (_isTestingSound) {
                                unawaited(_audio.setVolume(value));
                              }
                            },
                            onChangeEnd: (value) => context
                                .read<AlertPreferencesCubit>()
                                .selectVolume(value),
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          child: Text(
                            '${(state.volume * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('alert_sound_preview_button'),
                        onPressed: () => _toggleSoundTest(state),
                        icon: Icon(
                          _isTestingSound
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline_rounded,
                        ),
                        label: Text(
                          _isTestingSound ? 'PARAR TESTE' : 'TESTAR SOM',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No alerta real, o som se repete até o fiscal tocar em Ciente ou Silenciar.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'O som e o volume ficam salvos somente neste aparelho.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
