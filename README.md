# 💰 FinTrack Lite

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.16+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.1+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/platform-android%20|%20ios%20|%20linux%20|%20macos%20|%20windows%20|%20web-lightgrey?style=for-the-badge" alt="Platforms" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <b>A beautiful, privacy-first expense tracker that stays on your device.</b><br/>
  No accounts. No cloud. Just you and your money.
</p>

---

## ✨ Why FinTrack Lite?

Most expense trackers want your email, your data, and a monthly subscription. FinTrack Lite doesn't. Everything lives on your device — your transactions, your budgets, your habits. It's fast, it's offline, and it's yours.

Built with Flutter and Material You, it looks right at home on Android, iOS, and desktop. Track expenses, set budgets, spot spending patterns with smart insights, and keep a streak going — all without an internet connection.

---

## 🎯 Features

| Category                | What You Get                                                                                             |
| ----------------------- | -------------------------------------------------------------------------------------------------------- |
| 📊 **Dashboard**        | At-a-glance today's spending, monthly balance, weekly chart, and recent transactions — all on one screen |
| 💸 **Transactions**     | Log income and expenses in seconds. Search, filter by date or type, pull to refresh                      |
| 🗂️ **Categories**       | Comes with sensible defaults. Add, edit, or delete your own — full control                               |
| 📈 **Statistics**       | Drill into weekly, monthly, and yearly breakdowns. Pie charts, bar charts, line charts — pick your view  |
| 🔁 **Recurring**        | Set up daily, weekly, or monthly recurring transactions. Rent, salary, subscriptions — automate them     |
| 🎯 **Budgets**          | Set monthly spending limits per category. Get notified when you're close to the edge                     |
| 💡 **Smart Insights**   | Automatically surfaces patterns: biggest expense, category spikes, week-over-week changes                |
| 🔥 **Streaks**          | How many days in a row have you logged? Keep the streak alive                                            |
| 🌗 **Dark Mode**        | Full light and dark theme support with Material 3 dynamic colors on Android 12+                          |
| 📦 **Backup & Restore** | Export everything to JSON. Import it back when you switch phones. Your data, portable                    |
| 📄 **Export**           | Generate CSV or PDF reports for sharing or archiving                                                     |
| 🔐 **Biometric Lock**   | Optional fingerprint / face unlock to keep prying eyes out                                               |
| 🔔 **Notifications**    | Budget threshold alerts — no surprises at the end of the month                                           |

---

## 🧱 Tech Stack

| Layer                | Technology                                                            |
| -------------------- | --------------------------------------------------------------------- |
| **Framework**        | [Flutter](https://flutter.dev)                                        |
| **State Management** | [Riverpod](https://riverpod.dev) (code-gen with `riverpod_generator`) |
| **Local Database**   | [Hive](https://docs.hivedb.dev) — fast, NoSQL, pure-Dart              |
| **Charts**           | [fl_chart](https://pub.dev/packages/fl_chart)                         |
| **Routing**          | [go_router](https://pub.dev/packages/go_router)                       |
| **Fonts**            | [Google Fonts](https://pub.dev/packages/google_fonts) (Inter)         |
| **Code Generation**  | `build_runner` + `hive_generator` + `json_serializable`               |
| **Security**         | `local_auth` (biometrics) + `flutter_secure_storage`                  |
| **Notifications**    | `flutter_local_notifications`                                         |
| **Export**           | `csv` + `pdf` + `printing` + `share_plus`                             |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.1.0`
- Dart `>=3.1.0`
- An IDE (VS Code or Android Studio)

### Setup

```bash
# 1. Clone it
git clone https://github.com/your-username/fintrack_lite.git
cd fintrack_lite

# 2. Get dependencies
flutter pub get

# 3. Generate Hive adapters & Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# 4. Run it
flutter run
```

---

## 📁 Project Structure

```
lib/
├── main.dart                  # Entry point — initializes Hive, seeds defaults
├── app.dart                   # MaterialApp + theme setup (Material 3, dynamic colors)
├── models/                    # Data classes — Transaction, Category, Budget, RecurringRule
│   ├── transaction.dart
│   ├── category.dart
│   ├── budget.dart
│   └── recurring_rule.dart
├── providers/                 # Riverpod providers — state management layer
│   ├── transaction_provider.dart
│   ├── category_provider.dart
│   ├── stats_provider.dart
│   ├── insights_provider.dart
│   ├── budget_provider.dart
│   ├── recurring_provider.dart
│   ├── streak_provider.dart
│   ├── settings_provider.dart
│   └── theme_provider.dart
├── screens/                   # UI screens
│   ├── home_screen.dart       # Main dashboard with bottom navigation
│   ├── add_transaction_screen.dart
│   ├── stats_screen.dart      # Charts & analytics
│   ├── categories_screen.dart
│   ├── recurring_screen.dart
│   └── settings_screen.dart
└── services/                  # Business logic & platform services
    ├── storage_service.dart   # Hive CRUD operations
    ├── calculator_service.dart
    ├── insights_service.dart  # Smart insight generation
    ├── recurring_service.dart # Auto-creates transactions from rules
    ├── streak_service.dart    # Consecutive day tracking
    ├── backup_service.dart    # JSON export / import
    ├── export_service.dart    # CSV & PDF generation
    ├── notification_service.dart
    └── ...
```

---

## 🧠 Architecture

FinTrack Lite follows a **provider-first, service-backed** architecture:

```
┌─────────────────────────────────────┐
│  UI Layer (Screens & Widgets)       │
│  Reads state via Riverpod ref.watch │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Provider Layer (Riverpod)          │
│  Derives & caches reactive state    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Service Layer                      │
│  Pure Dart classes — business logic,│
│  calculations, side effects         │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Storage Layer (Hive Boxes)         │
│  categories | transactions          │
│  recurringRules | budgets | settings│
└─────────────────────────────────────┘
```

- **All data is local.** No network calls. No API keys needed.
- **Hive** stores typed objects directly — no SQL, no migrations, fast reads.
- **Riverpod** keeps the UI reactive without rebuilding the world on every change.
- Services are plain Dart classes — easy to test, easy to reason about.

---

## 🌍 Supported Platforms

| Platform | Status          |
| -------- | --------------- |
| Android  | ✅ Full support |
| iOS      | ✅ Full support |
| Linux    | ✅ Full support |
| macOS    | ✅ Full support |
| Windows  | ✅ Full support |
| Web      | ✅ Full support |

---

## 🤝 Contributing

Found a bug? Have an idea? PRs are welcome.

1. Fork the repo
2. Create a branch (`git checkout -b feature/cool-thing`)
3. Run `dart run build_runner build` after model changes
4. Commit and push
5. Open a PR

Keep it simple. Keep it offline. Keep it yours.

---

## 📝 License

MIT — do whatever you want. Just don't blame us if you spend too much on coffee.

---

<p align="center">
  <sub>Built with ☕ and Flutter</sub>
</p>
