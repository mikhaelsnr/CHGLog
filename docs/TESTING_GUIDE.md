# CHGLog Testing Guide

## Test levels

Run static checks and widget tests before every deployment:

```powershell
flutter pub get
flutter analyze
flutter test
```

Use **CHGLog (profile test)** for emulator performance verification. Debug mode
is intended for breakpoints and hot reload; profile mode better represents
release scrolling and rendering behavior.

## Test accounts

Prepare separate Google accounts for:

- An allowlisted `onsite` vendor domain.
- An allowlisted `wln` domain (`globe.com.ph`).
- A disallowed personal or unlisted domain.

Never use production credentials in screenshots or test reports. Remove test
activity rows after verification.

## Functional test matrix

### Authentication

1. Approved onsite account signs in successfully.
2. Globe account signs in and resolves to WLN.
3. Unapproved domain is rejected by the Auth Hook.
4. Existing user from a removed domain cannot call the Edge Function.
5. Sign-out clears the app session.

### Search

1. Exact existing `CHG` plus seven digits returns the correct row.
2. CHG within a multi-CHG column-I cell matches the correct token.
3. Nonexistent CHG displays not found.
4. Invalid formats are blocked before network submission.
5. B, C, U, O, P, Q, and structured T values display correctly.
6. Unknown or blank O displays `Not checked in`.

### Onsite workflow

1. Button reads **Continue to check in**.
2. Empty name, company, or contact is rejected.
3. Valid submission writes O=`login`, P=`HHmmH`, and labeled T details.
4. Activity appears only in that user's history.
5. Searching an owned CHG shows **Edit my details** with prefilled fields.
6. Editing contact updates T and the same activity without changing check-in.

### WLN workflow

1. Globe user sees **Add to my activities** regardless of column K.
2. No onsite detail form is displayed.
3. Activity is added without overwriting T.
4. Repeating the action does not create another record for that user and row.
5. An onsite account cannot call the WLN action directly.

### Manual hotline workflow

1. Enter P and T, then set O to `login`.
2. Confirm a manual activity is created.
3. Blank email leaves `user_id` null and hides the record from histories.
4. Matching Auth email links the record to that user.
5. T-only edits synchronize optional fields without changing status.
6. A WLN-only T value such as `WLN implementer: Dagz` succeeds.
7. Claiming through **Complete manual login** preserves login time and WLN name.

### Status and notification

1. Edit O through every approved status in sequence.
2. Verify Supabase status and `status_updated_at`.
3. Verify FCM is delivered only to linked users.
4. `implemented` writes Q once and displays checkout time.
5. Changing away from `implemented` clears Q and checkout fields.
6. Invalid status does not produce a webhook update.

### History

1. Today is selected initially.
2. Date picker displays the selected date's activities.
3. A 10 PM-or-later activity carries into the following day's view.
4. Both onsite and WLN implementers display when present.
5. Hotline link opens the phone dialer.
6. Long lists scroll smoothly in profile or release mode.

## Work-profile test

```powershell
adb shell pm list users
adb install --user <work-profile-id> build\app\outputs\flutter-apk\app-debug.apk
```

Open CHGLog from the Work apps tab and verify Google sign-in, FCM permission,
and dialer behavior. Work-profile policy can restrict sideloading; production
distribution should use the organization's managed app catalog.

## Database verification queries

```sql
select id, change_number, user_email, source, status,
       checked_in_at, checked_out_at
from public.activities
order by checked_in_at desc
limit 20;
```

```sql
select domain, company_name, user_role
from public.allowed_email_domains
order by domain;
```

Do not update timestamps with `HHmmH`; timestamp columns require full ISO or
PostgreSQL timestamp values. Sheet-format time belongs in `checked_out_time`.

## Release acceptance

- `flutter analyze` and `flutter test` pass.
- Configured profile build completes and does not freeze during history scroll.
- APK uses package `ph.com.globe.chglog` and the expected signing certificate.
- No `.env`, service-role key, Firebase Admin JSON, or webhook secret is inside
  source control or the APK.
- Auth, Sheet, Apps Script, Supabase, Firebase, and work-profile smoke tests pass.

