import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/detection.dart';
import '../../data/repositories/detection_repository.dart';

/// Avatar da pessoa detectada. Nunca existe uma foto de rosto real no mock
/// (por privacidade, o Supabase só recebe vetores faciais) — por isso
/// desenhamos um círculo colorido derivado do id. Quando o software
/// principal expuser uma foto local via API, [Detection.photoBytes]
/// deixa de ser nulo e a imagem real é usada aqui automaticamente.
class PersonAvatar extends StatefulWidget {
  const PersonAvatar({super.key, required this.detection, this.radius = 26});

  final Detection detection;
  final double radius;

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar> {
  Future<List<int>?>? _photo;

  static const _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFF8D6E63),
    Color(0xFF7E57C2),
    Color(0xFF42A5F5),
    Color(0xFFEC407A),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photo ??= context.read<DetectionRepository>().fetchPhoto(widget.detection);
  }

  @override
  void didUpdateWidget(covariant PersonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detection.id != widget.detection.id ||
        oldWidget.detection.photoUrl != widget.detection.photoUrl) {
      _photo = context.read<DetectionRepository>().fetchPhoto(widget.detection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>?>(
      future: _photo,
      builder: (context, snapshot) {
        final photo = snapshot.data;
        if (photo != null && photo.isNotEmpty) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundImage: MemoryImage(Uint8List.fromList(photo)),
          );
        }

        final color =
            _palette[widget.detection.id.hashCode.abs() % _palette.length];
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: color,
          child: Icon(Icons.person, color: Colors.white, size: widget.radius),
        );
      },
    );
  }
}
