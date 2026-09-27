# Study Nova 🌟
> Intelligent Study & Learning Companion built with Flutter and Gemini AI.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![RevenueCat Shipaton 2026](https://img.shields.io/badge/RevenueCat-Shipaton%202026-blue)](https://revenuecat-shipaton-2026.devpost.com/)
[![Category: Next Gen Award](https://img.shields.io/badge/Category-Next%20Gen%20Award-orange)](https://revenuecat-shipaton-2026.devpost.com/)

Submitted for the **Next Gen Award** at **RevenueCat Shipaton 2026**.

---

## 📱 Features

- **Smart Inbox**: Import lecture slides, documents (PDF, DOCX, CSV), and scan printed notes with on-device OCR (Google ML Kit).
- **Audio & Lecture Recording**: Live lecture recording, audio playback, and speech-to-text note capture.
- **TalkBack AI Voice Tutor (PRO)**: Interactive conversational AI study companion with text-to-speech for vocal retention practice.
- **Study Canvas**: 3D flip flashcards, active recall confidence rating, and synthesized study guides.
- **My Space**: Study streak tracker, weekly study hours graph, task calendar, and customizable theme settings.

---

## 💳 RevenueCat Monetization Integration

Study Nova features full monetization integration with RevenueCat SDK (`purchases_flutter: ^10.0.0` & `purchases_ui_flutter: ^10.0.0`):
- **Real-time Entitlement Verification**: Gating the interactive **TalkBack AI Voice Tutor** behind the `APP HATCH Pro` entitlement.
- **Paywall UI**: Powered by `RevenueCatUI.presentPaywall()` with customizable templates and native Android/iOS sheets.
- **Customer Center**: In-app self-serve subscription management, restore purchases, and cancellation flow via `RevenueCatUI.presentCustomerCenter()`.
- **Reactive Subscription Sync**: Global listener notifying the entire app in real time when entitlement status changes.

---

## 🚀 Getting Started & Testing

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12+ recommended)
- Android Studio / VS Code with Flutter extension
- An Android device or emulator (Android SDK 21+)

### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/studynova.git
cd studynova
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure API Keys

Study Nova uses **Google Gemini** for intelligent flashcard creation, lecture summarization, and AI tutoring, alongside **RevenueCat** for subscription management.

Copy the example configuration file:
```bash
cp api_keys.example.json api_keys.json
```
Edit `api_keys.json` with your credentials:
```json
{
  "GEMINI_API_KEY": "AIzaSy...",
  "RC_GOOGLE_KEY": "goog_...",
  "RC_APPLE_KEY": "appl_...",
  "RC_ENTITLEMENT_ID": "APP HATCH Pro"
}
```
*(Note: `api_keys.json` is automatically gitignored and will never be committed).*

### 4. Run the App

#### Option A: Using the config file (Recommended)
```bash
flutter run --dart-define-from-file=api_keys.json
```

#### Option B: Passing keys inline via CLI
```bash
flutter run \
  --dart-define=GEMINI_API_KEY="your_gemini_api_key" \
  --dart-define=RC_GOOGLE_KEY="goog_your_google_api_key" \
  --dart-define=RC_APPLE_KEY="appl_your_apple_api_key" \
  --dart-define=RC_ENTITLEMENT_ID="APP HATCH Pro"
```

### 5. Running Automated Tests
```bash
flutter test --dart-define-from-file=api_keys.json
```

---

## 📁 Project Architecture

```
lib/
├── main.dart                      # App entry point, theme & RevenueCat initialization
├── services/
│   ├── paywall_manager.dart       # RevenueCat configuration, paywall presentation, entitlement streams
│   ├── gemini_service.dart        # Gemini AI study assistant & lecture summarization
│   ├── isar_service.dart          # Local database storage for notes and study sets
│   ├── theme_service.dart         # Dynamic color schemes & dark/light theme persistence
│   └── tts_service.dart           # Text-to-speech audio service for TalkBack
├── ui/
│   ├── home_page.dart             # Main navigation hub (Smart Inbox, Canvas, TalkBack, Space)
│   ├── paywall_screen.dart        # RevenueCat Paywall & Customer Center launcher UI
│   ├── talkback_screen.dart       # Pro-gated AI tutor voice interface
│   ├── smart_inbox_screen.dart    # OCR, file import, audio recording
│   ├── study_canvas_screen.dart   # Interactive flashcards & study notes
│   └── my_space_screen.dart       # Streaks, study analytics, calendar, & settings
└── models/                        # Isar entity models (Notes, Flashcards, Tasks)
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


