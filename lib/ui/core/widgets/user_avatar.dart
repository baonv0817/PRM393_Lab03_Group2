import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photoUrl, this.size = 56});

  final String name;
  final String? photoUrl;
  final double size;

  static String initialOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.isEmpty ? '' : words.last.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final fallback = _Fallback(initial: initialOf(name), size: size);
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: url == null || !url.startsWith('https://')
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Center(
        child: initial.isEmpty
            ? Icon(Icons.person, color: colors.primaryText, size: size * 0.5)
            : Text(
                initial,
                style: text.titleMedium?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.4,
                ),
              ),
      ),
    );
  }
}
