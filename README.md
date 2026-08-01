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


## WhatsApp Reply & AI Handoff (Mobile)

The conversation screen now supports the full AI-to-human handoff flow, matching
the web CRM:

- **AI status bar** at the top of each conversation shows whether AI is
  auto-replying or a human has taken over (driven by the lead's `aiEnabled`
  flag).
- **Take over** pauses AI for that lead; **Re-enable AI** resumes it.
- A **reply composer** lets agents send free-form WhatsApp messages (valid
  inside the 24-hour service window). If the window has closed, the backend
  returns `template_required` and the user is told to use an approved template.

These actions call the same backend as the web app, so you must point the app
at your backend:

```bash
flutter run --dart-define=BACKEND_URL=https://your-backend-host
```

Endpoints used (Firebase ID token sent as Bearer):
- `POST /api/whatsapp/messages` — `{ orgId, leadId, text, clientMessageId }`
- `POST /api/v1/chat-sessions/takeover` — `{ orgId, leadId, reason }`
- `POST /api/v1/chat-sessions/re-enable-ai` — `{ orgId, leadId }`

If `BACKEND_URL` is not set, message history still loads (read-only) but
sending/takeover are disabled with a clear message.

## Native Call Tracking (Android)

After a call ends, the app reads the latest completed call from the Android
CallLog, matches it to a lead by the last 10 digits of the phone number, and
writes a `call` note to `organizations/{orgId}/leads/{leadId}/notes` (idempotent
by `call_{callLogId}`). This mirrors the reference Capacitor plugin.

- Permissions `READ_PHONE_STATE` and `READ_CALL_LOG` are requested at runtime
  (added to the manifest automatically by `scripts/setup_android.sh`).
- Native code lives in `scripts/android_templates/` and is installed into the
  generated Android project by the setup script.
- Tracking runs while the app is in the foreground/resumed; a catch-up check on
  resume (`getLastCall`) handles a call that ended while backgrounded. Android
  OEM background limits mean this is best-effort, not a persistent service.
