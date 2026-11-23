# 🌸 Petal

**A voice-first, offline and private life planner for Android.**

Petal keeps tasks, money, habits and mood in one calm, pastel app. You can just talk to it ("I spent 250 on lunch and 100 on auto"), ask it questions ("How much did I spend this week?"), and it answers out loud. Everything runs on the phone: there's no account, no ads and no internet, and even voice recognition happens on the device.

I built it for myself, because as a developer I can make the app I want to use every day.

<!-- Add screenshots to docs/screenshots/ and uncomment:
<p align="center">
  <img src="docs/screenshots/today.png" width="220" alt="Today screen">
  <img src="docs/screenshots/voice.png" width="220" alt="Voice">
  <img src="docs/screenshots/money.png" width="220" alt="Money">
  <img src="docs/screenshots/me.png" width="220" alt="Me and insights">
</p>
-->

---

## ✨ Features

### 🎙️ Voice first (works offline)
- Add tasks, spends, habits and mood by talking: *"Remind me to call mom tomorrow at 6"*, *"Drank 2 glasses of water"*, *"Feeling great"*.
- **Several spends in one sentence:** *"Spent 100 on food, 200 on travel and 50 on coffee"* saves three spends.
- Understands everyday Indian English: "spended", "auto", "chai", "two hundred fifty", "4 30 pm".
- Never confuses times, dates or quantities with money ("lunch at 1 pm" is a task, not ₹1).
- **Ask Petal:** *"How much did I spend this week?"*, *"What's on tomorrow?"*, *"How much budget is left?"*, *"What's my workout streak?"*. Petal answers on screen and out loud with the phone's offline voice.
- Nothing is saved without a confirmation card, and every save can be undone.

### 🔥 Habits that you earn
- Water (tap a glass), Workout, Study, Meditate and Read, with streaks and a weekly grid.
- **Add your own habits** (Skincare, Journal, Sleep by 11...) as a tick, minutes or a count, each with a matching icon.
- **Earn your streak:**
  - **Workout** counts only after real movement: 1,000 steps for a walk, or a 20-minute gym session (read from the phone's step counter, only while a session is open).
  - **Study** uses a **face-down focus timer**: the timer runs only while the phone lies face down, and leaving the app pauses it.
- Weekly workout and study plan.

### ✅ Tasks
- Lists (Work, Personal, Study, Shopping), priorities, due dates and times, and subtasks.
- Reminders as notifications, with a choice of how early.
- Week strip, filters, and "move all overdue to today" with Undo.

### 💰 Money
- Spends by category, with a weekly or monthly donut chart.
- Monthly budgets per category, plus a **warning the moment a spend puts you near or over a budget**.
- Export to CSV.

### 😊 Mood and insights
- A daily mood check-in and a monthly mood calendar.
- A "Your week so far" card: tasks done, habits kept, money spent and the mood of the week.
- **Petal noticed:** patterns found in your own data, on the phone. For example:
  - *"You feel happier on days you work out."*
  - *"You spend about 2.5x more a day on weekends."*
  - *"Your habits slip most on Mondays."*

### 📱 And also
- A home-screen widget with today's tasks and a "+ glass" button.
- Water reminders.
- Backup and restore to a single file.
- Three themes: Lavender, Peach and Mint.
- A first-launch welcome.
- TalkBack labels and large-text support.

---

## 🔒 Private by design

| | |
|---|---|
| Internet | **None.** The app has no `INTERNET` permission. |
| Account | None. |
| Voice | On-device recognition only. Audio never leaves the phone. |
| Sensors | The step counter and motion sensor are read **only while a session you started is open**. |
| Data | A local SQLite database in the app's private storage. Backups are files that you save yourself. |

---

## 🛠️ Tech stack

- **Flutter** (Dart), Android 8.0+ (minSdk 26)
- **Riverpod** for state management
- **Drift** (SQLite) for the local database
- **speech_to_text** for on-device speech recognition
- **flutter_local_notifications** for reminders
- Small native **Kotlin** pieces for the home-screen widget, the step counter, face-down detection, text-to-speech and file saving (no extra plugins)
- Bundled fonts (Nunito and Pacifico, both OFL), so nothing loads from the web

### Project structure

```
lib/
  core/       theme, shell (nav bar), platform bridges, utils, shared widgets
  data/       database (Drift), models, repositories, sample/demo data
  features/
    today/    Today screen, greeting, home-screen widget sync
    tasks/    tasks, reminders, week strip
    money/    spends, budgets, charts, CSV
    habits/   habits, streaks, earn-your-streak sessions
    mood/     check-in, calendar
    me/       weekly snapshot, insights, settings, backup
    voice/    speech, parser, Ask Petal answers
    welcome/  first-launch slides
android/      Kotlin: widget, sensors, text-to-speech, file saving
test/         unit and widget tests
```

The voice parser (`lib/features/voice/logic/voice_parser.dart`) is plain Dart with no AI model. It turns a sentence into a task, spend(s), habit, mood or question with rules that are tested by over 100 cases.

---

## 🚀 Run it

```bash
flutter pub get
flutter run            # with an Android phone connected (USB debugging on)
flutter test           # 279 tests
```

Debug builds include **Settings → Load demo data** (two months of realistic data) for trying the app out or recording demos.

To make a release build you need your own signing key. See [Flutter's guide](https://docs.flutter.dev/deployment/android#sign-the-app); `key.properties` and `*.jks` are git-ignored.

**For voice:** on the phone, install an offline speech pack (Settings → System → Languages → On-device speech recognition). English (India) works best for Indian accents.

---

## 🗺️ Ideas for next

- Dark mode
- Repeating tasks and bills
- Tap a reminder to open its task
- Swipe actions on tasks and spends
- A year-in-colour mood view

---
🎬 Full demo: [watch on LinkedIn](https://lnkd.in/p/gYpcvR6e)

Made with 🌸 by Khushi Sharma.
