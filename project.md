**Project Name:** AirChat (Peer-to-Peer Chat App Over Wi-Fi/Hotspot)

---

## 📊 Overview

A peer-to-peer messaging app that works entirely offline using Android's Nearby Connections API or Wi-Fi Direct. It enables chat and file sharing between nearby devices without the need for an internet connection or a central server.

---

## 🤖 Target Audience

* People in areas with poor/no internet connectivity
* Activists or journalists in surveillance-heavy regions
* Students in hostels/campuses
* Emergency responders

---

## 🚀 Goals & Objectives

* Enable chat over local communication protocols (Wi-Fi Direct/Nearby)
* Ensure all communication is secure and private
* Make it cross-platform (start with Android, then Flutter)
* Allow file sharing in a secure, efficient manner

---

## ⚙️ Features (Planned Phases)

### ✅ **Phase 1: MVP**

* Device Discovery via Nearby API
* Text chat (1-to-1)
* Realtime messaging (like Socket.io, but P2P)
* Basic chat UI

### 🔐 **Phase 2: Security**

* End-to-End Encryption
* Key exchange using ECDH
* Message verification (digital signature)

### 📁 **Phase 3: File Transfer**

* Send images, files via WiFi
* Progress indicators
* File size limits

### 🌐 **Phase 4: LAN Chat (Optional)**

* If both users on same router, auto-connect
* Use TCP sockets or WebRTC DataChannels

### 🧠 **Phase 5: Smartness**

* Group chat (multi-peer mesh)
* Chat history backup locally
* Language translation / emotion detection (mini AI)

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

* Flutter Frontend

    * Initiates connection via platform channels
    * Displays chat UI and handles local logic
* Android Native (Kotlin)

    * Handles Nearby Advertising & Discovery
    * Sends/receives messages
* Encryption Layer

    * Keys are exchanged securely
    * Each message is encrypted before sending

---

## 🏛 Project Folder Structure (Proposed)

```
airchat/
  lib/
    main.dart
    ui/
      home_screen.dart
      chat_screen.dart
    services/
      connection_service.dart
      encryption_service.dart
  android/
    app/
      src/
        main/
          kotlin/
            com/example/airchat/
              MainActivity.kt
              NearbyHandler.kt
```

---

---

## 🔧 Future Improvements

* Multiplatform support (iOS)
* QR code pairing
* Offline-first ML features
* App theming + customization

---

## 📓 References

* Android Nearby Connections API
* Flutter Platform Channels
* Libsodium (for encryption)
* Wi-Fi Direct APIs
* WebRTC Data Channels (for LAN)

---

Ready to begin implementation when you are! Let me know which module you'd like to start coding first.
