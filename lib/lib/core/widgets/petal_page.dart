import 'package:material_ui/material_ui.dart';

import '../theme/petal_tokens.dart';

/// Standard scrollable layout for a tab screen: page gutters, a header, then
/// the screen's blocks with even spacing.
///
/// Bottom padding comes from the Scaffold (it extends the body behind the nav
/// bar and reports the bar's height as padding), so content never hides
/// under the nav bar or the raised mic button.
class PetalPage extends StatelessWidget {
  const PetalPage({super.key, required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          PetalSpacing.page,
          PetalSpacing.xl,
          PetalSpacing.page,
          bottomInset + PetalSpacing.xl,
        ),
        children: [
          header,
          for (final child in children) ...[
            const SizedBox(height: PetalSpacing.lg),
            child,
          ],
        ],
      ),
    );
  }
}

/// A Pacifico page title with an optional small line above it and an
/// optional widget on the right (e.g. the progress ring or an "Add" button).
class PetalPageHeader extends StatelessWidget {
  const PetalPageHeader({
    super.key,
    required this.title,
    this.overline,
    this.trailing,
  });

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null) Text(overline!, style: text.labelMedium),
              Semantics(
                header: true,
                child: Text(title, style: text.headlineMedium),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: PetalSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}
