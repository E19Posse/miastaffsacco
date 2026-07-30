# BMC SACCO Flutter App — Setup Guide

## 1. Install the tools (in this order)

### a) Java 17 (JDK)
Download: https://adoptium.net/temurin/releases/?version=17
Install, then set JAVA_HOME environment variable to the install folder.

### b) Android Studio
Download: https://developer.android.com/studio
During install, also install:
- Android SDK (API 34)
- Android Virtual Device (AVD) — Pixel 6, API 34

### c) Flutter SDK
Download: https://docs.flutter.dev/get-started/install/windows
Extract to C:\flutter
Add C:\flutter\bin to your PATH environment variable.

### d) Verify everything works
Open a new PowerShell and run:
    flutter doctor
All items should show a green tick. Fix any issues it reports.

---

## 2. Get dependencies

    cd C:\bmcsacco_app
    flutter pub get

---

## 3. Configure the API URL

Edit `lib/constants/api_constants.dart`:

- For Android Emulator: use `http://10.0.2.2/bmcsacco/public/api`
- For physical device on same WiFi: use your PC's local IP e.g. `http://192.168.1.100/bmcsacco/public/api`

---

## 4. Set up the Laravel API (backend)

The app needs these API routes on the Laravel side.
Run this in the bmcsacco project to add Sanctum:

    composer require laravel/sanctum
    php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
    php artisan migrate

---

## 5. Run the app

Start the Android emulator in Android Studio, then:

    flutter run

Or build a release APK:

    flutter build apk --release
    # APK will be at: build/app/outputs/flutter-apk/app-release.apk

---

## Project Structure

    lib/
    ├── main.dart              App entry point
    ├── app.dart               Routing & theme setup
    ├── theme/app_theme.dart   Dark theme & colors
    ├── constants/             API URLs
    ├── models/                Data models (Member, Loan, Savings, Transaction)
    ├── services/              API client (Dio) + secure storage
    ├── providers/             State management (Auth, Dashboard)
    └── screens/
        ├── login/             Login screen
        ├── home/              Dashboard with balance card & stats
        ├── transactions/      Transaction list with search & filters
        ├── savings/           Savings accounts
        ├── loans/             Loan portfolio with progress bars
        └── profile/           Member profile & settings
