import 'package:flutter/material.dart';

import '../theme/build_context_ext.dart';

/// Circular avatar with network image and initials fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
  });

  final String? imageUrl;
  final String? name;
  final double radius;

  String get _initials {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    return parts.length == 1
        ? parts.first.characters.first.toUpperCase()
        : (parts.first.characters.first + parts.last.characters.first)
            .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.mutedBg,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              _initials,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
    );
  }
}
