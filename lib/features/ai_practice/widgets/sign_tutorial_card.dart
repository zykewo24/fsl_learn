import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Collapsible "How to sign" tutorial shown on the practice screen.
///
/// Displays the target sign's label badge, a reference image when
/// available, and brief how-to instructions + live feedback tips.
class SignTutorialCard extends StatelessWidget {
  final String title;
  final String? label;

  /// How-to / description text for the sign.
  final String description;

  /// Network URL or asset path of a reference image (optional).
  final String? image;

  const SignTutorialCard({
    super.key,
    required this.title,
    this.label,
    required this.description,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          initiallyExpanded: !_hasReference(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: _LabelBadge(color: theme.colorScheme.primary, label: label),
          title: Text(
            "How to sign '$title'",
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Match the shape to turn the tracking lines green',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.66),
            ),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          children: [
            if (_hasReference())
              _ReferenceImage(
                image: image!,
                title: title,
                label: label,
              ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const _LiveTip(
              color: AppColors.success,
              icon: Icons.check_circle_outline,
              text: 'Green lines - your hand is signing correctly',
            ),
            const SizedBox(height: 8),
            const _LiveTip(
              color: AppColors.danger,
              icon: Icons.adjust,
              text: 'Red lines - keep adjusting your hand placement',
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelBadge extends StatelessWidget {
  final Color color;
  final String? label;

  const _LabelBadge({required this.color, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        (label ?? '?').isEmpty ? '?' : label!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReferenceImage extends StatelessWidget {
  final String image;
  final String title;
  final String? label;

  const _ReferenceImage({
    required this.image,
    required this.title,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isAsset = !image.startsWith('http');

    final imageWidget = isAsset
        ? ColoredBox(
            color: Colors.white,
            child: Image.asset(
              image,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _Placeholder(label: label),
            ),
          )
        : Image.network(
            image,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _Placeholder(label: label),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageWidget,
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String? label;

  const _Placeholder({this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: Text(
        "Reference\n'${(label ?? '').isEmpty ? '?' : label}'",
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.subtitle),
      ),
    );
  }
}

class _LiveTip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _LiveTip({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
        ),
      ],
    );
  }
}

extension on SignTutorialCard {
  bool _hasReference() {
    final image = this.image;
    return image != null && image.isNotEmpty;
  }
}