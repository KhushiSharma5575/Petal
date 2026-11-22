import 'package:material_ui/material_ui.dart';

import '../theme/petal_palette.dart';
import '../theme/petal_tokens.dart';
import 'petal_card.dart';

/// Friendly placeholder for a screen or section with nothing to show yet:
/// an outlined icon in a soft circle, a title and one line of help.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tileColor,
    this.action,
  });

  /// Optional button under the message (e.g. "Show all tasks").
  final Widget? action;

  final IconData icon;
  final String title;
  final String message;

  /// Background of the icon circle. Defaults to the theme's soft colour.
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return PetalCard(
      padding: const EdgeInsets.symmetric(
        horizontal: PetalSpacing.xl,
        vertical: PetalSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tileColor ?? palette.soft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: palette.deep),
          ),
          const SizedBox(height: PetalSpacing.lg),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: PetalSpacing.xs),
          Text(message, style: text.bodySmall, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: PetalSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
