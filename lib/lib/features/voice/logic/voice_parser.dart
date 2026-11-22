/// Rule-based English parser for things said to Petal's mic.
///
/// Pure Dart, no AI service, no network: it turns a transcript into a
/// [VoiceCommand] that the UI shows on a confirmation card before saving.
///
/// Order of checks (first match wins):
/// 1. An explicit task cue at the start ("add", "remind me to", "I need to")
///    -> task. This lets "remind me to drink water" be a task, not a habit.
/// 2. "feeling great" style -> mood.
/// 3. A spend ("spent 250 on lunch", "uber 180") -> expense.
/// 4. A finished habit ("drank 2 glasses of water", "studied 45 minutes")
///    -> habit log.
/// 5. Anything else that isn't empty -> task, so "call dentist tomorrow"
///    still works. The confirmation card lets the user fix a wrong guess.
library;

import '../../../core/utils/clock_time.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/habit.dart';
import '../../../data/models/mood.dart';
import '../../../data/models/task.dart';
import '../../tasks/logic/due_label.dart';

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

sealed class VoiceCommand {
  const VoiceCommand();
}

class AddTask extends VoiceCommand {
  const AddTask(this.draft);
  final TaskDraft draft;
  @override
  String toString() =>
      'AddTask(${draft.title}, ${draft.dueDate}, ${draft.dueTime})';
}

class AddExpense extends VoiceCommand {
  const AddExpense(this.draft);
  final ExpenseDraft draft;
  @override
  String toString() => 'AddExpense(${draft.amount}, ${draft.category})';
}

class LogHabit extends VoiceCommand {
  const LogHabit(this.habitKey, [this.amount]);

  /// One of [HabitKeys].
  final String habitKey;

  /// Glasses (water) or minutes (study) to add. Null means "mark done".
  final int? amount;
  @override
  String toString() => 'LogHabit($habitKey, $amount)';
}

class SetMood extends VoiceCommand {
  const SetMood(this.mood);
  final Mood mood;
  @override
  String toString() => 'SetMood($mood)';
}

/// Several expenses said in one go: "spent 100 on food, 200 on travel and
/// 50 on coffee".
class AddExpenses extends VoiceCommand {
  const AddExpenses(this.drafts);
  final List<ExpenseDraft> drafts;
  @override
  String toString() =>
      'AddExpenses(${drafts.map((d) => '${d.amount} ${d.category}').join(', ')})';
}

class NotUnderstood extends VoiceCommand {
  const NotUnderstood(this.said);
  final String said;
  @override
  String toString() => 'NotUnderstood("$said")';
}

/// What "Ask Petal" questions are about.
enum AskKind { spent, budgetLeft, tasks, water, streak, habitsLeft }

/// A question ("how much did I spend this week?"). Nothing is saved: Petal
/// answers out loud.
class AskPetal extends VoiceCommand {
  const AskPetal(
    this.kind, {
    required this.from,
    required this.to,
    required this.when,
    this.category,
    this.habitKey,
  });

  final AskKind kind;

  /// The days asked about (inclusive).
  final DateTime from;
  final DateTime to;

  /// "today", "tomorrow", "this week"... as it reads in the answer.
  final String when;
  final ExpenseCategory? category;
  final String? habitKey;

  @override
  String toString() => 'AskPetal($kind, $when, $category, $habitKey)';
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

VoiceCommand parseVoice(String said, DateTime now) {
  final s = _stripOpeners(_normalize(said));
  if (s.isEmpty) return NotUnderstood(said);

  final question = _question(s, now);
  if (question != null) return question;

  final cue = _taskCue.firstMatch(s);
  // "add 200 for lunch" / "add expense 50 tea": money, not a task. Only
  // for plain "add"-style cues; "add task ...", "remind me to ...",
  // "need to ..." stay tasks.
  if (cue != null && _addCue.hasMatch(cue.group(0)!)) {
    final rest = s.substring(cue.end);
    if (_looksLikeMoney(rest)) {
      final spends = _expenses('spent $rest', now);
      if (spends != null) return AddExpenses(spends);
      final spend = _expense('spent $rest', now);
      if (spend != null) return AddExpense(spend);
    }
  }
  if (cue != null) {
    final reminder = cue.group(0)!.contains('remind');
    return _task(s.substring(cue.end), now, reminder: reminder) ??
        NotUnderstood(said);
  }
  final mood = _mood(s);
  if (mood != null) return SetMood(mood);
  final spends = _expenses(s, now);
  if (spends != null) return AddExpenses(spends);
  final spend = _expense(s, now);
  if (spend != null) return AddExpense(spend);
  final habit = _habit(s);
  if (habit != null) return habit;
  return _task(s, now, reminder: false) ?? NotUnderstood(said);
}

// ---------------------------------------------------------------------------
// Questions ("Ask Petal")
// ---------------------------------------------------------------------------

final _questionStart = RegExp(
  r"^(?:how|what|what's|whats|which|when|do i|did i|have i|am i|any|anything|"
  r'tell me|show me|is there|are there|can i|give me)\b',
);

AskPetal? _question(String s, DateTime now) {
  if (!_questionStart.hasMatch(s)) return null;
  bool has(String words) => RegExp('\\b(?:$words)\\b').hasMatch(s);
  final today = dateOnly(now);

  final DateTime from, to;
  final String when;
  if (has('yesterday')) {
    from = to = addDays(today, -1);
    when = 'yesterday';
  } else if (has('tomorrow')) {
    from = to = addDays(today, 1);
    when = 'tomorrow';
  } else if (has('last week')) {
    from = addDays(startOfWeek(today), -7);
    to = addDays(from, 6);
    when = 'last week';
  } else if (has('this week|week')) {
    from = startOfWeek(today);
    to = addDays(from, 6);
    when = 'this week';
  } else if (has('last month')) {
    from = DateTime(today.year, today.month - 1, 1);
    to = DateTime(today.year, today.month, 0);
    when = 'last month';
  } else if (has('this month|month')) {
    from = DateTime(today.year, today.month, 1);
    to = DateTime(today.year, today.month + 1, 0);
    when = 'this month';
  } else {
    from = to = today;
    when = 'today';
  }
  AskPetal ask(AskKind kind, {ExpenseCategory? category, String? habit}) =>
      AskPetal(
        kind,
        from: from,
        to: to,
        when: when,
        category: category,
        habitKey: habit,
      );

  if (has('budgets?') ||
      has('left to spend|can i (?:still )?spend|money left')) {
    return ask(AskKind.budgetLeft, category: _categoryFor(s));
  }
  if (has('spend|spent|spending|expenses?|money')) {
    return ask(AskKind.spent, category: _categoryFor(s));
  }
  if (has('streaks?')) {
    final habit = has('workout|gym|exercise')
        ? HabitKeys.workout
        : has('study|studying')
        ? HabitKeys.study
        : has(r'meditat\w*')
        ? HabitKeys.meditate
        : has('read|reading')
        ? HabitKeys.read
        : has('water')
        ? HabitKeys.water
        : null;
    return ask(AskKind.streak, habit: habit);
  }
  if (has('water|glasses')) return ask(AskKind.water);
  if (has('habits?') || has("what'?s left|still to do|left to do|pending")) {
    return ask(AskKind.habitsLeft);
  }
  if (has(
    'tasks?|to-?dos?|plans?|planned|schedule|agenda|due|'
    'what do i have|on (?:today|tomorrow|for today|for tomorrow)|'
    'anything (?:today|tomorrow)',
  )) {
    return ask(AskKind.tasks);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Cleaning up what the recognizer gives us
// ---------------------------------------------------------------------------

String _normalize(String input) {
  var t = input.toLowerCase().trim();
  t = t.replaceAll('\u2019', "'");
  // "a.m." / "p. m." -> "am" / "pm"
  t = t.replaceAllMapped(RegExp(r'\b([ap])\.\s?m\b\.?'), (m) => '${m[1]}m');
  // Commas become separators, except inside numbers like 1,200.
  t = t.replaceAll(RegExp(r'(?<!\d),|,(?!\d)'), ' , ');
  // Speech writes "4:30 pm" as "4 30 pm".
  t = t.replaceAllMapped(
    RegExp(r'\b(\d{1,2}) ([0-5]\d) ?([ap]m)\b'),
    (m) => '${m[1]}:${m[2]} ${m[3]}',
  );
  // Full stops become spaces, except decimals like 99.50.
  t = t.replaceAll(RegExp(r'\.(?!\d)'), ' ');
  t = t.replaceAll(RegExp(r'[!?;"]'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = _fixSpendWords(t);
  return _numberWordsToDigits(t);
}

/// How people actually say (or the recognizer writes) spending words:
/// "spended", "payed", "buyed", "expended"... all mean a spend.
const _spendVariants = {
  'spended': 'spent',
  'spented': 'spent',
  'spends': 'spent',
  'spendings': 'spent',
  'expended': 'spent',
  'payed': 'paid',
  'paided': 'paid',
  'pays': 'paid',
  'buyed': 'bought',
  'boughted': 'bought',
  'purchase': 'purchased',
};

String _fixSpendWords(String t) {
  t = t.replaceAllMapped(
    RegExp('\\b(${_spendVariants.keys.join('|')})\\b'),
    (m) => _spendVariants[m[1]]!,
  );
  // "i spent it 250 on lunch" / "spend around 250" -> "spent 250".
  return t.replaceAllMapped(
    RegExp(
      r'\b(spent|spend|paid|bought) (?:it|around|about|like|almost|nearly) (?=(?:rs |₹ ?)?\d)',
    ),
    (m) => '${m[1]} ',
  );
}

const _units = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};
const _tens = {
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

/// "forty five" -> "45", "two" -> "2".
String _numberWordsToDigits(String t) {
  final tens = _tens.keys.join('|');
  final units = _units.keys.join('|');
  t = t.replaceAllMapped(
    RegExp('\\b($tens)[ -]($units)\\b'),
    (m) => '${_tens[m[1]]! + _units[m[2]]!}',
  );
  t = t.replaceAllMapped(RegExp('\\b($tens|$units)\\b'), (m) {
    return '${_tens[m[1]] ?? _units[m[1]]}';
  });
  // "a hundred", "2 hundred and 50", "1 thousand 5 hundred".
  t = t.replaceAllMapped(
    RegExp(r'\ba (hundred|thousand)\b'),
    (m) => '1 ${m[1]}',
  );
  t = t.replaceAllMapped(
    RegExp(r'\b(\d+) hundred(?: and)?(?: (\d{1,2}))?\b(?! hundred| thousand)'),
    (m) => '${int.parse(m[1]!) * 100 + int.parse(m[2] ?? '0')}',
  );
  t = t.replaceAllMapped(
    RegExp(r'\b(\d+) thousand(?: and)?(?: (\d{1,3}))?\b'),
    (m) => '${int.parse(m[1]!) * 1000 + int.parse(m[2] ?? '0')}',
  );
  return t;
}

/// Polite or filler words at the start (and thanks at the end).
final _opener = RegExp(
  r"^(?:hey petal|hi petal|ok petal|okay petal|petal|hey|hi|um+|uh+|erm|hmm+|so|well|"
  r"ok so|okay so|please|pls|kindly|just|can you|could you|would you|will you|"
  r"can u|i want you to|i'd like you to|i would like you to)\b[ ,]*",
);
final _closer = RegExp(r'[ ,]*\b(?:please|thanks|thank you)$');

String _stripOpeners(String s) {
  var t = s;
  while (true) {
    final next = t.replaceFirst(_opener, '').replaceFirst(_closer, '').trim();
    if (next == t) return t;
    t = next;
  }
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

final _taskCue = RegExp(
  r'^(?:remind me(?: to| about| that)?|'
  r'(?:add|create|make|set|new)(?: a| an| new)?(?: task| to-?do| todo| reminder)?(?: to| for| called| that)?|'
  r'remember to|(?:i )?(?:need|have|got) to|(?:i )?must|to-?do|task|note to self(?: to)?)'
  r'(?=\s|$)\s*',
);

final _weekdays = {
  'monday': 1,
  'tuesday': 2,
  'wednesday': 3,
  'thursday': 4,
  'friday': 5,
  'saturday': 6,
  'sunday': 7,
};
final _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};
const _monthRx =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|'
    r'aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

/// Mutable text being consumed: each recognised piece is cut out so what's
/// left becomes the title.
class _Text {
  _Text(String s) : value = ' $s ';
  String value;

  /// Finds [rx]; if found, removes it and returns the match.
  RegExpMatch? take(RegExp rx) {
    final m = rx.firstMatch(value);
    if (m != null) {
      value = value.replaceRange(m.start, m.end, ' ');
    }
    return m;
  }
}

AddTask? _task(String rest, DateTime now, {required bool reminder}) {
  final today = dateOnly(now);
  final t = _Text(rest);

  // Priority.
  var priority = TaskPriority.medium;
  if (t.take(
        RegExp(
          r"\b(?:it'?s |its )?(?:urgent(?:ly)?|important|asap|as soon as possible|(?:high|top) priority|priority high)\b",
        ),
      ) !=
      null) {
    priority = TaskPriority.high;
  } else if (t.take(RegExp(r'\b(?:low priority|priority low|not urgent)\b')) !=
      null) {
    priority = TaskPriority.low;
  } else {
    t.take(RegExp(r'\b(?:medium|normal) priority\b'));
  }

  // Date.
  DateTime? date;
  ClockTime? partOfDay;
  if (t.take(RegExp(r'\b(?:on )?(?:the )?day after tomorrow\b')) != null) {
    date = addDays(today, 2);
  } else if (t.take(RegExp(r'\b(?:by |for )?(?:tomorrow|tmrw)\b')) != null) {
    date = addDays(today, 1);
  } else if (t.take(RegExp(r'\btonight\b')) != null) {
    date = today;
    partOfDay = const ClockTime(20, 0);
  } else if (t.take(RegExp(r'\b(?:by |for )?today\b')) != null) {
    date = today;
  } else if (t.take(
        RegExp(r'\b(?:on |this |for the |at the )?(?:the )?weekend\b'),
      ) !=
      null) {
    date = today.weekday >= DateTime.saturday
        ? today
        : addDays(today, DateTime.saturday - today.weekday);
  } else if (t.take(RegExp(r'\b(?:by |for )?next week\b')) != null) {
    date = addDays(today, 8 - today.weekday);
  } else if (t.take(
        RegExp(
          '\\b(?:on |this |coming |by )?(next )?(${_weekdays.keys.join('|')})\\b',
        ),
      )
      case final m?) {
    date = _weekdayDate(today, _weekdays[m[2]]!, next: m[1] != null);
  } else if (t.take(
        RegExp(
          '\\b(?:on |by )?(?:the )?(\\d{1,2})(?:st|nd|rd|th)?(?: of)? $_monthRx\\b',
        ),
      )
      case final m?) {
    date = _monthDate(today, int.parse(m[1]!), m[2]!);
  } else if (t.take(
        RegExp(
          '\\b(?:on |by )?$_monthRx(?: the)? (\\d{1,2})(?:st|nd|rd|th)?\\b',
        ),
      )
      case final m?) {
    date = _monthDate(today, int.parse(m[2]!), m[1]!);
  }

  // Time.
  ClockTime? time;
  if (t.take(
        RegExp(r'\b(?:at |by |around |@ ?)?(\d{1,2})(?::(\d{2}))? ?(am|pm)\b'),
      )
      case final m?) {
    var h = int.parse(m[1]!) % 12;
    if (m[3] == 'pm') h += 12;
    time = _clock(h, int.tryParse(m[2] ?? '') ?? 0);
  } else if (t.take(RegExp(r'\b(?:at |by |around )?(\d{1,2}):(\d{2})\b'))
      case final m?) {
    time = _clock(int.parse(m[1]!), int.parse(m[2]!));
  } else if (t.take(RegExp(r'\b(?:at |by )?noon\b')) != null) {
    time = const ClockTime(12, 0);
  } else if (t.take(RegExp(r'\b(?:at |by )?midnight\b')) != null) {
    time = const ClockTime(0, 0);
  } else if (t.take(
        RegExp(
          r'\b(?:at |by |around )(\d{1,2})\b(?!\s*(?:minutes?|mins?|hours?|pages?|glasses?))',
        ),
      )
      case final m?) {
    final h = int.parse(m[1]!);
    // "at 6" almost always means 6 pm; "at 8" usually 8 am.
    time = _clock(h >= 1 && h <= 7 ? h + 12 : h, 0);
  }
  if (t.take(
        RegExp(r'\b(?:in the |this |tomorrow )?(morning|afternoon|evening)\b'),
      )
      case final m?) {
    partOfDay ??= switch (m[1]) {
      'morning' => const ClockTime(9, 0),
      'afternoon' => const ClockTime(14, 0),
      _ => const ClockTime(18, 0),
    };
  }
  time ??= partOfDay;
  if (time != null && date == null) {
    // A time with no day: today if it's still ahead, otherwise tomorrow.
    date = time.on(today).isAfter(now) ? today : addDays(today, 1);
  }

  final title = _cleanTitle(t.value);
  if (title.isEmpty) return null;

  return AddTask(
    TaskDraft(
      title: _capitalise(title),
      dueDate: date,
      dueTime: date == null ? null : time,
      priority: priority,
      list: _listFor(title),
      reminder: reminder && date != null,
    ),
  );
}

ClockTime? _clock(int h, int m) =>
    h >= 0 && h < 24 && m >= 0 && m < 60 ? ClockTime(h, m) : null;

DateTime _weekdayDate(DateTime today, int weekday, {required bool next}) {
  var diff = (weekday - today.weekday) % 7;
  if (!next) return addDays(today, diff); // "Friday" on a Friday = today
  if (diff == 0) diff = 7;
  final candidate = addDays(today, diff);
  // "next Friday" said on Monday means the Friday of next week.
  final sameWeek = startOfWeek(candidate) == startOfWeek(today);
  return sameWeek ? addDays(candidate, 7) : candidate;
}

DateTime? _monthDate(DateTime today, int day, String monthWord) {
  final month = _months[monthWord.substring(0, 3)]!;
  if (day < 1 || day > 31) return null;
  var date = DateTime(today.year, month, day);
  if (date.month != month) return null; // e.g. 31 February
  if (date.isBefore(today)) {
    date = DateTime(today.year + 1, month, day);
    if (date.month != month) return null; // 29 Feb in a non-leap year
  }
  return date;
}

final _connector = r'(?:to|and|then|on|at|by|for|that|about|,)';

String _cleanTitle(String raw) {
  var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  while (true) {
    final next = t
        .replaceFirst(RegExp('^$_connector(?=\\s|\$)\\s*'), '')
        .replaceFirst(RegExp('\\s*\\b$_connector\$|\\s*,\$'), '')
        .replaceAll(RegExp(r'\s+,'), ',')
        .trim();
    if (next == t) break;
    t = next;
  }
  return t.replaceAll(RegExp(r'\s*,\s*'), ', ').replaceAll(RegExp(r',$'), '');
}

String _capitalise(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

TaskList _listFor(String title) {
  if (RegExp(
    r'\b(?:buy|buying|purchase|groceries|grocery|shopping|shop for|order)\b',
  ).hasMatch(title)) {
    return TaskList.shopping;
  }
  if (RegExp(
    r'\b(?:study|studying|revise|revision|exam|exams|homework|assignment|'
    r'chapter|lecture|class|syllabus|quiz)\b',
  ).hasMatch(title)) {
    return TaskList.study;
  }
  if (RegExp(
    r'\b(?:meeting|review|report|client|clients|email|presentation|deadline|'
    r'office|work|project|standup|invoice|manager|boss)\b',
  ).hasMatch(title)) {
    return TaskList.work;
  }
  return TaskList.personal;
}

// ---------------------------------------------------------------------------
// Mood
// ---------------------------------------------------------------------------

const _moodWords = {
  Mood.great: [
    'great',
    'amazing',
    'awesome',
    'fantastic',
    'excellent',
    'wonderful',
    'brilliant',
    'superb',
    'fabulous',
  ],
  Mood.good: ['good', 'happy', 'nice', 'cheerful', 'positive', 'well'],
  Mood.okay: ['okay', 'ok', 'alright', 'fine', 'meh', 'average', 'normal'],
  Mood.low: [
    'low',
    'down',
    'sad',
    'tired',
    'blue',
    'exhausted',
    'lonely',
    'stressed',
    'anxious',
  ],
  Mood.bad: [
    'bad',
    'terrible',
    'awful',
    'horrible',
    'upset',
    'angry',
    'sick',
    'miserable',
  ],
};

Mood? _mood(String s) {
  final m =
      RegExp(
        r"^(?:i am |i'm |im |i )?(?:feeling|feel|felt)"
        r'(?: (?:really|very|so|pretty|quite|super|kind of|kinda|a bit|a little|bit|little))*'
        r' ([a-z]+)',
      ).firstMatch(s) ??
      RegExp(r'^(?:my )?mood(?: is)? ([a-z]+)').firstMatch(s);
  if (m == null) return null;
  for (final MapEntry(key: mood, value: words) in _moodWords.entries) {
    if (words.contains(m[1])) return mood;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

/// "spent", "I have spent", "paid", "expense of" ... anywhere in the
/// sentence ("yesterday I spent 100 on food", "for lunch I paid 250").
final _spendCue = RegExp(
  r"\b(?:i |i've |ive |i have |i had |we |we've |we have )?(?:just |already |also )?"
  r'(?:spent|spend|spending|paid|pay|bought|purchased|gave|given|donated|'
  r'transferred|expenses?(?: of| for)?)\b\s*',
);

/// A plain "add"-style task cue without the word task/to-do/reminder.
final _addCue = RegExp(
  r'^(?:add|create|make|new|set)\b(?!.*\b(?:task|to-?do|todo|reminder)\b)',
);

/// Words that only make sense for money.
final _moneyWord = RegExp(
  r'(?:₹|\b(?:rs|inr|rupees?|bucks|spent|spend|paid|expenses?|money)\b)',
);

/// An amount (not a time or date) plus a money word or a spending
/// category. "add gym at 6 pm" and "add pay rent on 15 november" are tasks.
bool _looksLikeMoney(String s) {
  final rest = _notMoneyNumbers(s);
  return _amountRx.hasMatch(rest) &&
      (_moneyWord.hasMatch(rest) || _categoryFor(rest) != null);
}

/// [s] without numbers that are times, dates or quantities ("at 1 pm",
/// "15 november", "2 kg", "3 eggs"), so they're never read as rupees.
String _notMoneyNumbers(String s) {
  return s
      .replaceAll(RegExp(r'\b\d{1,2}(?::\d{2})? ?(?:am|pm)\b'), ' ')
      .replaceAll(RegExp(r'\b\d{1,2}:\d{2}\b'), ' ')
      .replaceAll(RegExp(r'\b(?:at|by|around) \d{1,2}\b'), ' ')
      .replaceAll(
        RegExp('\\b\\d{1,2}(?:st|nd|rd|th)?(?: of)? $_monthRx\\b'),
        ' ',
      )
      .replaceAll(
        RegExp('\\b$_monthRx(?: the)? \\d{1,2}(?:st|nd|rd|th)?\\b'),
        ' ',
      )
      .replaceAll(RegExp(r'\bthe \d{1,2}(?:st|nd|rd|th)\b'), ' ')
      .replaceAll(_quantity, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final _quantity = RegExp(
  r'\b\d+(?:\.\d+)? ?(?:kgs?|kilos?|g|gm|grams?|litres?|liters?|ltrs?|l|ml|'
  r'dozens?|pieces?|pcs|packets?|packs?|eggs?|bottles?|cups?|glasses?|'
  r'hours?|hrs?|minutes?|mins?|pages?|days?|weeks?|months?|years?|times|'
  r'people|persons?|kms?|steps|items?|boxes?)\b',
);
final _amountRx = RegExp(
  r'(?:₹ ?|\brs\.? ?|\binr ?)?\b(\d{1,3}(?:,\d{2,3})+|\d+)(?:\.(\d{1,2}))?(?: ?(k)\b)?'
  r'(?: ?(?:rupees?|rs\b|bucks|inr\b))?',
);

/// (category, keywords). Checked in this order, so "movie tickets" is Fun
/// rather than Travel and "grocery shopping" is Food.
const _categoryWords = [
  (
    ExpenseCategory.bills,
    r'bills?|electricity|internet|wifi|wi-fi|rent|recharge|'
        r'phone bill|mobile bill|broadband|gas|emi|insurance|subscription|dth',
  ),
  (
    ExpenseCategory.health,
    r'medicines?|pharmacy|chemist|doctor|hospital|clinic|'
        r'dentist|tablets|checkup|gym|physio',
  ),
  (
    ExpenseCategory.fun,
    r'movies?|cinema|netflix|party|games?|concert|outing|drinks|'
        r'bowling|show',
  ),
  (
    ExpenseCategory.travel,
    r'uber|ola|rapido|auto|cab|taxi|bus|metro|train|flight|'
        r'petrol|diesel|fuel|parking|toll|travel',
  ),
  (
    ExpenseCategory.food,
    r'lunch|dinner|breakfast|brunch|food|snacks?|coffee|tea|chai|'
        r'groceries|grocery|restaurant|swiggy|zomato|pizza|burger|meal|cafe|juice|'
        r'fruits?|vegetables|milk|sandwich(?:es)?|biscuits?|bread|eggs?|maggi|'
        r'samosas?|dosa|biryani|ice ?cream|chocolates?|cake|dessert|tiffin|'
        r'thali|momos?|paratha|noodles|vada pav|pani ?puri',
  ),
  (
    ExpenseCategory.shopping,
    r'shoes|clothes|shirt|t-shirt|tshirt|dress|jeans|amazon|'
        r'flipkart|myntra|shopping|bag|gift|headphones|electronics',
  ),
];

ExpenseCategory? _categoryFor(String s) {
  for (final (category, words) in _categoryWords) {
    if (RegExp('\\b(?:$words)\\b').hasMatch(s)) return category;
  }
  return null;
}

ExpenseDraft? _expense(String said, DateTime now) {
  final s = _notMoneyNumbers(said);
  final cue = _spendCue.firstMatch(s);
  final amountMatch = _amountRx.firstMatch(s);
  if (amountMatch == null) return null;

  // Without a cue, accept "200 rupees for lunch with friends" (a money
  // word) or short "uber 180" / "lunch 250" phrases naming a category.
  if (cue == null && !_moneyWord.hasMatch(s)) {
    final words = s.split(' ').length;
    if (words > 6 || _categoryFor(s) == null) return null;
  }

  final whole = amountMatch[1]!.replaceAll(',', '');
  final decimals = (amountMatch[2] ?? '').padRight(2, '0');
  var paise = int.parse(whole) * 100 + int.parse(decimals);
  if (amountMatch[3] == 'k') paise *= 1000;
  if (paise <= 0) return null;

  final t = _Text(s);
  if (cue != null) t.take(_spendCue);
  t.take(_amountRx);
  t.take(RegExp(r'\b(?:rupees?|rs|bucks|money|expenses?)\b'));
  var date = dateOnly(now);
  if (t.take(RegExp(r'\bday before yesterday\b')) != null) {
    date = addDays(date, -2);
  } else if (t.take(RegExp(r'\byesterday\b')) != null) {
    date = addDays(date, -1);
  } else {
    t.take(RegExp(r'\btoday\b'));
  }
  var note = t.value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final noteConnector = RegExp(
    r'^(?:on|for|at|in|towards|to)\b\s*|\s*\b(?:on|for|at|in|to)$',
  );
  while (noteConnector.hasMatch(note)) {
    note = note.replaceAll(noteConnector, '').trim();
  }

  return ExpenseDraft(
    amount: paise,
    category: _categoryFor(s) ?? ExpenseCategory.other,
    note: _capitalise(note),
    date: date,
  );
}

/// Two or more amounts in one sentence -> one expense per amount.
///
/// Speech usually comes without commas ("spent 100 on food 200 on travel
/// and 50 on coffee"), so items are cut at the amounts, not at punctuation:
/// if the sentence starts with an amount, each item is an amount plus the
/// words after it; otherwise ("food 100 travel 200") the words before it.
List<ExpenseDraft>? _expenses(String s, DateTime now) {
  // A day said once ("yesterday I spent ...") applies to every item.
  var body = s;
  var day = '';
  final dayMatch = RegExp(r'\b(?:day before yesterday|yesterday|today)\b')
      .firstMatch(body);
  if (dayMatch != null) {
    day = dayMatch[0]!;
    body = body.replaceRange(dayMatch.start, dayMatch.end, ' ');
  }
  body = body.replaceAll(RegExp(r'\s+'), ' ').trim();

  final cue = _spendCue.firstMatch(body);
  if (cue != null) {
    body = body.replaceRange(cue.start, cue.end, ' ');
  }
  body = body
      .replaceAll(RegExp(r'\b(?:rupees?|rs|bucks|money|expenses?)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  body = _notMoneyNumbers(body);
  final amounts = _amountRx.allMatches(body).toList();
  if (amounts.length < 2) return null;

  final amountFirst = body.substring(0, amounts.first.start).trim().isEmpty;
  final items = <String>[];
  for (var i = 0; i < amounts.length; i++) {
    final a = amounts[i];
    final String words;
    if (amountFirst) {
      final end = i + 1 < amounts.length ? amounts[i + 1].start : body.length;
      words = body.substring(a.end, end);
    } else {
      final start = i == 0 ? 0 : amounts[i - 1].end;
      words = body.substring(start, a.start);
    }
    items.add('${a[0]} ${_trimJoiners(words)}');
  }
  // Without "spent"/"paid", every item must name a known category, so a
  // task like "call 2 people at 5" never turns into money.
  // Without "spent"/"paid": at least one item names a category and every
  // amount is a real one ("coffee 120 and sandwich 180").
  if (cue == null &&
      (items.every((i) => _categoryFor(i) == null) ||
          amounts.any((a) => int.parse(a[1]!.replaceAll(',', '')) < 10))) {
    return null;
  }

  final drafts = <ExpenseDraft>[];
  for (final item in items) {
    final draft = _expense('spent $item $day'.trim(), now);
    if (draft == null) return null;
    drafts.add(draft);
  }
  return drafts;
}

/// Drops "and", "then", "also", "plus" and commas at both ends.
String _trimJoiners(String words) {
  final joiner = RegExp(r'^(?:,|and|then|also|plus|&)(?=\s|$)\s*');
  final joinerEnd = RegExp(r'\s*(?:,|\band|\bthen|\balso|\bplus|&)$');
  var t = words.trim();
  while (true) {
    final next = t.replaceFirst(joiner, '').replaceFirst(joinerEnd, '').trim();
    if (next == t) return t;
    t = next;
  }
}

// ---------------------------------------------------------------------------
// Habits (only finished things: "studied", not "study tomorrow")
// ---------------------------------------------------------------------------

LogHabit? _habit(String s) {
  if (RegExp(r'\bwater\b').hasMatch(s) &&
      RegExp(r'\b(?:drank|drunk|had|drink|drinking|finished|glass|glasses)\b')
          .hasMatch(s)) {
    final n = RegExp(r'(\d+) (?:glass|glasses|cups?|bottles?)\b').firstMatch(s);
    return LogHabit(HabitKeys.water, n == null ? 1 : int.parse(n[1]!));
  }
  if (RegExp(
    r'\b(?:done with (?:the |my )?(?:gym|workout)|finished (?:my |the )?(?:workout|gym)|'
    r'worked out|did (?:my |a |the )?workout|went to (?:the )?gym|gym done|workout done|'
    r'exercised|did (?:my )?exercise)\b',
  ).hasMatch(s)) {
    return const LogHabit(HabitKeys.workout);
  }
  if (RegExp(
    r'\b(?:studied|done studying|finished studying|did (?:my )?study|study done)\b',
  ).hasMatch(s)) {
    return LogHabit(HabitKeys.study, _minutes(s));
  }
  if (RegExp(
    r'\b(?:meditated|did (?:my |some )?meditation|done (?:with )?meditat(?:ing|ion)|'
    r'finished meditat(?:ing|ion)|meditation done)\b',
  ).hasMatch(s)) {
    return const LogHabit(HabitKeys.meditate);
  }
  if (RegExp(
    r'\b(?:read \d+ pages?|finished reading|done reading|did (?:my )?reading|'
    r'read for \d+|read a chapter|reading done)\b',
  ).hasMatch(s)) {
    return const LogHabit(HabitKeys.read);
  }
  return null;
}

/// Minutes in "45 minutes", "1.5 hours", "an hour", "half an hour".
int? _minutes(String s) {
  if (RegExp(r'\b(?:an hour and a half|1 and a half hours?)\b').hasMatch(s)) {
    return 90;
  }
  if (RegExp(r'\bhalf an hour\b').hasMatch(s)) return 30;
  final hours = RegExp(r'(\d+(?:\.\d+)?) ?(?:hours?|hrs?)\b').firstMatch(s);
  if (hours != null) return (double.parse(hours[1]!) * 60).round();
  if (RegExp(r'\ban hour\b').hasMatch(s)) return 60;
  final mins = RegExp(r'(\d+) ?(?:minutes?|mins?)\b').firstMatch(s);
  if (mins != null) return int.parse(mins[1]!);
  return null;
}

// ---------------------------------------------------------------------------
// Confirmation text
// ---------------------------------------------------------------------------

const _habitNames = {
  HabitKeys.water: 'Water',
  HabitKeys.workout: 'Workout',
  HabitKeys.study: 'Study',
  HabitKeys.meditate: 'Meditate',
  HabitKeys.read: 'Read',
};

/// A note that only repeats the category ("Shopping · \"Shopping\"") is
/// left out.
bool _noteAddsInfo(ExpenseDraft d) =>
    d.note.isNotEmpty && d.note.toLowerCase() != d.category.label.toLowerCase();

/// One line for the "I'll save: ..." card.
String describeCommand(VoiceCommand c, DateTime now) {
  final today = dateOnly(now);
  switch (c) {
    case AddTask(:final draft):
      return [
        'Task: "${draft.title}"',
        if (draft.dueDate != null)
          dueLabel(draft.dueDate, draft.dueTime, today),
        if (draft.priority == TaskPriority.high) 'High priority',
        if (draft.priority == TaskPriority.low) 'Low priority',
        draft.list.label,
        if (draft.reminder) 'With reminder',
      ].join(' · ');
    case AddExpense(:final draft):
      return [
        'Spend: ${formatRupees(draft.amount)}',
        draft.category.label,
        if (_noteAddsInfo(draft)) '"${draft.note}"',
        dueLabel(draft.date, null, today),
      ].join(' · ');
    case LogHabit(:final habitKey, :final amount):
      final name = _habitNames[habitKey] ?? habitKey;
      if (amount == null) return '$name: done today';
      if (habitKey == HabitKeys.water) {
        return '$name: +$amount ${amount == 1 ? 'glass' : 'glasses'}';
      }
      return '$name: +$amount min';
    case AddExpenses(:final drafts):
      final total = drafts.fold<int>(0, (sum, d) => sum + d.amount);
      return [
        '${drafts.length} spends, ${formatRupees(total)} in total',
        for (final d in drafts)
          [
            formatRupees(d.amount),
            d.category.label,
            if (_noteAddsInfo(d)) '"${d.note}"',
          ].join(' · '),
        dueLabel(drafts.first.date, null, today),
      ].join('\n');
    case SetMood(:final mood):
      return 'Today\'s mood: ${mood.label}';
    case AskPetal():
      return 'Question';
    case NotUnderstood():
      return 'Sorry, I didn\'t catch that';
  }
}
