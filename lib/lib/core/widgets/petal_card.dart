import 'package:material_ui/material_ui.dart';

import '../theme/petal_tokens.dart';

/// White rounded card with Petal's soft purple shadow.
///
/// If [onTap] is set, the whole card becomes a button with an ink ripple, and
/// [semanticLabel] (if given) is read by TalkBack.
class PetalCard extends StatelessWidget {
  const PetalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PetalSpacing.lg),
    this.color = PetalColors.surface,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: PetalRadii.cardRadius,
        child: content,
      );
    }
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: PetalRadii.cardRadius,
          boxShadow: PetalShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: PetalRadii.cardRadius,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}
