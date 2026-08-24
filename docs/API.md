# CHGLog API Documentation

## Base URLs

```text
https://<project-ref>.supabase.co/functions/v1/chglog
https://<project-ref>.supabase.co/functions/v1/sheet-status-webhook
```

Requests and responses use JSON. Do not call these functions with a Supabase
service-role key from a mobile client.

## Authentication

### `chglog`

```http
Authorization: Bearer <supabase-user-access-token>
Content-Type: application/json
```

The function rejects unauthenticated users, non-allowlisted domains, and role
violations.

### `sheet-status-webhook`

```http
X-CHGLog-Webhook-Secret: <private-shared-secret>
Content-Type: application/json
```

## `chglog` actions

All actions use `POST /functions/v1/chglog`.

### Find a change

```json
{"action":"find","number":"CHG0135067"}
```

The response includes `found`, Sheet details, normalized status and times,
structured column-T details, `isWlnUser`, ownership flags, and editable current
user values. A CHG must match `^CHG\d{7}$`.

### Submit or edit onsite details

```json
{
  "action": "submit",
  "number": "CHG0135067",
  "fullName": "Juan Dela Cruz",
  "company": "Huawei",
  "contactNumber": "09123456789"
}
```

For a new onsite check-in, the function writes `login` to O, the Manila login
time to P, labeled details to T, and inserts an activity. If the same user
already owns the activity, the request updates T and the existing database
record without changing check-in time or creating a duplicate. If an unassigned
manual activity exists, the request claims it atomically.

### Add a WLN activity

```json
{"action":"add-wln-activity","number":"CHG0135067"}
```

Only users whose Supabase domain role is `wln` may call this action. It creates
or claims the personal activity without requiring onsite details and without
overwriting T. Repeating the action is idempotent for the same user and CHG row.

### List activities

```json
{"action":"list-activities"}
```

Returns the authenticated user's activities in descending check-in order.
RLS excludes unassigned and other-user records.

### Register an Android device

```json
{"action":"register-device","token":"<fcm-registration-token>"}
```

The token must be between 32 and 4096 characters. Upsert ownership is scoped to
the authenticated user.

## Sheet status webhook

Apps Script posts one row event at a time:

```json
{
  "sheetName": "ACTIVE",
  "editType": "status",
  "rowNumber": 20,
  "status": "ongoing pre-checks",
  "logoutTime": "",
  "changeNumbers": ["CHG0135067"],
  "title": "Change title",
  "objective": "Change objective",
  "proponent": "Owner",
  "loginTime": "2200H",
  "details": "Onsite implementer: Juan Dela Cruz\nCompany: Huawei\nContact: 09123456789\nEmail:\nWLN implementer: Dagz",
  "editedBy": "operator@example.com",
  "editedAt": "2026-08-23T14:00:00.000Z"
}
```

`editType` is `status` for O edits or `details` for T-only edits. Status edits
update status, checkout fields, notification history, and FCM delivery. Details
edits update only manual implementer fields and may link an exact Auth email
match; they do not emit a status notification.

## Common status codes

| Code | Meaning |
| --- | --- |
| 200 | Successful request |
| 400 | Invalid action, CHG, status, time, details, or role workflow |
| 401 | Missing/invalid JWT or webhook secret |
| 403 | Domain not allowed or action forbidden for the resolved role |
| 404 | CHG not present in ACTIVE |
| 405 | HTTP method is not POST |
| 409 | Manual record was already claimed |
| 500 | Sheet, database, Firebase, or unexpected server failure |

Production error responses intentionally avoid returning credential or provider
details. Inspect Supabase Function logs for server-side diagnostics.

