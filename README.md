# Women Safety App (WSA) 🛡️

A comprehensive personal safety and emergency response mobile application built with **Flutter**, powered by a **Node.js/Express** and **MongoDB** backend. The application provides instant distress signaling, background evidence capture, live location tracking, and guardian alerting.

---

## 🌟 Key Features

### For Users
- **🚨 Instant SOS Trigger**: One-tap emergency activation with haptic feedback and optional countdown cancellation.
- **🎙️ Voice-Activated Distress**: Hands-free voice trigger detection for emergency situations.
- **📸 Silent Evidence Capture**: Automatically captures front and rear camera snapshots during an alert and uploads them securely.
- **📍 Real-Time GPS Tracking**: Streams accurate live coordinates and Google Maps location links to guardians.
- **📱 Automated Emergency SMS**: Dispatches urgent SMS messages with live location details to saved emergency contacts.
- **📞 Fake Call Simulator**: Discreetly exit uncomfortable situations with a realistic simulated incoming call.
- **🛡️ Safe Route & Status Check**: Lets users notify guardians of safety status with a single tap.

### For Guardians
- **🔔 Live Emergency Alerts**: Real-time push notifications when a ward triggers an SOS.
- **🗺️ Live Map Tracking**: View real-time location and movement history of the user.
- **📷 Incident Evidence Viewer**: Inspect captured camera photos and timestamped incident details.
- **👥 Multi-Ward Management**: Monitor multiple family members or wards from a single guardian dashboard.

---

## 🏗️ Architecture

```
├── lib/
│   ├── models/            # Data models (AppUser, EmergencyAlert, GuardianContact)
│   ├── providers/         # State management (AppState ChangeNotifier)
│   ├── screens/
│   │   ├── auth/          # Login & Signup screens
│   │   ├── guardian/      # Guardian home & live alert dashboard
│   │   ├── user/          # User SOS home, triggers & contacts
│   │   └── role_selection_screen.dart
│   ├── services/          # Core hardware & API services
│   │   ├── api_service.dart
│   │   ├── camera_service.dart
│   │   ├── emergency_service.dart
│   │   ├── location_service.dart
│   │   ├── notification_service.dart
│   │   ├── sms_service.dart
│   │   └── voice_service.dart
│   ├── theme/             # Material 3 design tokens & theme
│   └── main.dart          # App entry point
├── backend/
│   ├── server.js          # Express API server & MongoDB connection
│   └── package.json       # Backend dependencies
└── assets/                # App icons, illustrations, and media
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.19+ recommended)
- [Node.js](https://nodejs.org/) (v18+ recommended)
- [MongoDB](https://www.mongodb.com/) (local instance or MongoDB Atlas)
- Android Studio / VS Code with Flutter extensions

---

### 1. Backend Setup

```bash
cd backend
npm install
npm start
```
By default, the server runs on `http://localhost:5000` (or `http://10.0.2.2:5000` for Android Emulator).

---

### 2. Mobile App Setup

1. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Configure API Endpoint**:
   Update the backend base URL in `lib/services/api_service.dart` to your local machine IP or server address.

3. **Run on Device / Emulator**:
   ```bash
   flutter run
   ```

---

## 🔒 Permissions Configured

- **Location**: Fine and background location tracking (`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`)
- **Camera**: Silent dual-camera capture (`CAMERA`)
- **Microphone**: Voice trigger detection (`RECORD_AUDIO`)
- **SMS**: Emergency SMS dispatch (`SEND_SMS`)
- **Internet**: REST API communication (`INTERNET`)

---

## 👨‍💻 Author

- **Krishnakumar** - [@krishnakumar-2001](https://github.com/krishnakumar-2001)

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
