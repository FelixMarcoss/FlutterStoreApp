import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Nível de risco atribuído pela IA do software principal.
enum DetectionStatus {
  /// Rosto já confirmado em furto(s) anterior(es) nesta loja.
  knownThief,

  /// Comportamento ou histórico parcial que gera suspeita, sem confirmação.
  suspect,

  /// Pessoa sem nenhum registro anterior no sistema.
  newPerson;

  String get label => switch (this) {
        DetectionStatus.knownThief => 'Ladrão conhecido',
        DetectionStatus.suspect => 'Suspeito',
        DetectionStatus.newPerson => 'Novo',
      };

  Color get color => switch (this) {
        DetectionStatus.knownThief => AppColors.danger,
        DetectionStatus.suspect => AppColors.warning,
        DetectionStatus.newPerson => AppColors.neutral,
      };

  Color get backgroundColor => switch (this) {
        DetectionStatus.knownThief => AppColors.dangerBackground,
        DetectionStatus.suspect => AppColors.warningBackground,
        DetectionStatus.newPerson => AppColors.neutralBackground,
      };

  IconData get icon => switch (this) {
        DetectionStatus.knownThief => Icons.warning_amber_rounded,
        DetectionStatus.suspect => Icons.help_outline_rounded,
        DetectionStatus.newPerson => Icons.person_outline_rounded,
      };
}
