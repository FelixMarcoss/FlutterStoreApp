import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../detections/data/models/detection.dart';
import '../../detections/data/models/detection_status.dart';
import '../cubit/alert_cubit.dart';

/// Tela crítica de alto risco. O visual privilegia a comparação das duas
/// imagens e mantém as ações operacionais sempre acessíveis na parte inferior.
class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BlocConsumer<AlertCubit, AlertState>(
        listenWhen: (previous, current) =>
            previous.current != null && current.current == null,
        listener: (context, state) {
          if (context.canPop()) context.pop();
        },
        builder: (context, state) {
          final detection = state.current;
          if (detection == null) {
            return const Scaffold(body: SizedBox.shrink());
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _BrandHeader(
                    detection: detection,
                    queuedAlerts: state.queue.length - 1,
                    isSilenced: state.isSilenced,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RiskBanner(detection: detection),
                              const SizedBox(height: 14),
                              _DetectionPhotos(detection: detection),
                              if (detection.confidence != null) ...[
                                const SizedBox(height: 12),
                                _ConfidencePanel(
                                  confidence: detection.confidence!,
                                ),
                              ],
                              const SizedBox(height: 14),
                              _SuspectDataCard(
                                detection: detection,
                                queuedAlerts: state.queue.length - 1,
                                isSilenced: state.isSilenced,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _AlertActions(isSilenced: state.isSilenced),
          );
        },
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.detection,
    required this.queuedAlerts,
    required this.isSilenced,
  });

  final Detection detection;
  final int queuedAlerts;
  final bool isSilenced;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.center_focus_strong_rounded,
            color: AppColors.textSecondary,
            size: 30,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FaceTrack',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'INFORMAÇÕES DETALHADAS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: detection.status.backgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSilenced
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: detection.status.color,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  isSilenced ? 'SILENCIADO' : 'ALARME ATIVO',
                  style: TextStyle(
                    color: detection.status.color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (queuedAlerts > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '+$queuedAlerts',
                    style: TextStyle(
                      color: detection.status.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBanner extends StatelessWidget {
  const _RiskBanner({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final title = detection.isSuperCloud
        ? 'OCORRÊNCIA DA REDE'
        : switch (detection.status) {
            DetectionStatus.knownThief => 'SUSPEITO DETECTADO',
            DetectionStatus.suspect => 'PESSOA SOB ATENÇÃO',
            DetectionStatus.newPerson => 'PESSOA IDENTIFICADA',
          };
    final subtitle = detection.isSuperCloud
        ? 'CLASSIFICAÇÃO DE RISCO NÃO INFORMADA'
        : switch (detection.status) {
            DetectionStatus.knownThief => 'INTERVENÇÃO IMEDIATA REQUERIDA',
            DetectionStatus.suspect => 'PROTOCOLO DE ATENÇÃO PREVENTIVA',
            DetectionStatus.newPerson => 'REGISTRO INFORMATIVO',
          };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: detection.status.backgroundColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: detection.status.color),
      ),
      child: Row(
        children: [
          Icon(detection.status.icon, color: detection.status.color, size: 38),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: detection.status.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: detection.status.color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              detection.riskLabel.toUpperCase(),
              style: const TextStyle(
                color: AppColors.background,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidencePanel extends StatelessWidget {
  const _ConfidencePanel({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: AppColors.action,
                size: 20,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'CONFIANÇA BIOMÉTRICA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${(confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppColors.action,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 9,
              color: AppColors.action,
              backgroundColor: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionPhotos extends StatelessWidget {
  const _DetectionPhotos({required this.detection});

  final Detection detection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke, width: 1.4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FacePhoto(
                  label: 'FLAGRANTE',
                  bytes: detection.photoBytes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FacePhoto(
                  label: detection.isSuperCloud ? 'FOTO LOCAL' : 'CADASTRO',
                  bytes: detection.registeredPhotoBytes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacePhoto extends StatelessWidget {
  const _FacePhoto({required this.label, required this.bytes});

  final String label;
  final List<int>? bytes;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.84,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes == null || bytes!.isEmpty)
              const ColoredBox(
                color: AppColors.surfaceElevated,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 58,
                ),
              )
            else
              Image.memory(
                Uint8List.fromList(bytes!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuspectDataCard extends StatelessWidget {
  const _SuspectDataCard({
    required this.detection,
    required this.queuedAlerts,
    required this.isSilenced,
  });

  final Detection detection;
  final int queuedAlerts;
  final bool isSilenced;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final confidence = detection.confidence == null
        ? null
        : '${(detection.confidence! * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detection.isSuperCloud
                ? 'DADOS DA OCORRÊNCIA'
                : detection.status == DetectionStatus.knownThief
                ? 'DADOS DO SUSPEITO'
                : 'DADOS DA PESSOA',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          _DataRow(
            label: detection.isSuperCloud ? 'Ocorrência' : 'Nome',
            value: detection.isSuperCloud
                ? '#${detection.occurrenceNumber}'
                : detection.displayCode,
            valueColor: AppColors.action,
          ),
          if (detection.originStoreName?.trim().isNotEmpty == true)
            _DataRow(
              label: 'Loja de origem',
              value: detection.originStoreName!.trim(),
            ),
          if (detection.cameraLocation.trim().isNotEmpty)
            _DataRow(label: 'Câmera', value: detection.cameraLocation),
          _DataRow(
            label: 'Detectado em',
            value: dateFormat.format(detection.detectedAt),
          ),
          _DataRow(
            label: 'Nível de perigo',
            value: detection.riskLabel.toUpperCase(),
            valueColor: detection.status.color,
          ),
          if (confidence != null)
            _DataRow(label: 'Confiança', value: confidence),
          if (!detection.isSuperCloud &&
              detection.registeredBy?.trim().isNotEmpty == true)
            _DataRow(
              label: 'Cadastrado por',
              value: detection.registeredBy!.trim(),
            ),
          if (!detection.isSuperCloud && detection.createdAt != null)
            _DataRow(
              label: 'Cadastrado em',
              value: dateFormat.format(detection.createdAt!),
            ),
          if (!detection.isSuperCloud &&
              (detection.notes?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              detection.notes!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (isSilenced || queuedAlerts > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isSilenced)
                  const _InfoChip(
                    icon: Icons.notifications_off_outlined,
                    label: 'Alarme silenciado',
                  ),
                if (queuedAlerts > 0)
                  _InfoChip(
                    icon: Icons.queue_rounded,
                    label: '+$queuedAlerts na fila',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.25,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.warning, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertActions extends StatelessWidget {
  const _AlertActions({required this.isSilenced});

  final bool isSilenced;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _AlertActionButton(
                key: const Key('alert_silence_button'),
                icon: isSilenced
                    ? Icons.notifications_off_rounded
                    : Icons.volume_off_rounded,
                label: isSilenced ? 'ALARME\nSILENCIADO' : 'SILENCIAR\nALARME',
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                borderColor: AppColors.stroke,
                onTap: isSilenced
                    ? null
                    : context.read<AlertCubit>().silenceCurrent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AlertActionButton(
                key: const Key('alert_ok_button'),
                icon: Icons.check_rounded,
                label: 'CIENTE /\nATENDER',
                backgroundColor: AppColors.action,
                foregroundColor: AppColors.background,
                borderColor: AppColors.action,
                onTap: context.read<AlertCubit>().acknowledgeCurrent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertActionButton extends StatelessWidget {
  const _AlertActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label.replaceAll('\n', ' '),
      child: Opacity(
        opacity: onTap == null ? 0.62 : 1,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 86,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foregroundColor, size: 30),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 13,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
