import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/coach.dart';
import '../theme.dart';

/// Round coach photo: prefers the photo stored in the database
/// (base64), falls back to a hosted URL, then to the initial letter.
class CoachAvatar extends StatelessWidget {
  final Coach coach;
  final double radius;

  const CoachAvatar({super.key, required this.coach, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (coach.photoData.isNotEmpty) {
      final bytes = _decode(coach.photoData);
      if (bytes != null) image = MemoryImage(bytes);
    }
    if (image == null && coach.photoUrl.isNotEmpty) {
      image = NetworkImage(coach.photoUrl);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          coach.active ? AppTheme.courtBlue : Colors.grey.shade400,
      backgroundImage: image,
      child: image == null
          ? Text(coach.name.isEmpty ? '?' : coach.name[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.75,
                  fontWeight: FontWeight.bold))
          : null,
    );
  }

  static Uint8List? _decode(String data) {
    try {
      return base64Decode(data);
    } on FormatException {
      return null; // corrupt photo — show the initial instead of crashing
    }
  }
}
