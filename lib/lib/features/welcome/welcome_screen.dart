import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/petal_palette.dart';
import '../../core/theme/petal_text.dart';
import '../../core/theme/petal_tokens.dart';
import '../../core/utils/motion.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../me/state/me_providers.dart';

/// Whether the welcome slides were finished. Null while loading.
final welcomeSeenProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.welcomeSeen)
      .map((v) => v == 'true');
});

/// Marks the welcome as seen (false shows it again, e.g. from Settings).
Future<void> setWelcomeSeen(WidgetRef ref, bool seen) =>
    ref.read(settingsRepositoryProvider).setFlag(SettingKeys.welcomeSeen, seen);

class _Slide {
  const _Slide(this.icon, this.tile, this.title, this.body);
  final IconData icon;
  final Color tile;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    LucideIcons.mic,
    PetalColors.tileLavender,
    'Just say it',
    'Tap the mic and talk.\n"Spent 250 on lunch and 100 on auto"\n'
        '"Call mom tomorrow at 6"\nPetal sorts it out.',
  ),
  _Slide(
    LucideIcons.shieldCheck,
    PetalColors.tileMint,
    'Private by design',
    'No account, no ads, no tracking.\nYour tasks, money and moods stay on '
        'your phone.',
  ),
  _Slide(
    LucideIcons.wifiOff,
    PetalColors.tileSky,
    'Works offline',
    'Even the voice. Plan your day anywhere, no internet needed.',
  ),
];

/// First launch: three short slides, then "What should I call you?".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;
  bool _nameFilled = false;

  static const _count = 4; // three slides + name

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _count - 1) {
      _pages.nextPage(
        duration: motionDuration(context, const Duration(milliseconds: 320)),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isNotEmpty) await ref.read(meControllerProvider).setName(name);
    await setWelcomeSeen(ref, true);
  }

  @override
  Widget build(BuildContext context) {
    // Pre-fill a name saved earlier (e.g. when replaying from Settings).
    if (!_nameFilled) {
      final saved = ref.watch(userNameProvider).value;
      if (saved != null) {
        _nameFilled = true;
        _name.text = saved;
      }
    }
    final palette = context.palette;
    final last = _page == _count - 1;

    return Scaffold(
      backgroundColor: PetalColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: last
                        ? null
                        : () => _pages.animateToPage(
                            _count - 1,
                            duration: motionDuration(
                              context,
                              const Duration(milliseconds: 400),
                            ),
                            curve: Curves.easeOutCubic,
                          ),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (final s in _slides) _SlidePage(slide: s),
                  _NamePage(controller: _name, onDone: _finish),
                ],
              ),
            ),
            Semantics(
              label: 'Page ${_page + 1} of $_count',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? palette.deep : palette.soft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: PetalColors.ink,
                  ),
                  child: Text(last ? "Let's go" : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: slide.tile,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 56, color: context.palette.deep),
          ),
          const SizedBox(height: 36),
          Semantics(
            header: true,
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: pacifico(size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: nunito(
              FontWeight.w600,
              size: 16,
              color: PetalColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller, required this.onDone});
  final TextEditingController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              color: PetalColors.tilePeach,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.flower2,
              size: 56,
              color: context.palette.deep,
            ),
          ),
          const SizedBox(height: 36),
          Semantics(
            header: true,
            child: Text(
              'What should I call you?',
              textAlign: TextAlign.center,
              style: pacifico(size: 28),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            onSubmitted: (_) => onDone(),
            decoration: const InputDecoration(hintText: 'Your first name'),
          ),
          const SizedBox(height: 12),
          Text(
            'Optional. You can change it any time in Me.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
