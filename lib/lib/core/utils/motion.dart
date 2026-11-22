import 'package:material_ui/material_ui.dart';

/// Returns [normal], or [Duration.zero] when the user has turned on
/// "Remove animations" / "Reduce motion" in Android accessibility settings.
///
/// Use this for every non-essential animation in the app.
Duration motionDuration(BuildContext context, Duration normal) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
}

/// True when the user prefers reduced motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);
