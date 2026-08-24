# CHGLog Setup and Deployment Guide

This is the operator checklist. See [`../SETUP.md`](../SETUP.md) for the detailed
console-by-console configuration.

## Prerequisites

- Flutter SDK and Android SDK or Android Studio.
- Node.js and npm (`npm.cmd` and `npx.cmd` on restricted PowerShell systems).
- Supabase project and CLI access.
- Google Cloud project with OAuth and Sheets API.
- Firebase project with Android app `ph.com.globe.chglog`.
- Editor access to the Google Sheet and Apps Script project.

## Local project

```powershell
cd C:\development\CHGLog
flutter pub get
npm.cmd install
npx.cmd supabase login
npx.cmd supabase link --project-ref YOUR_PROJECT_REF
```

Keep Flutter outside synchronized folders when possible. Configure VS Code's
`dart.flutterSdkPath` to the actual SDK directory.

## Supabase database

```powershell
npx.cmd supabase db push
```

Enable **Authentication > Auth Hooks > Before User Created** and select
`public.hook_allow_globe_email`. In `allowed_email_domains`, add verified vendor
domains with `user_role=onsite`; keep `globe.com.ph` as `user_role=wln`.

## Google OAuth

Create a Web OAuth client for Supabase and an Android OAuth client for package
`ph.com.globe.chglog`. Configure the Supabase callback URI on the Web client and
the Android signing SHA-1 on the Android client. Enable Google under Supabase
Authentication providers.

## Google Sheets service account

Enable Sheets API, create a service account, and share the spreadsheet as
Editor with its email. Store the one-line JSON only in ignored
`supabase/.env`:

```text
GOOGLE_SERVICE_ACCOUNT_JSON={...}
```

Never commit this file.

## Firebase notifications

Place the Android client configuration at
`android/app/google-services.json`. Store Firebase Admin JSON and the webhook
secret as Supabase secrets, not Flutter assets.

## Deploy functions

```powershell
npx.cmd supabase secrets set --env-file supabase\.env
npx.cmd supabase secrets set --env-file supabase\notifications.env
npx.cmd supabase functions deploy chglog
npx.cmd supabase functions deploy sheet-status-webhook --no-verify-jwt
```

`--no-verify-jwt` is intentional only for the webhook because Apps Script uses
the separate shared-secret header. The `chglog` function remains JWT protected.

## Apps Script

Paste `apps_script/Code.gs` into the Sheet's Apps Script project. Configure
script properties:

- `CHGLOG_WEBHOOK_URL`
- `CHGLOG_WEBHOOK_SECRET`

Create an installable trigger for `handleStatusEdit`: **From spreadsheet > On
edit**. The trigger watches O and T. Do not convert it to a simple `onEdit`
function because authorized URL fetching requires an installable trigger.

## Run locally

Use **CHGLog (configured)** in VS Code or:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

## Build APK

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

For organizational deployment, use Managed Google Play or private app
publishing through the company's MDM team. Direct APK installation into work
profiles may be prohibited by enterprise policy.

## Operational maintenance

- Review allowed domains and roles regularly.
- Rotate webhook and service-account credentials after suspected exposure.
- Monitor Edge Function logs and failed Apps Script executions.
- Confirm the daily one-month retention job remains scheduled.
- Redeploy functions after modifying TypeScript; paste Apps Script changes into
  the Sheet project separately.

