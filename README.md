# Daily Roadmap 🎯

[![Flutter](https://img.shields.io/badge/Flutter-3.27.4-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5.0-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-4EAA25?logo=android&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**Daily Roadmap** is a productivity and developer-learning mobile application built with Flutter. It transforms expansive developer roadmaps (from [roadmap.sh](https://roadmap.sh)), Anki flashcard decks, and custom CSV learning plans into achievable, bite-sized daily practice checkpoints.

Never get overwhelmed by a 200-topic syllabus again. Stay consistent, build daily momentum, and keep your learning streak alive.

---

## ✨ Key Features

### 🗺️ Dynamic Roadmap Tracking
- **roadmap.sh Integration:** Paste any [roadmap.sh](https://roadmap.sh) URL (e.g. Frontend, Backend, DevOps, AI Engineer, SQL, Docker, Python) or choose from popular quick-picks to automatically parse topics and sequence your learning.
- **Daily Focus Checkpoint:** Delivers today's topic for each active roadmap so you always know exactly what to practice next.
- **Progress Tracking:** Interactive progress rings and percentage indicators across all active subjects.

### 🃏 Anki (.apkg) & CSV Import Support
- **Anki Flashcard Engine:** Built-in parser for `.apkg` files (SQLite + Zip archive extraction). Study cards directly with spaced repetition options (*Again*, *Hard*, *Good*, *Easy*).
- **CSV / TSV Support:** Import custom question/answer cards or topic checklists effortlessly.
- **Custom Roadmap Creator:** Manually type or paste your own syllabus with automatic topic ordering and index detection.

### 🔔 Multiple Practice Reminders & Smart Alarms
- **Multi-Alert Scheduling:** Configure multiple practice times throughout the day (e.g. *Morning Practice 🌅 9:00 AM*, *Afternoon Sprint ☀️ 2:00 PM*, *Evening Review 🌙 8:00 PM*, or custom times).
- **Exact Alarms (Android 14+):** Configured with `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, and native Android `AlarmManager` broadcast receivers to ensure reminders trigger even in deep Doze mode.
- **Battery Optimization Bypass:** Native channel integration to request battery exemption and prevent aggressive OEM background killing.
- **Heads-Up Notifications:** MAX-priority notification channels (`Importance.max`) with sound, vibration, and in-app instant feedback.

### 🔥 Streak Counter & Weekly Consistency
- **Daily Streak System:** Tracks consecutive days of practice with fire indicators and celebratory milestones.
- **7-Day Consistency Tracker:** Visual weekly activity dots showing your study habit over the past week.
- **Overall Stats Bar:** Quick dashboard view of completed topics, tracking roadmaps, total library size, and active streak days.

### 🎨 Clean Dark Aesthetic
- **Minimalist Workout-Inspired Palette:** Dark canvas (`#06060B`) with layered surface cards and high-contrast mint accents (`#00E599`).
- **Responsive Layouts:** Designed to adapt cleanly across screen sizes and aspect ratios without header overlap or clipped actions.
- **Haptic Feedback:** Tactile vibrations on actions, completions, and time selections.

---

## 📱 Screenshots & Overview

| Daily Checkpoints & Streaks | Multiple Practice Reminders | Flashcard & Topic Detail |
|:---:|:---:|:---:|
| Bite-sized daily tasks with active streaks | Configurable daily sessions & exact alarms | Deep-dive topic views & flashcard study |

---

## 🛠️ Architecture & Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (v3.27.4) & Dart (v3.5.0)
- **State Management:** [`provider`](https://pub.dev/packages/provider) (MVVM / ChangeNotifier pattern)
- **Local Storage:**
  - [`shared_preferences`](https://pub.dev/packages/shared_preferences) for user preferences and roadmap metadata
  - [`sqflite`](https://pub.dev/packages/sqflite) for Anki deck SQLite database parsing
- **Notifications & Scheduling:**
  - [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) (v19.5.0)
  - [`timezone`](https://pub.dev/packages/timezone) with native Kotlin timezone synchronization
- **File Parsing & Utilities:**
  - [`archive`](https://pub.dev/packages/archive) for `.apkg` zip extraction
  - [`file_picker`](https://pub.dev/packages/file_picker) for importing local files
  - [`http`](https://pub.dev/packages/http) for fetching roadmap.sh syllabus data
  - [`url_launcher`](https://pub.dev/packages/url_launcher) for external resource links
  - [`google_fonts`](https://pub.dev/packages/google_fonts) for typography

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.5.0)
- [Android SDK](https://developer.android.com/studio) (API 34 / Android 14 recommended)
- A connected Android / iOS physical device or emulator

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Shubham-Bhayaje/Daily-Roadmap.git
   cd Daily-Roadmap
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app in debug mode:**
   ```bash
   flutter run
   ```

4. **Build release APK (Android):**
   ```bash
   flutter build apk --release
   ```
   The built APK will be generated at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 📂 Project Structure

```text
daily_roadmap/
├── android/                   # Native Android configuration, receivers & permissions
│   └── app/src/main/
│       ├── AndroidManifest.xml # Notification receivers, alarms & wake lock
│       └── kotlin/.../
│           └── MainActivity.kt# Platform channels for battery & timezone
├── assets/                    # Static assets, branding logo & sample decks
│   ├── images/logo.png
│   └── decks/
├── lib/
│   ├── models/                # Data models (Roadmap, Topic, DailyPractice)
│   ├── providers/             # AppProvider (state management & data persistence)
│   ├── screens/               # UI Screens (HomeScreen, Detail, Add, Study)
│   ├── services/              # Parsers (Roadmap, Anki, CSV) & NotificationService
│   ├── theme/                 # AppTheme & AppColors (dark theme styling)
│   ├── widgets/               # Reusable modular UI components
│   └── main.dart              # Application entry point & provider injection
└── pubspec.yaml               # Project dependencies and asset declarations
```

---

## ⚙️ Permissions Used

| Permission | Purpose |
|:---|:---|
| `POST_NOTIFICATIONS` | Send daily study reminder notifications (Android 13+) |
| `SCHEDULE_EXACT_ALARM` | Schedule exact alarm triggers for morning, afternoon, and evening practice |
| `USE_EXACT_ALARM` | Ensures timely alarm delivery without Doze delay |
| `WAKE_LOCK` | Wakes the device briefly to display the practice notification |
| `RECEIVE_BOOT_COMPLETED` | Automatically reschedules your daily alarms when your phone restarts |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevents aggressive manufacturer battery managers from killing reminders |

---

## 🤝 Contributing

Contributions, feature suggestions, and feedback are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

**Made with ❤️ for disciplined daily learning.**
