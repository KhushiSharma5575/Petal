/// The five daily moods, best first. Stored by [name].
enum Mood {
  great('Great'),
  good('Good'),
  okay('Okay'),
  low('Low'),
  bad('Bad');

  const Mood(this.label);
  final String label;

  static Mood? tryParse(String? s) {
    for (final m in values) {
      if (m.name == s) return m;
    }
    return null;
  }
}
