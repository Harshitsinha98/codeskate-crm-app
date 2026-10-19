# Codeskate CRM — Flutter app (Android + iOS)

Premium mobile companion for the Codeskate web CRM (`SNS-ADS-ERP`). Same
Firebase project (`sns-ads-erp`), same backend (`https://api.codeskate.com`),
same data — every web admin/employee module is available in the app.

## Features

| Area | What's in the app |
|---|---|
| Auth | WhatsApp → SMS → Voice OTP, Firebase custom token, auto-claim team invites, org switcher, free-trial workspace setup |
| Dashboard | Live pipeline, KPIs, 14-day lead flow, status donut, lead sources, team leaderboard, today's follow-ups, live activity |
| Leads | Search, status/source/priority filters, Meta-ad badges, add lead, bulk paste import, status, priority, assign, follow-ups, timeline, blacklist/delete |
| Shared WhatsApp inbox | Unclaimed / Mine / Unread / AI filters, claim · release · hand over · take over, AI resume, 24h-window aware composer, approved templates, internal team notes |
| Meta ads | Click-to-WhatsApp attribution (ad headline, ad ID, ctwa_clid), Lead Ads, per-ad leads / win-rate report |
| Broadcasts | Template campaigns with audience filters, live audience preview, schedule, analytics, per-recipient status, retry/cancel |
| Team | Invite by phone, roles, deactivate, monthly goals, bulk reassign |
| Automation & AI | Workflow builder (trigger → conditions → actions, draft/publish/rollback, test-run, runs), follow-up automation, AI customer care (settings, knowledge base, playground, analytics), product catalogue |
| Channels | WhatsApp status/sync/repair/templates, Google Ads webhook, website form + API key, Codeskate Voice status |
| More | Internal tickets, team chat, bridge calls & recordings, Android call tracking, billing add-ons & voice wallet (Razorpay), AI help desk, push notifications |

Done on the web by design: WhatsApp Embedded Signup, Meta page connect, buying
a voice number / KYC upload, plan subscription changes, platform owner console.
The app deep-links to `app.codeskate.com` for these.

## Run

```bash
flutter pub get
flutter run                     # Android or iOS device/simulator
flutter build apk --release     # Android
flutter build ipa               # iOS (macOS + Xcode + Apple signing)
```

Override the backend with `--dart-define=BACKEND_URL=https://…`.

Firebase client config is committed (`android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`). These are
public identifiers; **never** add a service-account key to this repo.

### iOS notes
- Bundle ID `com.codeskate.crm`, iOS 15+, Push + background remote-notification enabled.
- Push on iOS needs an APNs auth key (`.p8`) uploaded in Firebase Console → Cloud Messaging.
- Apple doesn't allow reading the call log, so automatic call logging is Android-only.

### CI
`.github/workflows/build.yml` builds a release APK (ubuntu) and an unsigned iOS
build (macOS) on every push; download them from the run's artifacts.

## Backend requirements

Deploy `SNS-ADS-ERP` branch `feat/ctwa-ads-and-mobile-push`, which adds:
- Click-to-WhatsApp ad attribution on inbound messages.
- `POST /api/v1/devices/register|unregister` + FCM push dispatcher.
- Firestore rules for team chat and indexes (`firebase deploy --only firestore`).

## Code map

```
lib/core/api/api_client.dart       Authenticated JSON client
lib/services/crm_api.dart          Typed wrappers for every backend endpoint
lib/services/push_service.dart     FCM registration, foreground display, tap routing
lib/providers/                     Auth, leads, inbox, team, chat, settings, billing…
lib/screens/widgets/premium.dart   Motion UI kit (aurora, glow buttons, counters, sheets)
lib/screens/…                      One folder per module
```

Brand: Orange `#FF6B1A` · Ember `#C74E24` · Cream `#FDF8F0` · Midnight `#0F0C0A`,
Space Grotesk / Inter / JetBrains Mono — same tokens as the web CRM.
