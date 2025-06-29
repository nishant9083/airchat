# AirChat

AirChat is a privacy-focused, local-first chat app built with Flutter. It enables users to discover, connect, and chat with nearby devices directly—no internet required. All communication is encrypted end-to-end.

---

## 🚀 Features

- **Nearby Discovery:** Find and connect with users around you using Android's Nearby Connections API.
- **Secure Messaging:** All messages are encrypted using AES-256 and ECDH key exchange. (To be implemented)
- **File Sharing:** Send files and media securely to connected peers.
- **Offline-First:** Works without internet; all data is stored locally and securely.
- **Modern UI:** Clean, intuitive interface with theming support.
- **Cross-Platform:** Runs on Android, iOS, Windows, macOS, and Linux (with platform-specific features).

---

## 🛠️ Tech Stack

| Component     | Technology                                 |
| ------------- | ------------------------------------------ |
| UI            | Flutter                                    |
| Comm Protocol | Android Nearby API (via Platform Channels) |
| Encryption    | AES-256, ECDH (Libsodium or custom)        |
| State Mgmt    | Provider/Bloc                              |
| Storage       | Hive/SQLite (Encrypted)                    |

---

## 🔹 Architecture (High-Level)

* **Flutter Frontend**
    * Initiates connection via platform channels
    * Displays chat UI and handles local logic
* **Android Native (Kotlin)**
    * Handles Nearby Advertising & Discovery
    * Sends/receives messages
* **Encryption Layer**
    * Keys are exchanged securely
    * Each message is encrypted before sending

---

## 🏛 Project Folder Structure

```
airchat/
  ├── android/           # Android native code (Kotlin, manifests)
  ├── ios/               # iOS native code (Swift, assets)
  ├── lib/               # Flutter/Dart source code
  │   ├── main.dart      # App entry point
  │   ├── models/        # Data models (ChatUser, ChatMessage, etc.)
  │   ├── services/      # Platform channels, connection logic
  │   ├── providers/     # State management (Provider)
  │   ├── ui/            # Screens and UI widgets
  │   ├── utility/       # Helpers, utilities
  │   └── widgets/       # Reusable widgets
  ├── assets/            # App icons, splash, images
  ├── test/              # Unit/widget tests
  ├── pubspec.yaml       # Flutter dependencies
  └── README.md          # Project documentation
```

---

## ⚡ Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x recommended)
- Android Studio/Xcode for mobile builds
- A device or emulator (Nearby API requires real device for full functionality)

### Setup
1. **Clone the repository:**
   ```sh
   git clone https://github.com/nishant9083/airchat.git
   cd airchat
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **(Optional) Generate icons and splash:**
   ```sh
   flutter pub run flutter_launcher_icons:main
   flutter pub run flutter_native_splash:create
   ```

### Running the App
- **Android:**
  ```sh
  flutter run -d android
  ```
- **iOS:**
  ```sh
  flutter run -d ios
  ```
- **Desktop (Windows/macOS/Linux):**
  ```sh
  flutter run -d windows  # or macos/linux
  ```
- **Web:**
  ```sh
  flutter run -d chrome
  ```

---

## 📱 Usage
- Launch the app on two or more devices.
- Set your display name when prompted.
- Tap the discover button to find nearby devices.
- Tap a user to connect and start chatting.
- Send text, images, videos, or files securely.
- Use the search bar to quickly find chats or users.

---

## 🤝 Contributing

Contributions are welcome! To contribute:
1. Fork the repository
2. Create a new branch (`git checkout -b feature/your-feature`)
3. Make your changes and commit (`git commit -am 'Add new feature'`)
4. Push to your fork (`git push origin feature/your-feature`)
5. Open a Pull Request

Please follow the existing code style and add tests where appropriate.

---

## 🛡️ License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Credits
- [Flutter](https://flutter.dev/)
- [Hive](https://docs.hivedb.dev/)
- [Provider](https://pub.dev/packages/provider)
- [Nearby Connections API](https://developers.google.com/nearby/connections/overview)
- All contributors and open-source libraries used.
