# TBCare+ Mobile Application

TBCare+ Mobile is a premium, beautifully crafted early-detection tuberculosis expert system app built with **Flutter**. It provides a highly responsive, modern user experience using custom theme colors, smooth transition micro-animations, glassmorphism cards, and interactive expert assessment flows.

---

## ✨ Features

* **Complete Authentication Flows**: Fully functional Login and Registration interfaces connected directly to the ASP.NET backend.
* **Tuberculosis Assessment Expert System**: Comprehensive diagnostic questions mapping and checking symptoms with certainty factors.
* **Persistent Sessions**: Automatic storage of JWT authentication tokens and user profiles using `shared_preferences`.
* **Dynamic Diagnosis History**: History detail pages featuring interactive symptom insights and visual risk calculations.
* **Premium Glassmorphism & Scattered Aura UI**: Modern styling details following best visual design practices.

---

## 🛠️ Technology Stack

* **Framework**: Flutter (Dart ^3.11.0)
* **API Communication**: `http` package with built-in HTTP request timeout handling and exception mapping.
* **Local Persistence**: `shared_preferences` for quick, lightweight caching of tokens and user data.
* **Design Guidelines**: Highly responsive Material 3 components with fully customized color palettes (primary green accents, rich neutral grays, dynamic auras).

---

## ⚙️ Development Setup & Configuration

### 1. Backend Endpoint Configuration
Open `lib/core/constants/app_constants.dart` and verify the `baseUrl` configuration:
```dart
class AppConstants {
  // Use '10.0.2.2' for default Android Emulator to communicate with host localhost
  static const String baseUrl = 'http://10.0.2.2:5000';
  
  // Use your local network IP (e.g. 192.168.x.x) if running on physical Android/iOS devices
  // static const String baseUrl = 'http://192.168.1.15:5000';
}
```

### 2. Install Dependencies
Run the package manager from the `tbcare+_mobile` directory:
```bash
flutter pub get
```

### 3. Run the App
To start compiling and launching the app on your designated emulator or active physical device:
```bash
flutter run
```

---

## 📂 Project Architecture

```
lib/
├── core/
│   ├── constants/      # AppConstants holding REST API configurations
│   ├── models/         # UserModel and AuthResponse JSON serializers
│   ├── services/       # StorageService & AuthApiService wrappers
│   ├── theme/          # Custom color tokens, text styles, and theme schemes
│   └── widgets/        # Shared premium UI widgets
├── features/           # Feature-based modular structure
│   ├── auth/           # Login, registration, and cover pages
│   ├── home/           # Home dashboard and navigation
│   ├── assessment/     # Interactive diagnostic forms
│   ├── result/         # Certainty factor calculation results
│   ├── history/        # Previous assessment lists and details
│   └── profile/        # User accounts settings and profile updates
└── routes/             # AppRoutes and zero-delay route animations
```
