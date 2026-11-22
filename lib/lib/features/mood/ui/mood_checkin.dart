import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/petal_palette.dart';
import '../../../core/theme/petal_text.dart';
import '../../../core/theme/petal_tokens.dart';
import '../../../core/widgets/petal_card.dart';
import '../../../data/models/mood.dart';
import '../state/mood_providers.dart';
import 'mood_face.dart';

/// Daily mood check-in. Five faces until one is picked, then a single line
/// ("Feeling good") with a Change button.
class MoodCheckIn extends ConsumerStatefulWidget {
  const MoodCheckIn({super.key});

  @override
  ConsumerState<MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends ConsumerState<MoodCheckIn> {
  /// True while the user is changing an existing answer.
  bool _changing = false;

  Future<void> _pick(Mood mood) async {
    setState(() => _changing = false);
    await ref.read(moodControllerProvider).setToday(mood);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(todayMoodProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final mood = async.value;

    if (mood != null && !_changing) {
      return PetalCard(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            MoodFace(mood: mood, size: 32),
            const SizedBox(width: PetalSpacing.md),
            Expanded(
              child: Text(
                'Feeling ${mood.label.toLowerCase()}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _changing = true),
              child: Text(
                'Change',
                semanticsLabel: 'Change today\'s mood',
                style: nunito(
                  FontWeight.w800,
                  size: 14,
                  color: context.palette.deep,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PetalCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How are you feeling?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PetalSpacing.sm),
          Row(
            children: [
              for (final m in Mood.values)
                Expanded(
                  child: _FaceButton(
                    mood: m,
                    selected: m == mood,
                    onTap: () => _pick(m),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Feeling ${mood.label.toLowerCase()}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              MoodFace(mood: mood, size: 40),
              const SizedBox(height: 4),
              Text(
                mood.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nunito(
                  FontWeight.w700,
                  size: 11,
                  color: selected
                      ? context.palette.deep
                      : PetalColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
