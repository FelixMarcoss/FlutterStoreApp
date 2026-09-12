import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models/detection.dart';

/// Avatar da pessoa detectada. Nunca existe uma foto de rosto real no mock
/// (por privacidade, o Supabase só recebe vetores faciais) — por isso
/// desenhamos um círculo colorido derivado do id. Quando o software
/// principal expuser uma foto local via API, [Detection.photoBytes]
/// deixa de ser nulo e a imagem real é usada aqui automaticamente.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.detection, this.radius = 26});

  final Detection detection;
  final double radius;

  static const _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFF8D6E63),
    Color(0xFF7E57C2),
    Color(0xFF42A5F5),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final photo = detection.photoBytes;
    if (photo != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(Uint8List.fromList(photo)),
      );
    }

    final color = _palette[detection.id.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Icon(Icons.person, color: Colors.white, size: radius),
    );
  }
}
