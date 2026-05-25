# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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

### Fixed
- Android internet connectivity by adding `INTERNET` permission and cleartext traffic support in `AndroidManifest.xml`.
- Android emulator network connection by configuring dynamic localhost/10.0.2.2 baseUrl resolving in `app_constants.dart`.
- Registration flow redirect: modified register page to push the user to the login screen with a success notification instead of automatically logging them in.
- Corrected the backend API port in `AppConstants` from `5000` to `5181` to match the actual ASP.NET local server, resolving connection timeouts.
- Synced email format validation in `RegisterPage` and `LoginPage` to require both `@` and `.` characters, preventing invalid formats from passing locally.

### Changed
- Increased HTTP connection timeout to 30s in `AuthApiService` and added explicit `TimeoutException` handling for friendlier connection error messages.
- Refined **Home Page** UI by fixing Switch colors and removing redundant "See All" text.
- Updated **Profile Page** navigation index for consistency.
- Simplified **Profile Page** UI by removing unnecessary decorative elements.
- Updated route configuration to handle arguments for history details.

### Removed
- `Age` and `Gender` fields from `RegisterPage`, `AuthApiService.register()`, and `UserModel` — registration now only collects full name, email, and password.
- Page transition animations globally to provide instant page appearance.
- Custom slide transitions in HomeHeader and GuestBottomNav.
- Redundant "View Symptom Insights" button from Result Page (integrated into history).
- Decorative blur circles in Profile Page for a cleaner look.
