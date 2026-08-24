# CHGLog Supabase setup

CHGLog uses Supabase Auth for Google sign-in and a JWT-protected Supabase Edge
Function for Google Sheets access. The app displays a configuration warning
when its three compile-time configuration values are absent; it never performs
mock searches in a normal app launch.

## Account ownership

Use a personal Gmail account to own and configure the Supabase project, Google
Cloud project, OAuth clients, and service account. The administrator account
does not need to use an approved vendor domain and is not embedded in the app.

This is separate from app access. CHGLog accepts only verified Google accounts
whose company domain is listed in Supabase. Supabase Auth enforces the allowlist
before creating a user, and the Edge Function repeats the check on every Sheet
request.

## 1. Create and link a Supabase project

Sign in to <https://supabase.com/dashboard> with the personal Gmail account.
Create an organization if the account does not have one, then create the
`CHGLog` project inside it.

Run these commands from the CHGLog project directory. Use the `.cmd` commands
on Windows because PowerShell may block the `.ps1` wrappers:

```powershell
npm.cmd install supabase --save-dev
npx.cmd supabase login
npx.cmd supabase link --project-ref YOUR_PROJECT_REF
```

Find the project URL and publishable key under **Project Settings > API**. A
publishable key is intended for client apps; never put the secret/service-role
key in Flutter.

## 2. Enforce approved company domains in Supabase Auth

Deploy the included database migration:

```powershell
npx.cmd supabase db push
```

The migrations create `public.allowed_email_domains` and the
`public.hook_allow_globe_email` Auth Hook. The function name is retained for
compatibility with existing hook configuration, but its rule now checks the
allowlist table instead of one hardcoded domain.

In the Supabase dashboard:

1. Open **Authentication > Hooks**.
2. Select **Before User Created**.
3. Choose **Postgres Function**.
4. Select `public.hook_allow_globe_email` and enable the hook.
5. Open **Authentication > Providers** and leave Google enabled. Disable email,
   phone, anonymous, and other sign-in providers that CHGLog does not use.
6. Open **Authentication > Users** and delete any users whose domains are not
   approved. The hook prevents new invalid users but does not retroactively
   delete existing accounts.

### Manage vendor domains

Open **Table Editor > allowed_email_domains**. The migration initially adds:

| domain | company_name | user_role |
| --- | --- | --- |
| `huawei.com` | `Huawei` | `onsite` |
| `globe.com.ph` | `Globe Telecom` | `wln` |

Add one row for every approved vendor after confirming the exact domain shown
after `@` in its company email addresses. For example, do not assume FiberHome
or ISERVE's domain from the company name; confirm it with the vendor first.

Store domains in lowercase without `@`, such as `vendor.example`. Removing a
row blocks new accounts from that domain and immediately blocks its existing
users from calling the CHGLog Edge Function. Delete any existing Supabase users
from that domain under **Authentication > Users** if their login access must
also be fully revoked.

An allowlist is used instead of a personal-email blocklist because public email
providers and custom personal domains cannot be enumerated reliably.

The `user_role` column controls the app workflow. Use `wln` only for trusted
Wireline domains; all vendor domains must remain `onsite`. The included
migration assigns `globe.com.ph` to `wln`. This role is resolved by Supabase on
every function call and cannot be selected by the mobile app.

The matching local hook configuration is stored in `supabase/config.toml`, and
the SQL is versioned under `supabase/migrations`.

## 3. Get the Android signing fingerprints

Android Studio already supplies the required Java runtime. Set it for the
current PowerShell session, then request the signing report:

```powershell
cd C:\Users\mikha\OneDrive\Documents\development\CHGLog\android
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
.\gradlew.bat signingReport
cd ..
```

Record the SHA-1 and SHA-256 values for the `debug` variant.

## 4. Configure Google authentication

Sign in to Google Cloud Console with the same personal Gmail account and create
or select a Google Cloud project. In Google Auth Platform:

1. Configure the app branding and consent screen.
2. Set the audience to **External** because the project is owned by a personal
   Gmail account. During testing, add the intended vendor accounts as test users
   if Google requests a test-user list.
3. Create a Web OAuth client. Add the Supabase callback shown under
   **Authentication > Providers > Google** as an authorized redirect URI.
4. Create an Android OAuth client for package `ph.com.globe.chglog`, using the
   SHA-1 recorded in the previous section.

In Supabase **Authentication > Providers > Google**, enable Google and enter the
Web client ID and secret. Keep the Web client ID for the Flutter build command.

Supabase's Before User Created hook is the authoritative signup check. Google
OAuth configuration alone is not treated as authorization. Each vendor's Google
Workspace administrator may still need to approve the OAuth application before
its company accounts can sign in.

## 5. Grant the Edge Function access to the Sheet

In the personal Google Cloud project, create a service account and enable Google
Sheets API. Share the spreadsheet with the service-account email as Editor. The
spreadsheet owner or its Workspace administrator may need to approve this
external share. Download the service account's JSON key.

Create an untracked `supabase/.env` containing one line. Keep the JSON on one
line and never commit this file:

```text
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

Set the secret and deploy the function:

```powershell
npx.cmd supabase secrets set --env-file supabase\.env
npx.cmd supabase functions deploy chglog
```

The function searches column `I`, returns the Title (`B`), Objective (`C`),
current Status (`O`), and Proponent (`U`) from the matching row, writes `login`
to column `O`, writes an Asia/Manila server timestamp in `HHmmH` format to
column `P`, and writes labeled check-in details to column `T` on the same row.

### Hotline-assisted manual login

When the vendor cannot use the app, the Wireline implementer can record the
login directly in the `ACTIVE` tab. Enter `login` in column `O`, the current
time in `HHmmH` format in column `P`, and use this labeled format in column `T`:

```text
Onsite implementer: Vendor employee name
Company: Vendor company
Contact: Contact number
Email: employee@approved-company.example
WLN implementer: Wireline implementer name
```

All five lines are independently optional for a hotline-assisted record. For a
WLN-only activity, column `T` may contain only `WLN implementer: Name`; missing
company, contact, and email values do not cause a webhook or database error.
The app never asks the vendor user for the WLN implementer and preserves an
existing WLN value when completing a manual login.

For a non-WLN activity already linked to the signed-in user, searching the CHG
shows **Edit my details**. The form is prefilled from Supabase and updates the
onsite implementer, company, contact number, and authenticated email in both
the existing database record and column `T`. It does not create a duplicate or
change the original check-in time.

The installable `handleStatusEdit` trigger sends the row to Supabase. The
database stores it with `source = manual`. When the email exactly matches an
existing Supabase Auth user, the activity is linked to that user and appears in
their **My activities** list. Without a match, the record remains in the
database with a null `user_id`; it stays searchable from the Sheet-backed main
screen but is not exposed in any user's activity history.

When an approved app user later searches that CHG, the result offers
**Complete manual login**. Submitting the form replaces column `T` with the
authenticated user's details and atomically links the unassigned manual record
to that user. The original login status and time are preserved, and the linked
record then appears in **My activities**.

Editing column `T` later also synchronizes the name, company, contact number,
and email for the matching manual database record. A T-only edit does not
change the status or checkout fields and does not send a status notification.
If the newly entered email exactly matches a Supabase Auth user, the previously
unassigned activity is linked to that user.

## 6. Run the configured app

Use the values from **Project Settings > API** and the Google Web OAuth client:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Use the same values for release builds. Without them, the app displays a
configuration warning instead of allowing searches.

## Data contract

- Spreadsheet: <https://docs.google.com/spreadsheets/d/1hwaPaPJs0nAtlGzR6nFmFwt3mIv4OznLEms6Bu7NrKg/edit?gid=401008961#gid=401008961>
- Spreadsheet ID: `1hwaPaPJs0nAtlGzR6nFmFwt3mIv4OznLEms6Bu7NrKg`
- Linked tab ID: `401008961` (expected tab name: `ACTIVE`)
- Tab: `ACTIVE`
- CHG lookup: column `I`, matching an exact `CHG` plus seven-digit token even
  when one cell contains multiple labeled CHG references
- Change preview: Title from column `B`, Objective from column `C`, and
  Proponent from column `U`; Status comes from column `O` and displays as
  `Not checked in` when the cell is empty or does not contain an approved status
  The structured column `T` details are also shown when present: onsite
  implementer, company, contact, email, and WLN implementer.
- WLN assignment: users from a Supabase-approved domain whose `user_role` is
  `wln` receive **Add to my activities** without being asked for onsite name,
  company, or contact details. Users from `onsite` domains receive the required
  onsite check-in form. Column `K` does not control the user's role.
- Check-in marker: `login` in column `O`
- Approved status values: `login`, `ongoing pre-checks`, `ongoing planned`,
  `ongoing post-checks`, and `implemented`
- Login time: column `P`
- Logout time: column `Q`, written in `HHmmH` format only when status becomes
  `implemented`
- Full name, company, contact number, and verified email: column `T`
- Activity retention: Supabase deletes activity records older than one calendar
  month in a daily scheduled job; related notification history is deleted with
  each expired activity
