# Codeskate CRM - Flutter Mobile App

A beautiful, modern CRM mobile application built with Flutter for managing leads, WhatsApp conversations, follow-ups, and team collaboration.

## Features

- **Phone OTP Login** - Secure Firebase Phone Authentication
- **Dashboard** - Overview stats, quick actions, recent leads
- **Leads Management** - View, search, filter leads by status
- **WhatsApp Conversations** - View WhatsApp message threads with leads
- **Employee Chat** - Internal team messaging
- **Notifications** - Real-time push notifications
- **Follow-ups** - Track overdue, today, and upcoming follow-up tasks
- **Settings** - Profile, organization, preferences

## Tech Stack

- **Flutter** - Cross-platform mobile framework (Android first, iOS later)
- **Firebase Auth** - Phone OTP authentication
- **Cloud Firestore** - Real-time database
- **Firebase Messaging** - Push notifications
- **Provider** - State management
- **GoRouter** - Declarative routing
- **flutter_animate** - Smooth animations

## Architecture

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase config
├── core/
│   ├── theme/                   # AppColors, AppTheme (warm beige/orange brand)
│   ├── routes/                  # GoRouter configuration
│   └── constants/               # App constants
├── models/                      # Data models (Lead, FollowUp, Notification, etc.)
├── providers/                   # State management (Auth, Leads, Chat, etc.)
└── screens/
    ├── splash_screen.dart
    ├── auth/                    # Login, OTP screens
    ├── home/                    # Bottom navigation shell
    ├── dashboard/               # Stats dashboard
    ├── leads/                   # Leads list & detail
    ├── whatsapp/                # WhatsApp conversations
    ├── chat/                    # Employee team chat
    ├── notifications/           # Notifications list
    ├── followups/               # Follow-up tasks
    ├── settings/                # App settings
    └── widgets/                 # Reusable UI components
```

## Setup

### Prerequisites
- Flutter SDK 3.1+
- Android Studio or VS Code with Flutter plugin
- Firebase project (same backend as SNS-ADS-ERP web CRM)

### Configuration (Android)

The repo intentionally does **not** commit the generated Android Gradle
wrapper / launcher icons. Generate them with `flutter create`, then run the
setup script which applies the Firebase (Google Services) configuration.

```bash
# 1. Clone and enter the project
git clone --branch feature/flutter-crm-app --single-branch \
  https://github.com/Harshitsinha98/codeskate-crm-app.git
cd codeskate-crm-app

# 2. Generate the Android platform files
flutter create --platforms=android .
flutter pub get

# 3. Apply the Firebase Android configuration (Gradle + package name)
bash scripts/setup_android.sh

# 4. Add your Firebase config file (NEVER commit this)
#    Download google-services.json from Firebase Console
#    (Project Settings -> your Android app: com.codeskate.crm)
#    and place it here:
#      android/app/google-services.json

# 5. Update lib/firebase_options.dart with your Firebase values
#    (or run: flutterfire configure --platforms=android)

# 6. Run on a connected device / emulator
flutter run
```

> **Phone OTP note:** In Firebase Console, enable Authentication -> Sign-in
> method -> Phone, add your debug SHA-1 (get it via
> `cd android && ./gradlew signingReport`) to the Android app, and optionally
> add a test phone number + code for deterministic testing.

### Firebase Collections Used

The app connects to the same Firestore backend as the web CRM:

- `organizations/{orgId}/leads` - Lead documents
- `organizations/{orgId}/followUpTasks` - Follow-up tasks
- `organizations/{orgId}/notifications` - User notifications
- `organizations/{orgId}/leads/{leadId}/messages` - WhatsApp messages
- `organizations/{orgId}/settings/config` - Org settings
- `memberships` - User organization memberships
- `users` - User profiles

## Brand Theme

- **Primary:** Warm Orange (#E8652B)
- **Background:** Soft Beige (#FFF8F2)
- **Font:** Poppins (Google Fonts)
- **Design:** Card-based UI with smooth animations

## Platform Support

- ✅ Android (primary target)
- 🔄 iOS (planned)
- ❌ Web (use the existing web CRM instead)
