# Codeskate CRM - Flutter Mobile App

A beautiful, modern CRM mobile application built with Flutter for managing leads, WhatsApp conversations, follow-ups, and team collaboration.

## Features

- **Phone OTP Login** - Backend multichannel OTP (WhatsApp → SMS → Voice) exchanged for a Firebase custom token
- **Dashboard** - Overview stats, quick actions, recent leads
- **Leads Management** - Search/filter, change status, reassign (admin), add leads (admin), team notes timeline
- **Follow-ups** - Schedule, complete (with outcome), reschedule; overdue / today / upcoming tabs
- **WhatsApp Conversations** - Reply, approved templates, AI takeover / re-enable, call from the chat
- **Calling** - Bridge calls, direct dial, native Android call logging, call history & recordings
- **Team Chat** - Firestore-backed org-wide "General" channel + 1:1 direct messages
- **Notifications** - In-app notification feed (real-time Firestore listener)
- **Billing** - Add-on packs and Voice Wallet top-ups via Razorpay
- **Settings** - Org switcher, lead-status editor (admin), help & support, about

## Tech Stack

- **Flutter** - Cross-platform mobile framework (Android first, iOS later)
- **Firebase Auth** - Custom-token sign-in after backend OTP
- **Cloud Firestore** - Real-time database
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

# 5. Android reads Firebase config from google-services.json only.
#    (lib/firebase_options.dart is used for iOS/web — run
#    `flutterfire configure` before targeting those platforms.)

# 6. Run on a connected device / emulator
flutter run
```

> **OTP note:** Login uses the backend's `POST /api/v1/otp/send` and
> `POST /api/v1/otp/verify` (which returns a Firebase custom token), so
> Firebase Phone Auth / SHA-1 setup is not required.

### Firebase Collections Used

The app connects to the same Firestore backend as the web CRM:

- `organizations/{orgId}/leads` - Lead documents
- `organizations/{orgId}/followUpTasks` - Follow-up tasks
- `organizations/{orgId}/notifications` - User notifications
- `organizations/{orgId}/leads/{leadId}/messages` - WhatsApp messages
- `organizations/{orgId}/settings/config` - Org settings
- `organizations/{orgId}/leads/{leadId}/notes` - Lead notes (worknotes, call logs)
- `organizations/{orgId}/teamChats/{chatId}/messages` - Team chat
- `memberships` - User organization memberships
- `users` - User profiles

## Lead & Follow-up Workflows

Lead status, assignment and follow-up tasks are server-owned in Firestore
rules, so the app calls the same secured endpoints as the web CRM
(`lib/services/crm_service.dart`):

- `POST /api/follow-ups/:leadId/status` — `{ orgId, status }`
- `POST /api/follow-ups/:leadId/reassign` — `{ orgId, assignedTo }` (admin)
- `POST /api/follow-ups/schedule` — `{ orgId, leadId, dueAt, type, title? }`
- `POST /api/follow-ups/:taskId/complete` — `{ orgId, expectedRevision, outcome, note?, leadStatus?, nextDueAt? }`
- `POST /api/leads/manual` — `{ orgId, name, phone, email?, requirement?, priority }` (admin)

Team worknotes are written directly to Firestore (allowed by rules for admins
and the lead's assignee).

## Team Chat

`organizations/{orgId}/teamChats/general` is an org-wide channel;
`dm_{uidA}__{uidB}` (sorted uids) are 1:1 threads. Access is enforced by the
`teamChats` block in `SNS-ADS-ERP/firestore.rules` — **deploy those rules**
(`firebase deploy --only firestore:rules`) before shipping this build.
Admins can start a DM with any member; employees can use General and reply to
DMs (rules don't let employees list the org's memberships).

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


## In-App Purchases — Add-ons & Voice Wallet (Razorpay)

Admins can buy add-on packs and top up the Voice Wallet directly from the app.
**Subscriptions/plan changes stay on the web dashboard** — the app links out to
it — but everything else (AI reply packs, extra seats/leads, catalogue, wallet
top-ups) is purchasable in-app via Razorpay, using the same backend as the web
CRM. No backend changes are required.

### Where
- **Settings → Billing & Add-ons** (`/billing`): live plan status, AI-reply
  usage, and the list of purchasable add-on packs (server-driven via
  `GET /api/billing/quota-status`). Non-admins see a read-only plan view.
- **Settings → Voice Wallet** (`/wallet`): balance, top-up (₹100 min, presets
  ₹500/1000/2000/5000 or custom), and transaction history. Gated to Growth+
  plans, matching the web app.

### Purchase flow (mirrors the web CRM)
1. `POST /api/billing/razorpay/addon/order` `{ orgId, addOnId, quantity }`
   (or `POST /api/wallet/order` `{ orgId, amountInr }`) → `{ orderId, amount,
   currency, keyId }`.
2. Open Razorpay Checkout (native `razorpay_flutter`) with those values.
3. On success → `POST /api/billing/razorpay/addon/verify`
   (or `POST /api/wallet/verify`) with
   `{ razorpay_order_id, razorpay_payment_id, razorpay_signature }`.
4. The app re-fetches quota/balance; the live org listener reflects new limits.

### Setup
- `razorpay_flutter` is already in `pubspec.yaml`. Run `flutter pub get`.
- Android `minSdk` is 23 (≥ 19 required) via `scripts/setup_android.sh`.
- The backend must have `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` configured
  (it already is for the web CRM). The publishable key is returned per-order, so
  no key is hard-coded in the app.
- If you enable code shrinking for release (`minifyEnabled true`), add the
  Razorpay ProGuard rules from https://pub.dev/packages/razorpay_flutter.

Backend base URL defaults to `https://api.codeskate.com`; override with
`--dart-define=BACKEND_URL=https://your-backend-host`.

### Code map
- `lib/services/billing_service.dart` — REST client (mirrors web `billingApi.js`)
- `lib/services/razorpay_checkout.dart` — awaitable wrapper over `razorpay_flutter`
- `lib/providers/billing_provider.dart` — org listener + purchase orchestration
- `lib/models/billing_models.dart` — OrgBilling / AddOn / QuotaStatus / Wallet*
- `lib/screens/billing/billing_screen.dart` — plan status + add-on store
- `lib/screens/billing/wallet_screen.dart` — wallet balance + top-up
