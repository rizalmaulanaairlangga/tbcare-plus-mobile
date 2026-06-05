# TBCare+

TBCare+ is a tuberculosis early-detection expert system mobile app built with **Flutter**. It provides symptom-based screening, certainty-factor assessment, and personalized health insights.

## Features

- **Authentication** — Login, registration, guest mode with Supabase JWT. Sessions persist
  across restarts and the access token is **silently refreshed** in the background; the user
  is only returned to login if the refresh token itself is rejected.
- **Quick Check & Full Assessment** — Two-tier TB screening with wizard-guided forms
- **Expert System Scoring** — Cross-TB-type certainty factor calculation
- **Assessment History** — Session-grouped history with detailed symptom insights
- **Profile Management** — Edit profile, change password, profile picture upload
- **Offline Support** — Guests can complete and save an assessment locally; question
  configs are cached after first fetch as an offline fallback. Authenticated actions
  require connectivity and persist to the server.

## Tech Stack

- **Framework**: Flutter (Dart 3.12+)
- **Auth**: Supabase JWT with automatic (silent) token refresh
- **HTTP**: `http`
- **Local Storage**: `shared_preferences` (tokens, cached configs, guest assessment)
- **Connectivity**: `connectivity_plus` (offline pre-flight gating)
- **Files & Images**: `file_picker`, `image` (profile picture pick/encode)
- **Misc**: `intl` (date formatting), `url_launcher` (external links)

## Getting Started

### Prerequisites

- Flutter SDK 3.22+
- Android Studio or Xcode

### Setup

```bash
git clone https://github.com/rizalmaulanaairlangga/tbcare-plus-mobile.git
cd tbcare-plus-mobile
flutter pub get
```

### Backend Configuration

Copy `.env.example` to `.env` and fill in your backend URL:

```bash
cp .env.example .env
```

The `.env` file contains three settings:

```env
API_BASE_URL=https://your-backend-api.azurewebsites.net
API_LOCAL_URL=http://localhost:5181
USE_LOCAL=false
```

For local development, set `USE_LOCAL=true` to point the app at `http://localhost:5181` (Android emulator users automatically get `http://10.0.2.2:5181`).

### Run

```bash
flutter run
```

## Build Release

```bash
flutter build apk --split-per-abi
```

APKs output to `build/app/outputs/flutter-apk/`.

For keystore setup, see the [Flutter Android deployment guide](https://docs.flutter.dev/deployment/android).

## Project Structure

```
lib/
├── core/
│   ├── constants/    # API endpoints, base URL toggle, prefs keys
│   ├── models/       # Data models, JSON serializers
│   ├── services/     # Auth/assessment API, storage, connectivity, guest
│   │                 #   assessment, session, asset caching. Authenticated
│   │                 #   calls go through authorized_client (auto-attaches the
│   │                 #   Bearer token) + token_service (silent refresh-and-retry)
│   ├── utils/        # NetworkException, image & URL helpers
│   ├── theme/        # Colors, text styles, theme
│   └── widgets/      # Shared widgets (HomeHeader, AppTopBar)
├── features/
│   ├── auth/         # Cover, login, register pages
│   ├── home/         # Home dashboard
│   ├── assessment/   # Quick check & full assessment wizards
│   ├── result/       # Assessment results with scoring
│   ├── history/      # History list, detail, symptom insights
│   ├── profile/      # Profile view, edit, change password
│   └── about/        # About & help page
└── routes/           # Named route definitions
```
