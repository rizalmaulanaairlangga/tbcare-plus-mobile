# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Auto-logout on token expiry**: Added `SessionService` class that clears local storage and uses `AppRoutes.navigatorKey` to programmatically redirect the user to the login page when a `401 Unauthorized` response is received from any authenticated API call.
- **`navigatorKey` global navigation**: Registered `GlobalKey<NavigatorState>` in `AppRoutes` and passed it to `MaterialApp` in `main.dart` to enable navigation from outside the widget tree (required for auto-logout).
- **Quick assessment save to Supabase**: `AssessmentApiService.submitAssessment()` reinstated and integrated into `ResultPage` — when a logged-in user completes a quick assessment, the result is submitted to `POST /api/v1/assessment/submit` for server-side storage.

### Fixed
- **Quick assessment card tap selection**: Wrapped symptom answer cards in `GestureDetector` on the `HomePage` so tapping anywhere on the card toggles the selection — previously required tapping the small `Switch` widget directly.
- **Double-entry prevention**: Backend integration ensures that if a logged-in user has already completed a full assessment, submitting a quick assessment will return the calculated result **without** saving a duplicate entry to the database.
- **Null safety type casting**: Fixed dynamic map cast compile-time error in `AssessmentApiService.fetchMostRecentAssessment()` where nullable `bestRl` was casted without a safety downcast check.

### Changed
- **Removed real-time percentage display** from quick assessment answer cards — score percentage is no longer shown while answering questions; results are only displayed on the results page after submission.
- **`AssessmentApiService`**: All authenticated endpoints (`submitAssessment`, `fetchHistory`, `fetchHistorySessions`, `fetchHistorySessionDetail`, `fetchHistoryDetail`) now intercept `401` responses and trigger `SessionService.logoutAndRedirectToLogin()` automatically.
- **`AuthApiService.fetchCurrentUser`**: Also intercepts `401` and delegates to `SessionService.logoutAndRedirectToLogin()`.
- **History Detail Dropdowns & Symptom Items**:
  - Restructured each TBC type card in the history detail screen to be a collapsible dropdown section using smooth `AnimatedCrossFade` transitions and arrow icon state toggle.
  - Restricted the symptom card title to exactly 2 lines with ellipsis to prevent long names from cluttering.
  - Eliminated the duplicated symptom name from the expanded child dropdown view so it is not repeated, displaying only the detailed description.
  - Integrated `ExpansionTileController` to programmatically collapse the symptom expansion card when tapping the "Mengerti" button.



### Added
- Close notification button (X) on the login page success banner after successful account creation.
- Functional **Registration & Login Logic Endpoints Integration**:
  - Converted `LoginPage` from a static mock to a fully functional `StatefulWidget` handling form inputs, controller disposal, login API submission, local storage persistence, and home page redirection.
  - Converted `RegisterPage` to a functional `StatefulWidget` supporting full name, email, password, confirm password validation, loading indicators, error banners, and automatic authentication on success.
  - Added `AuthApiService` wrapper for REST communication with ASP.NET backend (signup, login, logout, and handling custom server exceptions).
  - Added `StorageService` for persistent local storage of JWT Access/Refresh tokens and user profile state using `shared_preferences`.
  - Added `UserModel` and `AuthResponse` mapping classes.
  - Registered `http` and `shared_preferences` packages in `pubspec.yaml`.
  - Added `AppConstants` configuration file holding API endpoints and shared preference keys.
- New **History Detail Page** to display comprehensive assessment results.
- Interactive symptom cards in history detail with expandable explanations.
- Filtered symptom insights to show only user-selected symptoms.
- Scattered aura animations and refined risk level cards on the **Cover Page**.
- Assets directory registration for `assets/images/` in `pubspec.yaml`.
- Navigation route for `history-detail`.
- `fetchCurrentUser()` method in `AuthApiService` to call `GET /api/v1/auth/me` and sync the user profile from the backend on app load.
- Local **client-side diagnosis calculation** in `FullAssessmentPage` using the saturation formula `1 - exp(-k * sum)` — the app no longer submits answers to the server for diagnosis.
- Background user profile sync on `HomePage` and `ProfilePage` init to keep local nickname in sync with the backend.

### Fixed
- Fixed compile-time errors in `ProfilePage` and `HomePage` by importing `AuthApiService`, and in `FullAssessmentPage` by importing `dart:math` for `exp`.
- Android internet connectivity by adding `INTERNET` permission and cleartext traffic support in `AndroidManifest.xml`.
- Android emulator network connection by configuring dynamic localhost/10.0.2.2 baseUrl resolving in `app_constants.dart`.
- Registration flow redirect: modified register page to push the user to the login screen with a success notification instead of automatically logging them in.
- Corrected the backend API port in `AppConstants` from `5000` to `5181` to match the actual ASP.NET local server, resolving connection timeouts.
- Synced email format validation in `RegisterPage` and `LoginPage` to require both `@` and `.` characters, preventing invalid formats from passing locally.
- **Header greeting** now displays "Hello, (Nickname)" using the user's display name from Supabase metadata, instead of the static "Hi, User" placeholder.

### Changed
- Increased HTTP connection timeout to 30s in `AuthApiService` and added explicit `TimeoutException` handling for friendlier connection error messages.
- Refined **Home Page** UI by fixing Switch colors and removing redundant "See All" text.
- Updated **Profile Page** navigation index for consistency.
- Simplified **Profile Page** UI by removing unnecessary decorative elements.
- Updated route configuration to handle arguments for history details.
- `RegisterPage` now uses a **"Nickname"** field instead of "Full Name"; the nickname value is sent as `display_name` in Supabase user metadata.
- `AppConstants.usersMe` endpoint updated to `/api/v1/auth/me` to match the new backend route.
- `HomeHeader` greeting updated to read nickname from `StorageService` and display "Hello, (Nickname)".

### Removed
- `Age` and `Gender` fields from `RegisterPage`, `AuthApiService.register()`, and `UserModel` — registration now only collects full name, email, and password.
- Page transition animations globally to provide instant page appearance.
- Custom slide transitions in HomeHeader and GuestBottomNav.
- Redundant "View Symptom Insights" button from Result Page (integrated into history).
- Decorative blur circles in Profile Page for a cleaner look.
- `submitAssessment()` method from `AssessmentApiService` — assessment answers are no longer sent to the backend; diagnosis is calculated locally.

