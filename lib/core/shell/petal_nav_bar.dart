import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/petal_palette.dart';
import '../theme/petal_text.dart';
import '../theme/petal_tokens.dart';
import '../utils/motion.dart';
import 'nav_state.dart';

/// Bottom navigation: Today, Tasks, [raised mic], Money, Me.
///
/// Layout: the widget is taller than the white bar by [_micOverhang] so the
/// mic button can poke out above it and still receive taps. The transparent
/// strip above the bar has no hit-testable widget except the mic, so taps
/// there reach the scrolling content behind.
class PetalNavBar extends StatelessWidget {
  const PetalNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onMic,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback onMic;

  static const double _barHeight = 68;
  static const double _micOverhang = 28;
  static const double _micSize = 64;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return MediaQuery.withClampedTextScaling(
      // Labels still grow with system font size, but are capped so the bar
      // can't overflow. Content screens are not clamped.
      maxScaleFactor: 1.4,
      child: SizedBox(
        height: _barHeight + _micOverhang + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight + bottomInset,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: PetalColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(PetalRadii.navTop),
                  ),
                  boxShadow: PetalShadows.nav,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset),
                  child: Row(
                    children: [
                      _tab(AppTab.today),
                      _tab(AppTab.tasks),
                      const Spacer(), // room for the mic
                      _tab(AppTab.money),
                      _tab(AppTab.me),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _MicButton(size: _micSize, onTap: onMic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(AppTab tab) => Expanded(
    child: _NavItem(
      tab: tab,
      selected: tab == current,
      onTap: () => onSelect(tab),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Inactive uses secondary text colour (5.6:1 on white). The prototype's
    // #8A829C was only about 3.6:1, below our 4.5:1 rule.
    final color = selected ? palette.deep : PetalColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tab.label} tab',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PetalSpacing.minTouch),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Soft pill behind the active icon, so the selected state is
              // not shown by colour alone.
              AnimatedContainer(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 200),
                ),
                curve: Curves.easeOut,
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? palette.soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(PetalRadii.chip),
                ),
                child: Icon(tab.icon, size: 22, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nunito(FontWeight.w800, size: 11, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised round mic button in the middle of the nav bar.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add by voice',
      onTap: onTap,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PetalColors.ink,
          // Cream ring makes the button look cut out of the bar.
          border: Border.all(color: PetalColors.background, width: 5),
          boxShadow: PetalShadows.mic,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const Icon(LucideIcons.mic, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
